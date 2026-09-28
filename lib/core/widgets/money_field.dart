import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/money.dart';
import 'ezy_text_field.dart';

/// Campo de dinero del design system.
///
/// Captura en formato `es-MX` (`1,240.00`) y entrega el valor ya convertido a
/// `double` ([Money.parseInput]); nunca se hace aritmética con el texto.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.label,
    this.controller,
    this.onChanged,
    this.hint,
    this.errorText,
    this.helperText,
    this.isRequired = false,
    this.enabled = true,
    this.autofocus = false,
    this.emphasized = false,
    this.prefixIcon = true,
    this.fillColor,
    this.suffixText,
    this.fieldHeight,
    this.borderRadius,
    this.borderColor,
    this.prefixColor,
    this.prefixIconSize = 20,
  });

  final String label;
  final TextEditingController? controller;
  final ValueChanged<double>? onChanged;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final bool isRequired;
  final bool enabled;
  final bool autofocus;

  /// Monto protagonista (arqueo y totales): tipografía grande y fina.
  final bool emphasized;

  /// Muestra el `$` dentro del campo.
  final bool prefixIcon;

  /// Relleno del campo; `null` deja el del tema. Se usa para pintar el campo en
  /// blanco (`surfaces.panel`) cuando la sección que lo contiene es del mismo
  /// color (POS) o cuando el campo flota sobre el lienzo gris de la hoja.
  final Color? fillColor;

  /// Unidad monetaria al final del campo (`MXN` en el rediseño de la hoja).
  final String? suffixText;

  /// Alto nominal del campo (46 px en las hojas del POS).
  final double? fieldHeight;

  /// Radio del borde (12 en las hojas del POS).
  final double? borderRadius;

  /// Color del borde en reposo.
  final Color? borderColor;

  /// Color del `$`; por defecto el tono terciario de la superficie.
  final Color? prefixColor;

  final double prefixIconSize;

  /// Valor inicial listo para capturar (`1,240.00`).
  static String format(double value) => Money.formatPlain(value);

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final suffix = suffixText;
    final fieldStyle =
        (emphasized ? EzyTextStyles.moneyLarge : EzyTextStyles.fieldValue)
            .copyWith(color: surfaces.textPrimary);

    return EzyTextField(
      label: label,
      controller: controller,
      hint: hint,
      errorText: errorText,
      helperText: helperText,
      isRequired: isRequired,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.right,
      prefixIcon: prefixIcon ? Icons.attach_money : null,
      prefixIconColor: prefixColor,
      prefixIconSize: prefixIconSize,
      fillColor: fillColor,
      fieldHeight: fieldHeight,
      borderRadius: borderRadius,
      borderColor: borderColor,
      suffix: suffix == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                suffix,
                style: EzyTextStyles.caption.copyWith(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: surfaces.textMuted,
                ),
              ),
            ),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      textStyle: fieldStyle,
      onChanged: onChanged == null
          ? null
          : (value) => onChanged!(Money.parseInput(value)),
    );
  }
}
