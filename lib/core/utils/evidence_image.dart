import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';

/// Foto de evidencia lista para subir en un `multipart/form-data`.
///
/// Se comprime **antes** de enviarla (`flutter_image_compress`): el servidor
/// rechaza con `422` cualquier archivo mayor a
/// [AppConfig.maxEvidenceImageKb] KB.
class EvidenceImage {
  const EvidenceImage({
    required this.fileName,
    required this.bytes,
    required this.sizeKb,
  });

  factory EvidenceImage.fromBytes({
    required String fileName,
    required Uint8List bytes,
  }) => EvidenceImage(
    fileName: fileName,
    bytes: bytes,
    sizeKb: (bytes.length / 1024).ceil(),
  );

  /// Nombre con el que viaja el archivo (`foto-1.jpg`).
  final String fileName;
  final Uint8List bytes;

  /// Peso real de los bytes comprimidos.
  final int sizeKb;

  /// Peso legible (`245 KB`, `1.4 MB`).
  String get sizeLabel => sizeKb >= 1024
      ? '${(sizeKb / 1024).toStringAsFixed(1)} MB'
      : '$sizeKb KB';

  bool get isTooLarge => sizeKb > AppConfig.maxEvidenceImageKb;
}

/// Resultado de capturar fotos: las que quedaron listas y las que se
/// descartaron por exceder el peso máximo permitido por el servidor.
class EvidencePickResult {
  const EvidencePickResult({required this.images, this.skipped = 0});

  const EvidencePickResult.empty() : images = const <EvidenceImage>[], skipped = 0;

  final List<EvidenceImage> images;

  /// Fotos descartadas (no se pudieron comprimir por debajo del límite).
  final int skipped;

  bool get isEmpty => images.isEmpty;
}

/// Captura y compresión de evidencias fotográficas.
///
/// La app no envía rutas ni miniaturas generadas localmente: solo el archivo de
/// cada foto, ya reducido a un peso que el servidor acepta (2 MB).
class EvidencePicker {
  const EvidencePicker._();

  /// Lado mayor al que se reduce la foto antes de subirla.
  static const int _maxDimension = 1600;

  /// Calidades que se prueban en orden hasta bajar del límite de peso.
  static const List<int> _qualities = <int>[85, 70, 55, 40, 30];

  /// Una foto desde la cámara.
  ///
  /// [maxKb] permite apuntar a un límite distinto del de las evidencias (la foto
  /// de perfil acepta 1 MB, contrato §11b.4).
  static Future<EvidencePickResult> pickFromCamera({int? maxKb}) =>
      _pick(source: ImageSource.camera, limit: 1, maxKb: maxKb);

  /// Varias fotos desde la galería (hasta [limit]).
  static Future<EvidencePickResult> pickFromGallery({
    required int limit,
    int? maxKb,
  }) => _pick(source: ImageSource.gallery, limit: limit, maxKb: maxKb);

  static Future<EvidencePickResult> _pick({
    required ImageSource source,
    required int limit,
    int? maxKb,
  }) async {
    if (limit <= 0) {
      return const EvidencePickResult.empty();
    }

    final picker = ImagePicker();

    final List<XFile> files;

    if (source == ImageSource.camera) {
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      files = shot == null ? const <XFile>[] : <XFile>[shot];
    } else {
      final picked = await picker.pickMultiImage(
        imageQuality: 100,
        maxWidth: 2048,
        maxHeight: 2048,
        limit: limit,
      );

      files = picked.take(limit).toList(growable: false);
    }

    if (files.isEmpty) {
      return const EvidencePickResult.empty();
    }

    final images = <EvidenceImage>[];
    var skipped = 0;

    for (final file in files) {
      final image = await _compress(file, maxKb: maxKb);

      if (image == null) {
        skipped++;
        continue;
      }

      images.add(image);
    }

    return EvidencePickResult(images: images, skipped: skipped);
  }

  /// Comprime la foto bajando calidad hasta que el archivo entra en el límite.
  static Future<EvidenceImage?> _compress(XFile file, {int? maxKb}) async {
    final limitBytes = (maxKb ?? AppConfig.maxEvidenceImageKb) * 1024;

    Uint8List? best;

    for (final quality in _qualities) {
      try {
        final compressed = await FlutterImageCompress.compressWithFile(
          file.path,
          minWidth: _maxDimension,
          minHeight: _maxDimension,
          quality: quality,
          format: CompressFormat.jpeg,
        );

        if (compressed == null || compressed.isEmpty) {
          continue;
        }

        best = compressed;

        if (compressed.length <= limitBytes) {
          break;
        }
      } on Exception {
        // Si la compresión falla, se intentan las siguientes calidades.
        continue;
      }
    }

    if (best == null) {
      return null;
    }

    final fileName = _jpegFileName(file.name);

    return EvidenceImage.fromBytes(fileName: fileName, bytes: best);
  }

  /// El archivo comprimido siempre es JPEG.
  static String _jpegFileName(String original) {
    final cleaned = original.trim().isEmpty ? 'evidencia.jpg' : original.trim();
    final dot = cleaned.lastIndexOf('.');

    return dot <= 0 ? '$cleaned.jpg' : '${cleaned.substring(0, dot)}.jpg';
  }
}
