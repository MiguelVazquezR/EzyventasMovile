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

  /// Valor inicial listo para capturar (`1,240.00`).
  static String format(double value) => Money.formatPlain(value);

  @override
  Widget build(BuildContext context) {
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
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      textStyle:
          (emphasized ? EzyTextStyles.moneyLarge : EzyTextStyles.fieldValue)
              .copyWith(color: context.surfaces.textPrimary),
      onChanged: onChanged == null
          ? null
          : (value) => onChanged!(Money.parseInput(value)),
    );
  }
}
