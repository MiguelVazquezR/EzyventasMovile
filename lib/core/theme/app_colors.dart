import 'package:flutter/material.dart';

/// Paleta de marca EzyVentas (Design system "Tesla UI", §2).
///
/// Los valores son los hex exactos del preset web (`tailwind.config.js`).
class EzyColors {
  const EzyColors._();

  // Primario (naranja EzyVentas)
  static const Color primary50 = Color(0xFFFEF4E7);
  static const Color primary100 = Color(0xFFFDE6C8);
  static const Color primary200 = Color(0xFFFBD3A0);
  static const Color primary300 = Color(0xFFF9B96F);
  static const Color primary400 = Color(0xFFF79F43);
  static const Color primary = Color(0xFFF68C0F); // primary-500
  static const Color primary600 = Color(0xFFE47909);
  static const Color primary700 = Color(0xFFBB610A);
  static const Color primary800 = Color(0xFF984E0F);
  static const Color primary900 = Color(0xFF7C4112);
  static const Color primary950 = Color(0xFF422007);

  // Acentos y semánticos
  static const Color primaryLight = Color(0xFFFCDCB5);
  static const Color secondary = Color(0xFFE9A527);
  static const Color secondaryLight = Color(0xFFF8E2BA);
  static const Color danger = Color(0xFFF80505);

  /// Estados de ventas y órdenes (§7 del design system).
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color neutral = Color(0xFF6B7280);

  /// Verde de WhatsApp: botón de envío del ticket por chat.
  static const Color whatsApp = Color(0xFF25D366);

  /// Azul de Bluetooth: botones de impresora (buscar, conectar, cambiar).
  static const Color bluetooth = Color(0xFF3B82F6);


  // Neutros
  static const Color grayF2 = Color(0xFFF2F2F2);
  static const Color grayD9 = Color(0xFFD9D9D9);
  static const Color gray99 = Color(0xFF999999);
  static const Color gray9A = Color(0xFF9A9A9A);
  static const Color gray77 = Color(0xFF777777);
  static const Color gray66 = Color(0xFF666666);
  static const Color gray4A = Color(0xFF4A4A4A);
  static const Color gray37 = Color(0xFF373737);
  static const Color black1 = Color(0xFF1A1A1A);
  static const Color black2 = Color(0xFF0D0D0D);

  // Superficies
  static const Color surfaceDark = Color(0xFF232323); // paneles / cards
  static const Color surfaceDarkInner = Color(0xFF1A1A1A); // fondo / inputs
  static const Color surfaceDarkDeep = Color(0xFF0D0D0D);
  static const Color borderDark = Color(0xFF3A3A3A);
  static const Color borderDarkStrong = Color(0xFF4A4A4A);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceLightInner = Color(0xFFF9FAFB);

  /// Lienzo del tema claro (fondo de la app): un gris un paso más oscuro que el
  /// blanco de cards, filtros y campos, para que estos se despeguen del fondo.
  static const Color surfaceLightCanvas = Color(0xFFE9EBF0);

  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderLightStrong = Color(0xFFE5E7EB);

  // Texto (§6 y §13: umbrales de contraste obligatorios)
  // Títulos de pantalla, montos, folios y nombres.
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF111827);
  // Cuerpo y datos de listas.
  static const Color textBodyDark = Color(0xFFE5E7EB);
  static const Color textBodyLight = Color(0xFF1F2937);
  // Texto de apoyo: folios, fechas, ayudas.
  static const Color textSecondaryDark = Color(0xFFD1D5DB);
  static const Color textSecondaryLight = Color(0xFF374151);
  // Micro-etiquetas y textos terciarios (mínimo permitido).
  static const Color textMutedDark = Color(0xFF9CA3AF);
  static const Color textMutedLight = Color(0xFF4B5563);

  // Tonos de texto de los badges de estatus (§13).
  static const Color successTextDark = Color(0xFF86EFAC);
  static const Color successTextLight = Color(0xFF15803D);
  static const Color warnTextDark = Color(0xFFFCD34D);
  static const Color warnTextLight = Color(0xFFB45309);
  static const Color infoTextDark = Color(0xFF93C5FD);
  static const Color infoTextLight = Color(0xFF1D4ED8);
  static const Color dangerTextDark = Color(0xFFFCA5A5);
  static const Color dangerTextLight = Color(0xFFB91C1C);
  static const Color neutralTextDark = Color(0xFFD1D5DB);
  static const Color neutralTextLight = Color(0xFF4B5563);

  static const Color white = Color(0xFFFFFFFF);
}

