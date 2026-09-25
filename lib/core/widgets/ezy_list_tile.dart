import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Fila de lista del design system: icono en cuadro de 40 px, título, subtítulo,
/// valor y chevron, separada por un divisor de 1 px (§17, §18).
///
/// Sustituye a las tarjetas dentro de tarjetas: la lista se apoya en el panel y
/// los divisores marcan el ritmo, sin sombras ni cards anidadas.
class EzyListTile extends StatelessWidget {
  const EzyListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.value,
    this.valueColor,
    this.onTap,
    this.isDestructive = false,
    this.showDivider = true,
    this.enabled = true,
    this.badgeCount,
    this.badgeColor = EzyColors.danger,
  });

  final String title;
  final String? subtitle;

  /// Icono a la izquierda; el cuadro solo se pinta si hay icono.
  final IconData? icon;

  /// Acción propia a la derecha (interruptor, badge…). Tiene prioridad sobre el
  /// chevron, que solo aparece cuando la fila navega.
  final Widget? trailing;

  /// Dato numérico a la derecha en cifras tabulares.
  final String? value;
  final Color? valueColor;

  final VoidCallback? onTap;

  /// Acción destructiva: el icono y el texto van en rojo.
  final bool isDestructive;
  final bool showDivider;
  final bool enabled;

  /// Avisos pendientes del servidor: se pintan como pastilla a la derecha
  /// (`9+` a partir de diez). Reemplaza al badge hecho a mano de la campana.
  final int? badgeCount;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final accent = isDestructive ? EzyColors.danger : surfaces.textSecondary;
    final foreground = !enabled
        ? surfaces.textMuted
        : (isDestructive ? EzyColors.danger : surfaces.textPrimary);
    final canTap = enabled ? onTap : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          onTap: canTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: <Widget>[
                if (icon != null) ...<Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDestructive
                          ? EzyColors.danger.withValues(alpha: 0.10)
                          : surfaces.panelInner,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDestructive
                            ? EzyColors.danger.withValues(alpha: 0.3)
                            : surfaces.border,
                      ),
                    ),
                    child: Icon(icon, size: 20, color: accent),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: EzyTextStyles.bodyStrong.copyWith(
                          color: foreground,
                        ),
                      ),
                      if (subtitle != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: EzyTextStyles.secondary.copyWith(
                            color: surfaces.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...<Widget>[
                  const SizedBox(width: 12),
                  Text(
                    value!,
                    style: EzyTextStyles.moneyList.copyWith(
                      color: valueColor ?? surfaces.textPrimary,
                    ),
                  ),
                ],
                if (badgeCount != null && badgeCount! > 0) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeCount! > 9 ? '9+' : '${badgeCount!}',
                      style: EzyTextStyles.badge.copyWith(
                        color: EzyColors.white,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 10),
                  trailing!,
                ],
                if (trailing == null && canTap != null) ...<Widget>[
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
