import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/evidence_image.dart';
import '../../../../core/widgets/server_image.dart';
import '../../data/models/service_order_detail.dart';
import 'service_order_form_controls.dart';

/// Evidencias de la orden (card 6 del prototipo).
///
/// Una sola tira horizontal de miniaturas de 104 px que mezcla los dos orígenes
/// de foto del formulario:
///
/// * **Guardadas** (`media.initial_service_order_evidence`): la ✕ las marca en
///   `deleted_media_ids[]` y el borrado se confirma al guardar (se puede
///   deshacer tocando el velo rojo).
/// * **Nuevas**: los bytes ya comprimidos de esta sesión; la ✕ las descarta.
///
/// El contador `n/5` del encabezado avisa el cupo restante, los botones de
/// captura se deshabilitan al llegar al máximo y tocar una miniatura la abre a
/// pantalla completa con zoom (`InteractiveViewer`).
class ServiceOrderEvidencePicker extends StatelessWidget {
  const ServiceOrderEvidencePicker({
    super.key,
    required this.existing,
    required this.photos,
    required this.deletedMediaIds,
    required this.isPicking,
    required this.onCamera,
    required this.onGallery,
    required this.onRemovePhoto,
    required this.onToggleDelete,
  });

  /// Evidencias ya guardadas en el servidor (vacío en el alta).
  final List<ServiceOrderMedia> existing;

  /// Fotos capturadas en esta sesión y aún no subidas.
  final List<EvidenceImage> photos;

  /// Ids que viajarán en `deleted_media_ids[]`.
  final Set<int> deletedMediaIds;

  /// Hay una captura en curso (cámara/galería + compresión).
  final bool isPicking;

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemovePhoto;
  final ValueChanged<int> onToggleDelete;

  /// Cupo de fotos del servidor (`AppConfig.maxEvidenceImages`).
  int get _limit => AppConfig.maxEvidenceImages;

  /// Fotos que llevaría la orden si se guardara ahora mismo.
  int get _used =>
      existing.where((media) => !deletedMediaIds.contains(media.id)).length +
      photos.length;

  @override
  Widget build(BuildContext context) {
    final full = _used >= _limit;
    final busy = isPicking;

    final tiles = <Widget>[
      for (final media in existing) _savedTile(context, media),
      for (var index = 0; index < photos.length; index++)
        _photoTile(context, index),
    ];

    return SoCard(
      title: 'Evidencias',
      trailing: SoTag(
        label: '$_used/$_limit',
        color: full ? SoColors.warn : SoColors.success,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (tiles.isEmpty)
            SoNote(
              text:
                  'Adjunta hasta $_limit fotos del equipo al recibirlo. Se '
                  'comprimen a ${AppConfig.maxEvidenceImageKb ~/ 1024} MB cada '
                  'una antes de subirse.',
              icon: Icons.photo_camera_outlined,
              color: SoColors.info,
            )
          else
            _EvidenceStrip(children: tiles),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: SoOutlineButton(
                  label: 'Tomar foto',
                  icon: Icons.photo_camera_outlined,
                  onPressed: full || busy ? null : onCamera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SoOutlineButton(
                  label: 'Galería',
                  icon: Icons.photo_library_outlined,
                  onPressed: full || busy ? null : onGallery,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (busy)
            Row(
              children: <Widget>[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Procesando fotos…',
                  style: EzyTextStyles.caption.copyWith(
                    color: SoColors.textMuted(context),
                  ),
                ),
              ],
            )
          else if (full)
            const SoNote(
              text: 'Llegaste al máximo de fotos de esta orden.',
              icon: Icons.check_circle_outline,
              color: SoColors.success,
            )
          else
            const SoNote(
              text: 'Cada foto se comprime automáticamente antes de subirse.',
              icon: Icons.bolt_outlined,
              color: SoColors.info,
            ),
        ],
      ),
    );
  }

