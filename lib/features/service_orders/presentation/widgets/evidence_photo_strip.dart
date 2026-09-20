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
    this.onRemove,
    this.isMarkedForDeletion = false,
  });

  final String caption;
  final Uint8List? bytes;
  final String? imageUrl;
  final VoidCallback? onRemove;
  final bool isMarkedForDeletion;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SizedBox(
      width: 96,
      child: Column(
        children: <Widget>[
          Stack(
            children: <Widget>[
              Container(
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
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.broken_image_outlined,
                          color: surfaces.textMuted,
                        ),
                      )
                    : null,
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
}
