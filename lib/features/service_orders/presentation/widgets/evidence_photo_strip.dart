import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/evidence_image.dart';
import '../../../../core/widgets/server_image.dart';
import '../../data/models/service_order_detail.dart';

/// Lado de cada miniatura (§D del rediseño del diagnóstico).
const double _thumbSize = 96;

/// Radio de las miniaturas.
const double _thumbRadius = 12;

/// Alto de la cinta: miniatura + etiqueta inferior + aire para el botón de
/// descarte, que se sale por arriba de la miniatura.
const double _stripHeight = 130;

/// Fotos capturadas que todavía no se suben (se muestran desde los bytes
/// comprimidos, sin depender del sistema de archivos).
///
/// Las miniaturas llevan borde ámbar y un botón circular rojo (X) que las quita
/// del listado local **antes** de enviar (no toca el servidor).
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
            borderColor: EzyColors.warning,
            draftRemove: true,
            removeTooltip: 'Descartar foto',
            onRemove: () => onRemove(index),
          ),
      ],
    );
  }
}

/// Evidencias que ya están en el servidor (miniaturas de `media.*`).
///
/// En modo edición se pueden marcar para borrarlas
/// (`deleted_media_ids[]` del `PUT`); el diagnóstico **no** borra fotos: al
/// abrirse con [onToggleDelete] `null` las fotos son estrictamente de lectura y
/// solo se pueden ampliar con zoom. La miniatura se pide con su URL original
/// como respaldo: cuando la conversión del servidor no existe, la foto igual se
/// ve.
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
            showServerBadge: onToggleDelete == null,
            isMarkedForDeletion: markedForDeletion.contains(media.id),
            removeIcon: markedForDeletion.contains(media.id)
                ? Icons.undo
                : Icons.cancel,
            removeColor: markedForDeletion.contains(media.id)
                ? EzyColors.primary
                : EzyColors.danger,
            removeTooltip: markedForDeletion.contains(media.id)
                ? 'Conservar evidencia'
                : 'Quitar evidencia',
            onRemove: onToggleDelete == null
                ? null
                : () => onToggleDelete!(media.id),
          ),
      ],
    );
  }
}

/// Cinta horizontal deslizable de miniaturas.
class _Strip extends StatelessWidget {
  const _Strip({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _stripHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Deja sitio al botón de descarte, que sobresale de la miniatura.
        padding: const EdgeInsets.only(top: 10),
        itemCount: children.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

/// Miniatura de una evidencia: 96×96, radio 12 y etiqueta inferior.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.caption,
    this.bytes,
    this.imageUrl,
    this.fallbackUrl,
    this.borderColor,
    this.showServerBadge = false,
    this.draftRemove = false,
    this.onRemove,
    this.removeTooltip,
    this.removeIcon,
    this.removeColor,
    this.isMarkedForDeletion = false,
  });

  final String caption;
  final Uint8List? bytes;
  final String? imageUrl;
  final String? fallbackUrl;

  /// Borde propio (ámbar en los borradores); sin él, el borde normal.
  final Color? borderColor;

  /// Etiqueta «Servidor» con check verde (fotos confirmadas en el servidor).
  final bool showServerBadge;

  /// El botón de quitar es el círculo rojo de los borradores.
  final bool draftRemove;

  final VoidCallback? onRemove;
  final String? removeTooltip;
  final IconData? removeIcon;
  final Color? removeColor;
  final bool isMarkedForDeletion;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final canOpen = bytes != null || (imageUrl ?? '').isNotEmpty;

    return SizedBox(
      width: _thumbSize,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              GestureDetector(
                onTap: canOpen ? () => _open(context) : null,
                child: Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  decoration: BoxDecoration(
                    color: surfaces.panelInner,
                    borderRadius: BorderRadius.circular(_thumbRadius),
                    border: Border.all(
                      color: borderColor ??
                          (isMarkedForDeletion
                              ? StatusPalette.border(EzySeverity.danger)
                              : surfaces.border),
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
                  top: -8,
                  right: -8,
                  child: _RemoveButton(
                    draft: draftRemove,
                    tooltip: removeTooltip,
                    icon: removeIcon,
                    color: removeColor,
                    onTap: onRemove!,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (showServerBadge)
            const _ServerBadge()
          else
            Text(
              isMarkedForDeletion ? 'Se eliminará' : caption,
              maxLines: 1,
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
      barrierColor: EzyColors.surfaceDarkDeep,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: EzyColors.surfaceDarkDeep,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(maxScale: 5, child: Center(child: image)),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close, color: EzyColors.white),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    caption,
                    style: EzyTextStyles.caption.copyWith(
                      color: EzyColors.textSecondaryDark,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Micro-etiqueta «Servidor» con check verde.
class _ServerBadge extends StatelessWidget {
  const _ServerBadge();

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, EzySeverity.success);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.check_circle, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          'Servidor',
          style: EzyTextStyles.badge.copyWith(color: color, letterSpacing: 0.6),
        ),
      ],
    );
  }
}

/// Botón de quitar de una evidencia.
///
/// En los borradores es el círculo rojo del rediseño; en modo edición conserva
/// el icono de alternar borrado.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({
    required this.draft,
    required this.onTap,
    this.tooltip,
    this.icon,
    this.color,
  });

  final bool draft;
  final VoidCallback onTap;
  final String? tooltip;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!draft) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon ?? Icons.cancel, size: 20, color: color),
      );
    }

    final surfaces = context.surfaces;

    return Tooltip(
      message: tooltip ?? 'Descartar foto',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: EzyColors.danger,
            shape: BoxShape.circle,
            border: Border.all(color: surfaces.panel, width: 2),
          ),
          child: const Icon(Icons.close, size: 14, color: EzyColors.white),
        ),
      ),
    );
  }
}

