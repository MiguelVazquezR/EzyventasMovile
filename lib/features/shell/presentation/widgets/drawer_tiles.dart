import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Piezas del menú lateral (`EzyAppDrawer`).
///
/// El panel se lee por bloques: cada sección lleva su rótulo en MAYÚSCULAS y una
/// tarjeta con sus filas dentro, separadas por un divisor **entre** ellas (la
/// última nunca lo lleva). Las filas son táctiles de extremo a extremo, con el
/// icono a la izquierda y el estado (activa, aviso, interruptor) a la derecha.
///
/// Los colores salen siempre de los tokens de superficie del tema
/// (`context.surfaces`), así que la tarjeta queda un paso por encima del fondo
/// del panel tanto en oscuro (#232323 sobre #1A1A1A) como en claro (#FFFFFF
/// sobre #E9EBF0).

/// Color del borde y de los divisores del panel: `border` en oscuro (#3A3A3A) y
/// `borderStrong` en claro (#E5E7EB), que es el trazo visible en cada lienzo.
Color _lineColor(BuildContext context) {
  final surfaces = context.surfaces;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return isDark ? surfaces.border : surfaces.borderStrong;
}

/// Rótulo superior de sección: micro-etiqueta en MAYÚSCULAS sobre el fondo del
/// panel, nunca dentro de la tarjeta.
class DrawerSectionLabel extends StatelessWidget {
  const DrawerSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.microLabel.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: context.surfaces.textMuted,
        ),
      ),
    );
  }
}

/// Tarjeta de sección: agrupa las filas de un bloque con esquinas de 16 px,
/// borde de 1 px y divisores internos de 1 px sangrados 12 px a cada lado.
class DrawerSectionCard extends StatelessWidget {
  const DrawerSectionCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final line = _lineColor(context);
    final radius = BorderRadius.circular(16);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ClipRRect(
        // `antiAlias` recorta las filas al borde redondeado: ni el estado activo
        // ni los divisores se salen de la tarjeta.
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaces.panel,
            borderRadius: radius,
            border: Border.all(color: line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (var index = 0; index < children.length; index++) ...<Widget>[
                children[index],
                // Divisor solo entre filas de la misma sección.
                if (index < children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 12,
                    endIndent: 12,
                    color: line,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de navegación del panel.
///
/// [isPrimary] es la acción de marca (`Nueva venta`): el icono va dentro de un
/// cuadro naranja de 24 px y el título en color primario. [isSelected] marca la
/// pestaña actual: fondo primario al 14 %, filete izquierdo de 3 px, icono y
/// título en naranja y el chip «Activo» a la derecha.
class DrawerNavTile extends StatelessWidget {
  const DrawerNavTile({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.onTap,
    this.isSelected = false,
    this.isPrimary = false,
    this.badgeCount,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isPrimary;

  /// Avisos pendientes: pastilla roja a la derecha (`9+` a partir de diez).
  final int? badgeCount;

  /// Acción propia a la derecha (el interruptor del tema).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final accent = EzyColors.primary;
    final hasBadge = badgeCount != null && badgeCount! > 0;
    final showChevron = onTap != null && trailing == null && !isSelected;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.14) : null,
          // Filete izquierdo del estado activo: 3 px del naranja de marca.
          border: Border(
            left: BorderSide(
              width: 3,
              color: isSelected ? accent : Colors.transparent,
            ),
          ),
        ),
        child: Padding(
          // 9 px + los 3 px del filete = 12 px de respiro a la izquierda.
          padding: const EdgeInsets.fromLTRB(9, 10, 12, 10),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                if (isPrimary)
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 16, color: accent),
                  )
                else
                  Icon(
                    icon,
                    size: 18,
                    color: isSelected ? accent : surfaces.textSecondary,
                  ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        fontSize: 12.5,
                        fontWeight: isSelected || isPrimary
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected || isPrimary
                            ? accent
                            : surfaces.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.secondary.copyWith(
                          fontSize: 10,
                          color: surfaces.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected) ...<Widget>[
                const SizedBox(width: 8),
                const _ActiveChip(),
              ],
              if (hasBadge) ...<Widget>[
                const SizedBox(width: 8),
                _CountBadge(count: badgeCount!),
              ],
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                trailing!,
              ],
              if (showChevron) ...<Widget>[
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: isPrimary ? accent : surfaces.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de la pestaña actual: «Activo» en el naranja de marca.
class _ActiveChip extends StatelessWidget {
  const _ActiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: EzyColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Activo',
        style: EzyTextStyles.microLabel.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: EzyColors.primary,
        ),
      ),
    );
  }
}

/// Pastilla de avisos pendientes: rojo de peligro, cifras blancas.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: EzyColors.danger,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: EzyTextStyles.microLabel.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
          color: EzyColors.white,
        ),
      ),
    );
  }
}

/// Fila destructiva (`Cerrar sesión`): tarjeta roja translúcida con 4 px más de
/// respiro que las secciones, para que se lea como advertencia y no como una
/// fila más del menú. El diálogo de confirmación lo pone quien la usa.
class DrawerDestructiveTile extends StatelessWidget {
  const DrawerDestructiveTile({
    super.key,
    required this.title,
    this.icon,
    this.onTap,
  });

  final String title;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final danger = EzyColors.danger;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: danger.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: danger.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 18, color: danger),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: danger,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: danger),
            ],
          ),
        ),
      ),
    );
  }
}
