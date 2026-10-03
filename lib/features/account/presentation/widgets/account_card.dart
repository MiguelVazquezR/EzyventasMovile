import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Tarjeta de la pantalla Cuenta: radio 16 px, borde de 1 px y fondo `panel`
/// (`#232323` oscuro / `#FFFFFF` claro), con micro-título opcional en
/// mayúsculas. Los colores salen de `context.surfaces`, así que el modo claro y
/// el oscuro comparten el mismo código (§2 del rediseño de Cuenta).
class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  /// Micro-título de sección (`MÓDULOS CONTRATADOS`); 10 px, `w800`, mayúsculas.
  final String? title;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Text(
              title!.toUpperCase(),
              style: EzyTextStyles.microLabel.copyWith(
                fontWeight: FontWeight.w800,
                color: surfaces.textBody,
              ),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Cuadro de icono reutilizable (32x32, radio 8) sobre el fondo interno del
/// panel: el mismo truco que `EzyListTile` para que el icono no se pierda.
class AccountIconBox extends StatelessWidget {
  const AccountIconBox({
    super.key,
    required this.icon,
    this.color,
    this.size = 32,
    this.radius = 8,
  });

  final IconData icon;
  final Color? color;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: surfaces.border),
      ),
      child: Icon(
        icon,
        size: size * 0.55,
        color: color ?? surfaces.textSecondary,
      ),
    );
  }
}

/// Pastilla de conteo del sistema: fondo rojo peligro, texto blanco en negrita
/// y formato inteligente (`9+` a partir de diez). Se oculta con conteo `0`.
class AccountCountPill extends StatelessWidget {
  const AccountCountPill({
    super.key,
    required this.count,
    this.fontSize = 10,
    this.background = EzyColors.danger,
  });

  final int count;
  final double fontSize;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: EzyTextStyles.badge.copyWith(
          fontSize: fontSize,
          letterSpacing: 0,
          fontWeight: FontWeight.w800,
          color: EzyColors.white,
        ),
      ),
    );
  }
}
