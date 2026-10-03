import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Tokens de color del Centro de soporte (Tesla UI / EzyColors).
///
/// Las superficies (panel, panelInner, bordes y textos) se resuelven con
/// `context.surfaces`; aquí solo viven los acentos semánticos y los hex exactos
/// que dependen del modo claro/oscuro del prototipo validado.
class SupportPalette {
  const SupportPalette._();

  /// Acento primario EzyVentas (`#F68C0F`).
  static const Color accent = EzyColors.primary;
  static const Color accentSoft = Color(0x24F68C0F); // 14 %
  static const Color accentBorder = Color(0x4DF68C0F); // 30 %

  /// Ámbar de aviso («Viene pronto», `#F59E0B`).
  static const Color warnSoft = Color(0x24F59E0B); // 14 %
  static const Color warnBorder = Color(0x59F59E0B); // 35 %
  static const Color warnBannerSoft = Color(0x1AF59E0B); // 10 %
  static const Color warnBannerBorder = Color(0x4DF59E0B); // 30 %

  /// Rojo de peligro (`#F80505`), banner de error.
  static const Color dangerSoft = Color(0x1FF80505); // 12 %
  static const Color dangerBorder = Color(0x4DF80505); // 30 %

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Borde de cards y cuadros: `#3A3A3A` (oscuro) / `#E5E7EB` (claro).
  static Color border(BuildContext context) => isDark(context)
      ? EzyColors.borderDark
      : EzyColors.borderLightStrong;

  /// Divisores internos: `#3A3A3A` al 60 % (oscuro) / `#F3F4F6` (claro).
  static Color divider(BuildContext context) => isDark(context)
      ? EzyColors.borderDark.withValues(alpha: 0.6)
      : EzyColors.borderLight;

  /// Avisos ámbar con contraste: `#FCD34D` (oscuro) / `#B45309` (claro).
  static Color warnText(BuildContext context) =>
      isDark(context) ? EzyColors.warnTextDark : EzyColors.warnTextLight;

  /// Botón deshabilitado «Abrir centro de ayuda».
  static Color disabledBackground(BuildContext context) => isDark(context)
      ? const Color(0x296B7280)
      : EzyColors.borderLight;

  static Color disabledBorder(BuildContext context) => isDark(context)
      ? const Color(0x596B7280)
      : EzyColors.borderLightStrong;

  static Color disabledText(BuildContext context) =>
      isDark(context) ? const Color(0xCC9CA3AF) : EzyColors.neutral;
}

/// Card del Centro de soporte: radio 16, borde de 1 px y `elevation: 0`.
class SupportSectionCard extends StatelessWidget {
  const SupportSectionCard({
    super.key,
    required this.child,
    this.header,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  /// Micro-título en mayúsculas a la izquierda.
  final Widget? header;

  /// Acción/pastilla a la derecha del micro-título.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final hasHeader = header != null || trailing != null;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SupportPalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasHeader) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (header != null)
                  Expanded(child: header!)
                else
                  const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Micro-título de sección: 10 px, `w800`, MAYÚSCULAS, tracking 0.8.
class SupportMicroTitle extends StatelessWidget {
  const SupportMicroTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: EzyTextStyles.microLabel.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: context.surfaces.textBody,
      ),
    );
  }
}

/// Cuadro de icono (chips, horarios y canales) con fondo y borde propios.
class SupportIconBox extends StatelessWidget {
  const SupportIconBox({
    super.key,
    required this.icon,
    this.size = 28,
    this.radius = 8,
    this.iconSize = 15,
    this.background,
    this.border,
    this.color,
  });

  final IconData icon;
  final double size;
  final double radius;
  final double iconSize;
  final Color? background;
  final Color? border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? surfaces.panelInner,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? SupportPalette.border(context)),
      ),
      child: Icon(icon, size: iconSize, color: color ?? surfaces.textMuted),
    );
  }
}
