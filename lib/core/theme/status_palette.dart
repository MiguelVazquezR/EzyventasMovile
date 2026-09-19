import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Severidades del design system (§7 y §13).
enum EzySeverity { success, warn, info, danger, neutral }

/// Colores de cada severidad: color pleno, tono de texto por modo y utilidades
/// para fondos y bordes de badge/banner.
class StatusPalette {
  const StatusPalette._();

  /// Color pleno de la severidad.
  static Color base(EzySeverity severity) => switch (severity) {
    EzySeverity.success => EzyColors.success,
    EzySeverity.warn => EzyColors.warning,
    EzySeverity.info => EzyColors.info,
    EzySeverity.danger => EzyColors.danger,
    EzySeverity.neutral => EzyColors.neutral,
  };

  /// Tono de texto legible sobre el fondo translúcido del badge.
  static Color text(BuildContext context, EzySeverity severity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return switch (severity) {
      EzySeverity.success =>
        isDark ? EzyColors.successTextDark : EzyColors.successTextLight,
      EzySeverity.warn =>
        isDark ? EzyColors.warnTextDark : EzyColors.warnTextLight,
      EzySeverity.info =>
        isDark ? EzyColors.infoTextDark : EzyColors.infoTextLight,
      EzySeverity.danger =>
        isDark ? EzyColors.dangerTextDark : EzyColors.dangerTextLight,
      EzySeverity.neutral =>
        isDark ? EzyColors.neutralTextDark : EzyColors.neutralTextLight,
    };
  }

  /// Fondo del badge/banner: color pleno al 12 %.
  static Color soft(EzySeverity severity) =>
      base(severity).withValues(alpha: 0.12);

  /// Borde del badge/banner: color pleno al 30 %.
  static Color border(EzySeverity severity) =>
      base(severity).withValues(alpha: 0.3);
}
