import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/utils/json_reader.dart';

/// Resultado de convertir las `operations` del servidor en bytes de impresora.
class EncodedPrintOperations {
  const EncodedPrintOperations({
    required this.bytes,
    required this.text,
    required this.ignored,
  });

  /// Bytes listos para el transporte (ESC/POS del ticket o TSPL de la etiqueta).
  final Uint8List bytes;

  /// Texto legible del documento, sin comandos (para previsualizar o compartir
  /// por WhatsApp). Solo lo aporta el ticket ESC/POS.
  final String text;

  /// Operaciones que el servidor pidió y el teléfono **no** puede emitir
  /// (p. ej. `DescargarImagenDeInternetEImprimir`, que exige rasterizar).
  final List<String> ignored;

  bool get isEmpty => bytes.isEmpty;

  int get byteCount => bytes.length;

  /// Aviso en español cuando la plantilla trae algo que no se puede imprimir.
  String? get ignoredNotice => ignored.isEmpty
      ? null
      : 'La plantilla incluye ${ignored.join(', ')}, que el teléfono no '
            'puede imprimir: revisa el documento en la web si falta algo.';
}

/// Traduce las `operations` del contrato §10 a bytes de impresora.
///
/// El servidor entrega el documento **ya armado** y la app solo lo transporta;
/// este intérprete cubre únicamente lo que un teléfono puede emitir:
///
/// | Operación | Qué se manda |
/// |---|---|
/// | `TextoSegunPaginaDeCodigos` | selección de tabla de códigos (`ESC t n`) + el texto ESC/POS que ya armó el servidor, byte por byte |
/// | `EscribirTexto` | el texto tal cual en UTF-8 (es el comando **TSPL** de una etiqueta) |
/// | `AbrirCajon` | el pulso de cajón (`ESC p 0 25 250`) |
///
/// Cualquier otra operación (imágenes) queda en [EncodedPrintOperations.ignored]
/// para que la UI avise en vez de imprimir a medias.
class PrintOperationsEncoder {
  const PrintOperationsEncoder._();

  /// Operación que trae los bytes ESC/POS del ticket (§10).
  static const String codepageOperation = 'TextoSegunPaginaDeCodigos';

  /// Operación que trae el comando TSPL completo de la etiqueta (§10).
  static const String textOperation = 'EscribirTexto';

  /// Pulso del cajón de dinero (el mismo que usa el servidor con
  /// `open_drawer`).
  static const String drawerOperation = 'AbrirCajon';

  /// `ESC p m t1 t2`.
  static const List<int> drawerKick = <int>[0x1B, 0x70, 0x00, 0x19, 0xFA];

  /// Tablas de códigos Epson (`ESC t n`) que el servidor puede pedir por nombre.
  ///
  /// El servidor manda `[0, 'cp850', texto]`: el **nombre** es el que manda
  /// (el número es la tabla del plugin de escritorio, no la de Epson), así que
  /// `cp850` se traduce a `ESC t 2`, que es la tabla que ya usaba la app.
  static const Map<String, int> _codepageTables = <String, int>{
    'cp437': 0x00,
    'cp850': 0x02,
    'cp860': 0x03,
    'cp863': 0x04,
    'cp865': 0x05,
    'cp858': 0x13,
    'cp1252': 0x10,
    'latin1': 0x10,
    'iso8859-1': 0x10,
  };

