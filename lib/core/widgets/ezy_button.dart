import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Variantes de acción del design system.
///
/// `info` (azul Bluetooth) e `whatsApp` (verde) son acciones con color propio:
/// el color identifica la acción, no el estado.
enum EzyButtonVariant { primary, outline, danger, text, info, whatsApp }

/// Botón pill de 48 px de alto como mínimo (§4).
///
/// El spinner vive **dentro** del botón durante las peticiones, sin bloquear la
/// pantalla.
class EzyButton extends StatelessWidget {
  const EzyButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = EzyButtonVariant.primary,
    this.expand = true,
    this.height,
    this.textColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final EzyButtonVariant variant;
  final bool expand;

  /// Alto propio (por defecto el mínimo del design system, 48 px).
  final double? height;

  /// Color del texto de la variante [EzyButtonVariant.text]; por defecto el
  /// naranja de marca. La variante `text` de un enlace secundario (la web del
  /// login) usa el tono apagado de la superficie.
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    // La variante `text` pinta su etiqueta en naranja (o en el tono que pida
    // [textColor]); el resto hereda el color del botón.
    final labelColor = variant == EzyButtonVariant.text
        ? (textColor ?? EzyColors.primary)
        : null;
    final foreground = _foreground;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (isLoading)
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: labelColor),
        if (isLoading || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.button.copyWith(color: labelColor),
          ),
        ),
      ],
    );

    final button = switch (variant) {
      EzyButtonVariant.primary => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        child: child,
      ),
      EzyButtonVariant.info => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: _filledStyle(EzyColors.bluetooth, foreground),
        child: child,
      ),
      EzyButtonVariant.whatsApp => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: _filledStyle(EzyColors.whatsApp, foreground),
        child: child,
      ),
      EzyButtonVariant.danger => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: _filledStyle(EzyColors.danger, EzyColors.white),
        child: child,
      ),
      EzyButtonVariant.outline => OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        child: child,
      ),
      EzyButtonVariant.text => TextButton(
        onPressed: isEnabled ? onPressed : null,
        child: child,
      ),
    };

    if (!expand) {
      return button;
    }

    return SizedBox(width: double.infinity, height: height, child: button);
  }

  /// Color del texto y del spinner de las variantes rellenas.
  Color get _foreground => switch (variant) {
    EzyButtonVariant.whatsApp => EzyColors.black1,
    _ => EzyColors.white,
  };

  static ButtonStyle _filledStyle(Color background, Color foreground) =>
      FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: foreground,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        elevation: 0,
        shape: const StadiumBorder(),
        textStyle: EzyTextStyles.button,
      );
}
