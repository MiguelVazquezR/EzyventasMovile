import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/status_palette.dart';

/// Variantes de acción del design system.
///
/// `info` (azul Bluetooth) e `whatsApp` (verde) son acciones con color propio:
/// el color identifica la acción, no el estado. `outlinePrimary` es el contorno
/// de marca —acción secundaria que sigue perteneciendo al naranja— y `warn` el
/// relleno ámbar suave de las acciones «de aviso» que no llegan a destructivas.
enum EzyButtonVariant {
  primary,
  outline,
  outlinePrimary,
  danger,
  text,
  info,
  whatsApp,
  warn,
}

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
    final surfaces = context.surfaces;
    final isEnabled = onPressed != null && !isLoading;
    // La variante `text` pinta su etiqueta en naranja (o en el tono que pida
    // [textColor]); el resto hereda el color del botón. Apagada, la etiqueta se
    // queda en el tono de la superficie: un color propio no puede hacer pasar por
    // activa una acción deshabilitada (`Vaciar carrito` con el carrito vacío).
    final labelColor = variant != EzyButtonVariant.text
        ? null
        : isEnabled
        ? (textColor ?? EzyColors.primary)
        : surfaces.textMuted;
    final foreground = _foreground(context);

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
      // Contorno de marca: la acción secundaria que sigue siendo del naranja
      // (`Pedido` del carrito) sin competir con el relleno primario.
      EzyButtonVariant.outlinePrimary => OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: EzyColors.primary,
          disabledForegroundColor: surfaces.textMuted,
          side: BorderSide(
            color: isEnabled ? EzyColors.primary : surfaces.borderStrong,
          ),
        ),
        child: child,
      ),
      // Ámbar suave: reservar deja el producto apartado sin cobrarlo, así que no
      // puede vestirse de primario ni de destructivo.
      EzyButtonVariant.warn => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: _softStyle(
          EzySeverity.warn,
          foreground: foreground,
          border: isEnabled
              ? StatusPalette.border(EzySeverity.warn)
              : surfaces.border,
          disabledBackground: surfaces.panelInner,
          disabledForeground: surfaces.textMuted,
        ),
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

  /// Color del texto y del spinner de las variantes que no heredan el del tema.
  Color _foreground(BuildContext context) => switch (variant) {
    EzyButtonVariant.whatsApp => EzyColors.black1,
    // El ámbar suave necesita el tono legible sobre ese fondo, que cambia con el
    // modo claro/oscuro.
    EzyButtonVariant.warn => StatusPalette.text(context, EzySeverity.warn),
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

  /// Relleno con el tinte suave de una severidad: fondo al 12 %, borde al 30 % y
  /// texto en el tono legible sobre ese fondo (`StatusPalette`).
  ///
  /// Los colores del estado deshabilitado se pasan aparte: un `styleFrom` con
  /// colores propios no los hereda del tema y el botón apagado se vería encendido
  /// —en el carrito `Apartar` vive deshabilitado la mitad del tiempo—.
  static ButtonStyle _softStyle(
    EzySeverity severity, {
    required Color foreground,
    required Color border,
    required Color disabledBackground,
    required Color disabledForeground,
  }) => FilledButton.styleFrom(
    backgroundColor: StatusPalette.soft(severity),
    foregroundColor: foreground,
    disabledBackgroundColor: disabledBackground,
    disabledForegroundColor: disabledForeground,
    side: BorderSide(color: border),
    minimumSize: const Size(0, 48),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    elevation: 0,
    shape: const StadiumBorder(),
    textStyle: EzyTextStyles.button,
  );
}