  /// Miniatura de una evidencia del servidor (marcable para borrar).
  Widget _savedTile(BuildContext context, ServiceOrderMedia media) {
    final deleted = deletedMediaIds.contains(media.id);

    return _EvidenceTile(
      caption: deleted ? 'Se eliminará' : media.sizeLabel,
      deleted: deleted,
      imageUrl: media.thumbUrl,
      fallbackUrl: media.originalUrl,
      onRemove: () => onToggleDelete(media.id),
      onTap: () => _openViewer(
        context,
        image: ServerImage(
          media.thumbUrl,
          fallbackUrl: media.originalUrl,
          fit: BoxFit.contain,
        ),
        caption: media.fileName,
      ),
    );
  }

  /// Miniatura de una foto nueva (se descarta sin tocar el servidor).
  Widget _photoTile(BuildContext context, int index) {
    final photo = photos[index];

    return _EvidenceTile(
      caption: photo.sizeLabel,
      bytes: photo.bytes,
      onRemove: () => onRemovePhoto(index),
      onTap: () => _openViewer(
        context,
        image: Image.memory(photo.bytes, fit: BoxFit.contain),
        caption: photo.fileName,
      ),
    );
  }

  /// Abre la evidencia a pantalla completa (zoom con dos dedos).
  void _openViewer(
    BuildContext context, {
    required Widget image,
    required String caption,
  }) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xE6000000),
      builder: (dialogContext) => Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: InteractiveViewer(maxScale: 5, child: image),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: _RoundIconButton(
                icon: Icons.close,
                tooltip: 'Cerrar',
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
          if (caption.trim().isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: EzyTextStyles.caption.copyWith(
                    color: const Color(0xFFE5E7EB),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tira horizontal con separación constante entre miniaturas.
class _EvidenceStrip extends StatelessWidget {
  const _EvidenceStrip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: children.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

/// Miniatura de evidencia: foto, pie con el peso y acción de quitar.
class _EvidenceTile extends StatelessWidget {
  const _EvidenceTile({
    required this.caption,
    required this.onTap,
    required this.onRemove,
    this.bytes,
    this.imageUrl,
    this.fallbackUrl,
    this.deleted = false,
  });

  /// Pie de la miniatura (`245 KB` o `Se eliminará`).
  final String caption;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// Bytes de una foto nueva (`null` cuando viene del servidor).
  final Uint8List? bytes;
  final String? imageUrl;
  final String? fallbackUrl;

  /// Marcada para borrar: el velo rojo permite deshacerlo al tocarlo.
  final bool deleted;

  static const double _size = 104;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return SizedBox(
      width: _size,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _size,
            height: _size,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ClipRRect(
                  borderRadius: radius,
                  child: Container(
                    decoration: BoxDecoration(
                      color: SoColors.inner(context),
                      border: Border.all(
                        color: deleted
                            ? SoColors.danger
                            : SoColors.structuralBorder(context),
                        width: deleted ? 2 : 1,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: onTap,
                      behavior: HitTestBehavior.opaque,
                      child: _thumb(context),
                    ),
                  ),
                ),
                if (deleted)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: onRemove,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SoColors.danger.withValues(alpha: 0.35),
                          borderRadius: radius,
                        ),
                        child: const Icon(
                          Icons.undo,
                          size: 22,
                          color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _RoundIconButton(
                      icon: Icons.close,
                      tooltip: 'Quitar',
                      onTap: onRemove,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: deleted
                  ? SoColors.tone(context, SoColors.danger)
                  : SoColors.textMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context) {
    if (bytes != null) {
      return Image.memory(
        bytes!,
        fit: BoxFit.cover,
        width: _size,
        height: _size,
      );
    }

    return ServerImage(
      imageUrl,
      fallbackUrl: fallbackUrl,
      fit: BoxFit.cover,
      width: _size,
      height: _size,
      errorBuilder: (context, error, stackTrace) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: SoColors.textMuted(context),
        ),
      ),
    );
  }
}

/// Botón circular oscuro sobre la foto (quitar miniatura, cerrar el visor).
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xCC1A1A1A),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0x66FFFFFF)),
          ),
          child: Icon(icon, size: 15, color: const Color(0xFFFFFFFF)),
        ),
      ),
    );
  }
}

