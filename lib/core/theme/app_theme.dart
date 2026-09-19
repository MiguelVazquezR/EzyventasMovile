import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Tema "Tesla UI": superficies matte, **sin sombras** (la jerarquía se resuelve
/// con color de superficie + borde de 1 px) y radios grandes (24 contenedores,
/// 16 cards/inputs, pill botones).
class EzyTheme {
  const EzyTheme._();

  /// Modo oscuro: el predeterminado y la referencia visual.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surfaces = isDark ? EzySurfaces.dark : EzySurfaces.light;
    final base = isDark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);

    const radius16 = BorderRadius.all(Radius.circular(16));
    const radius24 = BorderRadius.all(Radius.circular(24));

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: EzyColors.primary,
          brightness: brightness,
        ).copyWith(
          primary: EzyColors.primary,
          onPrimary: EzyColors.white,
          secondary: EzyColors.secondary,
          onSecondary: EzyColors.black1,
          error: EzyColors.danger,
          onError: EzyColors.white,
          surface: surfaces.panel,
          onSurface: surfaces.textPrimary,
          surfaceContainerHighest: surfaces.panelInner,
          outline: surfaces.border,
          outlineVariant: surfaces.border,
        );

    return base.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaces.background,
      canvasColor: surfaces.background,
      extensions: <ThemeExtension<dynamic>>[surfaces],
      textTheme: base.textTheme.apply(
        fontFamily: EzyTextStyles.fontFamily,
        bodyColor: surfaces.textPrimary,
        displayColor: surfaces.textPrimary,
      ),
      iconTheme: IconThemeData(color: surfaces.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaces.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: surfaces.textPrimary),
        titleTextStyle: EzyTextStyles.screenTitle.copyWith(
          color: surfaces.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaces.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius24,
          side: BorderSide(color: surfaces.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: surfaces.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaces.panelInner,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: EzyTextStyles.fieldValue.copyWith(
          color: surfaces.textMuted,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: EzyTextStyles.microLabel.copyWith(color: surfaces.textMuted),
        errorStyle: EzyTextStyles.caption.copyWith(color: EzyColors.danger),
        border: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: surfaces.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: surfaces.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: EzyColors.primary, width: 1.4),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: EzyColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: radius16,
          borderSide: BorderSide(color: EzyColors.danger, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: EzyColors.primary,
          foregroundColor: EzyColors.white,
          disabledBackgroundColor: isDark
              ? EzyColors.gray37
              : EzyColors.grayD9,
          disabledForegroundColor: isDark
              ? EzyColors.gray99
              : EzyColors.gray66,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: EzyTextStyles.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: surfaces.textPrimary,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: BorderSide(color: surfaces.borderStrong),
          shape: const StadiumBorder(),
          textStyle: EzyTextStyles.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: EzyColors.primary,
          minimumSize: const Size(0, 44),
          textStyle: EzyTextStyles.button,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: surfaces.textSecondary,
          minimumSize: const Size(44, 44),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaces.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius24,
          side: BorderSide(color: surfaces.border),
        ),
        titleTextStyle: EzyTextStyles.bodyStrong.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: surfaces.textPrimary,
        ),
        contentTextStyle: EzyTextStyles.body.copyWith(
          color: surfaces.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaces.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: surfaces.borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: surfaces.panel,
        contentTextStyle: EzyTextStyles.body.copyWith(
          color: surfaces.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: radius16,
          side: BorderSide(color: surfaces.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaces.panel,
        surfaceTintColor: Colors.transparent,
        indicatorColor: EzyColors.primary.withValues(alpha: 0.14),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? EzyColors.primary : surfaces.textMuted,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return EzyTextStyles.badge.copyWith(
            color: selected ? EzyColors.primary : surfaces.textMuted,
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaces.panelInner,
        selectedColor: EzyColors.primary.withValues(alpha: 0.16),
        side: BorderSide(color: surfaces.border),
        labelStyle: EzyTextStyles.caption.copyWith(
          color: surfaces.textSecondary,
        ),
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: EzyColors.primary,
        linearTrackColor: Colors.transparent,
        circularTrackColor: Colors.transparent,
        strokeWidth: 3,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? EzyColors.white
              : surfaces.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? EzyColors.primary
              : surfaces.panelInner,
        ),
        trackOutlineColor: WidgetStateProperty.all(surfaces.borderStrong),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: surfaces.textPrimary,
        iconColor: surfaces.textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surfaces.border),
        ),
        textStyle: EzyTextStyles.caption.copyWith(
          color: surfaces.textPrimary,
        ),
      ),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