  static EncodedPrintOperations encode(List<Map<String, dynamic>> operations) {
    final out = BytesBuilder(copy: false);
    final buffer = StringBuffer();
    final ignored = <String>[];

    for (final operation in operations) {
      final name = JsonReader.stringOr(operation['nombre'], '');
      final arguments = operation['argumentos'];
      final args = arguments is List ? arguments : const <Object?>[];

      switch (name) {
        case codepageOperation:
          final raw = args.length > 2 ? JsonReader.stringOr(args[2], '') : '';

          if (raw.isEmpty) {
            break;
          }

          out.add(<int>[
            0x1B,
            0x74,
            _codepageTable(
              args.isEmpty ? null : args[0],
              args.length > 1 ? args[1] : null,
            ),
          ]);
          out.add(_rawBytes(raw));
          buffer.write(EscPosTextExtractor.extract(raw));
          break;
        case textOperation:
          final raw = args.isEmpty ? '' : JsonReader.stringOr(args.first, '');

          if (raw.isEmpty) {
            break;
          }

          out.add(utf8.encode(raw));
          break;
        case drawerOperation:
          out.add(drawerKick);
          break;
        default:
          if (name.isNotEmpty) {
            ignored.add(name);
          }
      }
    }

    return EncodedPrintOperations(
      bytes: out.toBytes(),
      text: buffer.toString().trim(),
      ignored: ignored,
    );
  }

  /// Bytes ESC/POS que viajan **dentro** de la operación.
  ///
  /// Son los bytes crudos que armó el servidor; el `String` de Dart los trae
  /// como unidades UTF-16 del mismo valor, así que se devuelven tal cual
  /// (nunca como UTF-8, que rompería los comandos ≥ 0x80).
  static Uint8List _rawBytes(String raw) =>
      Uint8List.fromList(raw.codeUnits.map((unit) => unit & 0xFF).toList());

  static int _codepageTable(Object? index, Object? name) {
    final table = _codepageTables[JsonReader.string(name)?.toLowerCase()];

    if (table != null) {
      return table;
    }

    final fallback = JsonReader.integer(index) ?? 0;

    return fallback < 0 || fallback > 0xFF ? 0x02 : fallback;
  }
}

/// Quita los comandos de un texto ESC/POS para poder leerlo o compartirlo.
///
/// No es un renderizador: solo recorre los comandos que emite el servidor
/// (`PrintEncoderService`) y deja el texto visible.
class EscPosTextExtractor {
  const EscPosTextExtractor._();

  static const int _esc = 0x1B;
  static const int _gs = 0x1D;

  static String extract(String raw) {
    final units = raw.codeUnits;
    final out = StringBuffer();

    for (var index = 0; index < units.length; index++) {
      final unit = units[index];

      if (unit == _esc) {
        index += _escSize(units, index) - 1;
        continue;
      }

      if (unit == _gs) {
        index += _gsSize(units, index) - 1;
        continue;
      }

      if (unit == 0x0A || unit >= 0x20) {
        out.writeCharCode(unit);
      }
    }

    return out.toString().trim();
  }

  /// Longitud del comando ESC (`@`, `a n`, `E n`, `t n`, `p …`).
  static int _escSize(List<int> units, int start) {
    final command = _at(units, start + 1);

    // ESC @ (inicializar), ESC p m t1 t2 (pulso de cajón), ESC d n (avance).
    if (command == 0x40) {
      return 2;
    }

    if (command == 0x70) {
      return 5;
    }

    // ESC a n, ESC E n, ESC t n, …
    return 3;
  }

  /// Longitud del comando GS (`V`, `h n`, `w n`, `k …`, `( k …`).
  static int _gsSize(List<int> units, int start) {
    final command = _at(units, start + 1);

    switch (command) {
      case 0x56: // GS V m [n] (corte)
        return _at(units, start + 2) == 66 ? 4 : 3;
      case 0x68: // GS h n (alto del código de barras)
      case 0x77: // GS w n (ancho)
        return 3;
      case 0x6B: // GS k m n datos… (código de barras)
        return 4 + _at(units, start + 3);
      case 0x28: // GS ( k pL pH … (QR): el largo declarado + la cabecera
        return _at(units, start + 3) + (_at(units, start + 4) << 8) + 5;
      default:
        return 2;
    }
  }

  static int _at(List<int> units, int index) =>
      index >= 0 && index < units.length ? units[index] : 0;
}
