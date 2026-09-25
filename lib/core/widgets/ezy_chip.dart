import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/status_palette.dart';

/// Chip pill del design system: radio 999 y borde de 1 px (§3, §12, §14).
///
/// Se usa para estatus de ventas, filtros, accesos rápidos y las etiquetas de
/// un dato (sucursal, propietario, correo sin verificar). El estado
/// seleccionado es el único que lleva el naranja de marca, y el naranja solo
/// aparece ahí (§23.11); con [tone] manda el color del estatus.
class EzyChip extends StatelessWidget {
  const EzyChip({
    super.key,
    required this.label,
    this.onTap,
    this.selected = false,
    this.icon,
    this.count,
    this.compact = false,
    this.tone,
    this.inner = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;

  /// Conteo opcional a la derecha del texto (`12`).
  final int? count;

  /// 32 px en lugar de 36 px: para barras de filtros densas.
  final bool compact;

  /// `true` para chips dentro de una tarjeta (fondo `panelInner`, el mismo truco
  /// que [SectionCard.inner]): así el chip no se pierde sobre el panel.
  final bool inner;

  /// Tono de estatus del chip: pinta el texto, el fondo y el borde con el color
  /// del estado (`warn` para "Correo sin verificar"). Tiene prioridad sobre
  /// [selected]: un dato con estatus no es una opción elegible.
  final EzySeverity? tone;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final status = tone;
    final foreground = status != null
        ? StatusPalette.text(context, status)
        : (selected ? EzyColors.primary : surfaces.textSecondary);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: compact ? 32 : 36,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
        decoration: BoxDecoration(
          color: status != null
              ? StatusPalette.soft(status)
              : selected
              ? EzyColors.primary.withValues(alpha: 0.14)
              : (inner ? surfaces.panelInner : surfaces.panel),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: status != null
                ? StatusPalette.border(status)
                : selected
                ? EzyColors.primary.withValues(alpha: 0.45)
                : surfaces.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: EzyTextStyles.caption.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (count != null) ...<Widget>[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: EzyTextStyles.badge.copyWith(
                  color: foreground,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
