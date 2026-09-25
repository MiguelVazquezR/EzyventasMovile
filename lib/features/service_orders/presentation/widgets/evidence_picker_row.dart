import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/evidence_image.dart';
import '../../../../core/widgets/ezy_chip.dart';
import 'service_order_labels.dart';

/// Captura fotos (cámara o galería), las comprime y avisa lo que se descartó.
///
/// El servidor acepta como máximo `AppConfig.maxEvidenceImages` fotos de
/// `AppConfig.maxEvidenceImageKb` KB cada una; [remaining] es cuántas caben
/// todavía en la petición.
Future<List<EvidenceImage>> captureEvidence(
  BuildContext context, {
  required ImageSource source,
  required int remaining,
}) async {
  if (remaining <= 0) {
    return const <EvidenceImage>[];
  }

  EvidencePickResult result;

  try {
    result = source == ImageSource.camera
        ? await EvidencePicker.pickFromCamera()
        : await EvidencePicker.pickFromGallery(limit: remaining);
  } on PlatformException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(ServiceOrderLabels.photoFailed)),
      );
    }

    return const <EvidenceImage>[];
  }

  if (context.mounted && result.skipped > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ServiceOrderLabels.photosSkipped(result.skipped))),
    );
  }

  return result.images;
}

/// Acciones para agregar evidencias (cámara / galería) con el cupo restante.
class EvidencePickerRow extends StatelessWidget {
  const EvidencePickerRow({
    super.key,
    required this.remaining,
    this.isBusy = false,
    required this.onCamera,
    required this.onGallery,
  });

  /// Fotos que todavía acepta el servidor en esta petición.
  final int remaining;
  final bool isBusy;
  final VoidCallback? onCamera;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final limit = AppConfig.maxEvidenceImages;
    final reachedLimit = remaining <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Evidencias (máximo $limit)',
          style: EzyTextStyles.microLabel.copyWith(color: surfaces.textMuted),
        ),
        const SizedBox(height: 8),
        if (reachedLimit)
          Text(
            'Ya adjuntaste $limit fotos.',
            style: EzyTextStyles.caption.copyWith(
              color: surfaces.textSecondary,
            ),
          )
        else
          // `Wrap`: los dos chips y el contador caben en una línea en un
          // teléfono normal y saltan de línea con texto grande (`textScale`),
          // sin desbordar como hacía la `Row` fija.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              EzyChip(
                icon: Icons.photo_camera_outlined,
                label: 'Tomar foto',
                onTap: isBusy ? null : onCamera,
              ),
              EzyChip(
                icon: Icons.photo_library_outlined,
                label: 'Elegir de galería',
                onTap: isBusy ? null : onGallery,
              ),
              Text(
                'Quedan $remaining',
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
