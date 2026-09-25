import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/evidence_image.dart';
import '../../../../core/widgets/server_image.dart';
import '../../data/models/service_order_detail.dart';

/// Fotos capturadas que todavía no se suben (se muestran desde los bytes
/// comprimidos, sin depender del sistema de archivos).
class DraftEvidenceStrip extends StatelessWidget {
  const DraftEvidenceStrip({
    super.key,
    required this.images,
    required this.onRemove,
  });

  final List<EvidenceImage> images;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return _Strip(
      children: <Widget>[
        for (var index = 0; index < images.length; index++)
          _Tile(
            caption: images[index].sizeLabel,
            bytes: images[index].bytes,
            onRemove: () => onRemove(index),
          ),
      ],
    );
  }
}

/// Evidencias que ya están en el servidor (miniaturas de `media.*`).
///
/// En modo edición se pueden marcar para borrarlas
/// (`deleted_media_ids[]` del `PUT`); el diagnóstico **no** borra fotos.
///
/// La miniatura se pide con su URL original como respaldo: cuando la conversión
/// del servidor no existe, la foto igual se ve. Tocar la foto la abre a pantalla
/// completa.
class EvidenceMediaStrip extends StatelessWidget {
  const EvidenceMediaStrip({
    super.key,
    required this.items,
    this.markedForDeletion = const <int>{},
    this.onToggleDelete,
  });

  final List<ServiceOrderMedia> items;

  /// Ids que se enviarán en `deleted_media_ids[]`.
  final Set<int> markedForDeletion;

  /// `null` = solo lectura (no se pueden borrar).
  final ValueChanged<int>? onToggleDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return _Strip(
      children: <Widget>[
        for (final media in items)
          _Tile(
            caption: media.sizeLabel,
            imageUrl: media.thumbUrl,
            fallbackUrl: media.originalUrl,
            isMarkedForDeletion: markedForDeletion.contains(media.id),
            onRemove: onToggleDelete == null
                ? null
                : () => onToggleDelete!(media.id),
          ),
      ],
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.caption,
    this.bytes,
    this.imageUrl,
    this.fallbackUrl,
    this.onRemove,
    this.isMarkedForDeletion = false,
  });

  final String caption;
  final Uint8List? bytes;
  final String? imageUrl;
  final String? fallbackUrl;
  final VoidCallback? onRemove;
  final bool isMarkedForDeletion;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final canOpen = bytes != null || (imageUrl ?? '').isNotEmpty;

    return SizedBox(
      width: 96,
      child: Column(
        children: <Widget>[
          Stack(
            children: <Widget>[
              GestureDetector(
                onTap: canOpen ? () => _open(context) : null,
                child: Container(
                  width: 84,
                  height: 66,
                  decoration: BoxDecoration(
                    color: surfaces.panelInner,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isMarkedForDeletion
                          ? StatusPalette.border(EzySeverity.danger)
                          : surfaces.border,
                    ),
                    image: bytes == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(bytes!),
                            fit: BoxFit.cover,
                          ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: bytes == null && (imageUrl ?? '').isNotEmpty
                      ? ServerImage(
                          imageUrl,
                          fallbackUrl: fallbackUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.broken_image_outlined,
                            color: surfaces.textMuted,
                          ),
                        )
                      : null,
                ),
              ),
              if (onRemove != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: IconButton(
                    tooltip: isMarkedForDeletion
                        ? 'Conservar evidencia'
                        : 'Quitar evidencia',
                    onPressed: onRemove,
                    icon: Icon(
                      isMarkedForDeletion ? Icons.undo : Icons.cancel,
                      size: 20,
                      color: isMarkedForDeletion
                          ? EzyColors.primary
                          : EzyColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            isMarkedForDeletion ? 'Se eliminará' : caption,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.caption.copyWith(
              color: isMarkedForDeletion
                  ? StatusPalette.text(context, EzySeverity.danger)
                  : surfaces.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Abre la evidencia a pantalla completa (zoom con dos dedos).
  void _open(BuildContext context) {
    final Widget image = bytes == null
        ? ServerImage(imageUrl, fallbackUrl: fallbackUrl, fit: BoxFit.contain)
        : Image.memory(bytes!, fit: BoxFit.contain);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        backgroundColor: EzyColors.surfaceDarkDeep,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: SizedBox(width: 400, child: image),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                caption,
                style: EzyTextStyles.caption.copyWith(
                  color: EzyColors.textSecondaryDark,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }
}
