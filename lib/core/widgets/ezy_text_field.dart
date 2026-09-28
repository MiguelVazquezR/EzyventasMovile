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
    this.fillColor,
    this.fieldHeight,
    this.borderRadius,
    this.borderColor,
    this.prefixIconColor,
    this.prefixIconSize = 20,
    this.showCounter = false,
    this.labelTrailing,
    this.requiredMarkColor,
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

  /// Relleno del campo. Sin él manda el tema (`panelInner`); sobre un lienzo gris
  /// la hoja del cliente pasa `panel` para que el campo se lea blanco, como las
  /// secciones que lo rodean.
  final Color? fillColor;

  /// Alto nominal del campo (§1 y §5 de los rediseños de hoja: 46 px). Sin él el
  /// campo conserva el relleno del tema; con él el texto se centra en la altura
  /// pedida para que el alto no dependa del `contentPadding` global.
  final double? fieldHeight;

  /// Radio del borde. Sin él el campo sigue con el radio 16 del tema; las hojas
  /// del POS —campos dentro de cards— lo bajan a 12.
  final double? borderRadius;

  /// Color del borde en reposo (las hojas del POS pasan `surfaces.borderStrong`).
  final Color? borderColor;

  /// Color del icono prefijo; por defecto el tono terciario de la superficie.
  final Color? prefixIconColor;

  final double prefixIconSize;

  /// Muestra el contador de caracteres del `maxLength` (`0/255`). Por defecto se
  /// oculta: en un campo de una línea el contador empujaba el layout.
  final bool showCounter;

  /// Contador o aviso corto alineado a la derecha de la etiqueta (`0/255`,
  /// `MÁX. 20`). Las hojas que muestran el tope de caracteres en la propia
  /// micro-etiqueta lo pasan aquí en vez de encender [showCounter].
  final Widget? labelTrailing;

  /// Color del `*` de obligatorio; sin él hereda el tono apagado de la etiqueta.
  final Color? requiredMarkColor;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final radius = borderRadius;
    final fieldStyle =
        textStyle ??
        EzyTextStyles.fieldValue.copyWith(color: surfaces.textPrimary);

    OutlineInputBorder? outline(Color color, double width) {
      if (radius == null) {
        return null;
      }

      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(
          label,
          isRequired: isRequired,
          trailing: labelTrailing,
          requiredMarkColor: requiredMarkColor,
        ),
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
          style: fieldStyle,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            counterText: showCounter ? null : '',
            counterStyle: EzyTextStyles.caption.copyWith(
              fontSize: 11,
              color: surfaces.textMuted,
            ),
            fillColor: fillColor,
            contentPadding: _contentPadding(fieldStyle),
            border: outline(borderColor ?? surfaces.border, 1),
            enabledBorder: outline(borderColor ?? surfaces.border, 1),
            focusedBorder: outline(EzyColors.primary, 1.5),
            errorBorder: outline(EzyColors.danger, 1),
            focusedErrorBorder: outline(EzyColors.danger, 1.5),
            prefixIcon: prefixIcon == null
                ? null
                : Icon(
                    prefixIcon,
                    size: prefixIconSize,
                    color: prefixIconColor ?? surfaces.textMuted,
                  ),
            suffixIcon: suffix,
            suffixIconConstraints: const BoxConstraints(minWidth: 40),
          ),
        ),
        if (helperText != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: EzyTextStyles.caption.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  /// Relleno vertical que centra el texto en [fieldHeight] (46 px en las hojas).
  EdgeInsetsGeometry? _contentPadding(TextStyle style) {
    final height = fieldHeight;
    if (height == null) {
      return null;
    }

    // Multilínea (dirección y notas): el alto lo fijan las líneas, no el token.
    if (maxLines > 1) {
      return const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    }

    final fontSize = style.fontSize ?? 15;
    final lineHeight = fontSize * (style.height ?? 1.3);
    final vertical = ((height - lineHeight) / 2).clamp(8.0, 20.0);

    return EdgeInsets.symmetric(horizontal: 14, vertical: vertical);
  }
}
