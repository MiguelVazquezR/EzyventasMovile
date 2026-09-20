import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/evidence_image.dart';
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
          Row(
            children: <Widget>[
              _Action(
                icon: Icons.photo_camera_outlined,
                label: 'Tomar foto',
                onTap: isBusy ? null : onCamera,
              ),
              const SizedBox(width: 8),
              _Action(
                icon: Icons.photo_library_outlined,
                label: 'Elegir de galería',
                onTap: isBusy ? null : onGallery,
              ),
              const Spacer(),
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

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = onTap == null ? surfaces.textMuted : EzyColors.primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: surfaces.panelInner,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: surfaces.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: EzyTextStyles.caption.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
