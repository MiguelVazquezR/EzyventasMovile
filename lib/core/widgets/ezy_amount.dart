import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/money.dart';

/// Escalas del monto (§3): todas con cifras tabulares.
enum EzyAmountSize {
  /// 30 px `w300` — resultado de venta, total a cobrar.
  hero(EzyTextStyles.moneyLarge),

  /// 22 px `w300` — cabeceras de resumen y cortes.
  large(EzyTextStyles.moneyMedium),

  /// 14 px `w700` — montos dentro de listas.
  list(EzyTextStyles.moneyList);

  const EzyAmountSize(this.style);

  final TextStyle style;
}

/// Monto del servidor formateado con cifras tabulares (§8, §10, §12).
///
/// Un solo punto de verdad para el dinero en pantalla: [Money.format] más la
/// escala tipográfica del design system, para que un cambio de formato no se
/// quede a medias en una pantalla concreta.
class EzyAmount extends StatelessWidget {
  const EzyAmount({
    super.key,
    required this.value,
    this.label,
    this.caption,
    this.size = EzyAmountSize.large,
    this.color,
    this.alignment = CrossAxisAlignment.start,
    this.withCurrency = false,
  });

  /// Valor tal como llega del servidor (texto decimal o número).
  final Object? value;

  /// Micro-etiqueta en MAYÚSCULAS sobre el monto (`TOTAL`).
  final String? label;

  /// Texto de apoyo bajo el monto.
  final String? caption;

  final EzyAmountSize size;
  final Color? color;
  final CrossAxisAlignment alignment;

  /// `$1,240.00 MXN` en lugar de `$1,240.00`.
  final bool withCurrency;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final text = withCurrency
        ? Money.formatWithCurrency(value)
        : Money.format(value);

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(
            label!.toUpperCase(),
            style: EzyTextStyles.microLabel.copyWith(color: surfaces.textMuted),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          text,
          style: size.style.copyWith(color: color ?? surfaces.textPrimary),
        ),
        if (caption != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            caption!,
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
