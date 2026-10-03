import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Fila de una categoría de la campana (§14.6).
///
/// Cuadro de icono de 40 px (radio 12), título y descripción, pastilla de conteo
/// del servidor (`9+` a partir de diez, oculta en `0`) y chevron **solo** cuando
/// la categoría abre una pantalla en la app (`onTap != null`).
class NotificationCategoryTile extends StatelessWidget {
  const NotificationCategoryTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Conteo del servidor: `0` oculta la pastilla; a partir de diez pinta `9+`.
  final int count;

  /// `null` cuando la categoría se explica pero no navega (Novedades, pedidos
  /// de la tienda en línea): la fila no muestra chevron.
  final VoidCallback? onTap;

  final bool showDivider;

  bool get _canNavigate => onTap != null;

  /// Texto de la pastilla, o `null` cuando no hay nada que mostrar.
  String? get _badgeText {
    if (count <= 0) {
      return null;
    }

    return count >= 10 ? '9+' : '$count';
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final badgeText = _badgeText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: surfaces.panelInner,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: surfaces.border),
                  ),
                  child: Icon(icon, size: 20, color: surfaces.textSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: EzyTextStyles.bodyStrong.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: surfaces.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: surfaces.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeText != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    height: 20,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: EzyColors.danger,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText,
                      style: EzyTextStyles.badge.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                        color: EzyColors.white,
                      ),
                    ),
                  ),
                ],
                if (_canNavigate) ...<Widget>[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: surfaces.textMuted,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: surfaces.border,
          ),
      ],
    );
  }
}