/// Superficies semánticas resueltas por tema.
///
/// Los widgets leen `context.surfaces` en lugar de preguntar por el
/// `Brightness`, de modo que el modo oscuro (predeterminado) y el claro
/// comparten el mismo código.
@immutable
class EzySurfaces extends ThemeExtension<EzySurfaces> {
  const EzySurfaces({
    required this.panel,
    required this.panelInner,
    required this.background,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textBody,
    required this.textSecondary,
    required this.textMuted,
    required this.onPrimary,
  });

  /// Card / panel (`#232323` en oscuro).
  final Color panel;

  /// Inputs y cards internas (`#1A1A1A` en oscuro).
  final Color panelInner;

  /// Fondo detrás de todo.
  final Color background;

  final Color border;
  final Color borderStrong;

  /// Títulos, montos, folios y nombres.
  final Color textPrimary;

  /// Cuerpo y datos de listas.
  final Color textBody;

  /// Texto de apoyo: folios, fechas, ayudas.
  final Color textSecondary;

  /// Micro-etiquetas y textos terciarios (tono mínimo permitido).
  final Color textMuted;

  final Color onPrimary;

  static const EzySurfaces dark = EzySurfaces(
    panel: EzyColors.surfaceDark,
    panelInner: EzyColors.surfaceDarkInner,
    background: EzyColors.surfaceDarkInner,
    border: EzyColors.borderDark,
    borderStrong: EzyColors.borderDarkStrong,
    textPrimary: EzyColors.textPrimaryDark,
    textBody: EzyColors.textBodyDark,
    textSecondary: EzyColors.textSecondaryDark,
    textMuted: EzyColors.textMutedDark,
    onPrimary: EzyColors.white,
  );

  static const EzySurfaces light = EzySurfaces(
    panel: EzyColors.surfaceLight,
    panelInner: EzyColors.surfaceLightInner,
    background: EzyColors.surfaceLightCanvas,
    border: EzyColors.borderLight,
    borderStrong: EzyColors.borderLightStrong,
    textPrimary: EzyColors.textPrimaryLight,
    textBody: EzyColors.textBodyLight,
    textSecondary: EzyColors.textSecondaryLight,
    textMuted: EzyColors.textMutedLight,
    onPrimary: EzyColors.white,
  );

  @override
  EzySurfaces copyWith({
    Color? panel,
    Color? panelInner,
    Color? background,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textBody,
    Color? textSecondary,
    Color? textMuted,
    Color? onPrimary,
  }) {
    return EzySurfaces(
      panel: panel ?? this.panel,
      panelInner: panelInner ?? this.panelInner,
      background: background ?? this.background,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textBody: textBody ?? this.textBody,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      onPrimary: onPrimary ?? this.onPrimary,
    );
  }

  @override
  EzySurfaces lerp(ThemeExtension<EzySurfaces>? other, double t) {
    if (other is! EzySurfaces) {
      return this;
    }

    return EzySurfaces(
      panel: Color.lerp(panel, other.panel, t) ?? panel,
      panelInner: Color.lerp(panelInner, other.panelInner, t) ?? panelInner,
      background: Color.lerp(background, other.background, t) ?? background,
      border: Color.lerp(border, other.border, t) ?? border,
      borderStrong:
          Color.lerp(borderStrong, other.borderStrong, t) ?? borderStrong,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textBody: Color.lerp(textBody, other.textBody, t) ?? textBody,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t) ?? onPrimary,
    );
  }
}

/// Atajo `context.surfaces` para no repetir `Theme.of(context).extension(...)`.
extension EzyThemeContext on BuildContext {
  EzySurfaces get surfaces =>
      Theme.of(this).extension<EzySurfaces>() ?? EzySurfaces.dark;

  ColorScheme get colors => Theme.of(this).colorScheme;
}
