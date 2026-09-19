import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Micro-etiqueta de campo: 10 px, MAYÚSCULAS, tracking alto (§3).
///
/// Va **fuera** del input (nunca `floatingLabel`), como en la web.
class FieldLabel extends StatelessWidget {
  const FieldLabel(
    this.text, {
    super.key,
    this.isRequired = false,
    this.color,
  });

  final String text;
  final bool isRequired;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final label = isRequired ? '${text.toUpperCase()} *' : text.toUpperCase();

    return Text(
      label,
      style: EzyTextStyles.microLabel.copyWith(
        color: color ?? context.surfaces.textMuted,
      ),
    );
  }
}
