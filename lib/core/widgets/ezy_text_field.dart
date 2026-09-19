import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'field_label.dart';

/// Campo de texto del design system: borde completo, radio 16, relleno de fondo
/// y etiqueta externa en micro-mayúsculas (§1.7).
class EzyTextField extends StatelessWidget {
  const EzyTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.textStyle,
    this.readOnly = false,
    this.onTap,
    this.autofocus = false,
    this.isRequired = false,
    this.textInputAction,
    this.inputFormatters,
    this.focusNode,
    this.enabled = true,
    this.maxLength,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? errorText;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final TextAlign textAlign;
  final TextStyle? textStyle;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool isRequired;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool enabled;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label, isRequired: isRequired),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLines: maxLines,
          maxLength: maxLength,
          textAlign: textAlign,
          readOnly: readOnly,
          onTap: onTap,
          autofocus: autofocus,
          enabled: enabled,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style:
              textStyle ??
              EzyTextStyles.fieldValue.copyWith(color: surfaces.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            counterText: '',
            prefixIcon: prefixIcon == null
                ? null
                : Icon(prefixIcon, size: 20, color: surfaces.textMuted),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(minWidth: 40),
          ),
        ),
        if (helperText != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: EzyTextStyles.caption.copyWith(color: surfaces.textSecondary),
          ),
        ],
      ],
    );
  }
}
