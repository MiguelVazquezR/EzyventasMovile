import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Variantes de acción del design system.
enum EzyButtonVariant { primary, outline, danger, text }

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
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final EzyButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: EzyColors.white,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18),
        if (isLoading || icon != null) const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.button,
          ),
        ),
      ],
    );

    final button = switch (variant) {
      EzyButtonVariant.primary => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        child: child,
      ),
      EzyButtonVariant.danger => FilledButton(
        onPressed: isEnabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: EzyColors.danger,
          foregroundColor: EzyColors.white,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          elevation: 0,
          shape: const StadiumBorder(),
          textStyle: EzyTextStyles.button,
        ),
        child: child,
      ),
      EzyButtonVariant.outline => OutlinedButton(
        onPressed: isEnabled ? onPressed : null,
        child: child,
      ),
      EzyButtonVariant.text => TextButton(
        onPressed: isEnabled ? onPressed : null,
        child: Text(
          label,
          style: EzyTextStyles.button.copyWith(color: EzyColors.primary),
        ),
      ),
    };

    if (!expand) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}
