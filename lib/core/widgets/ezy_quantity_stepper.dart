import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/money.dart';

/// Control de cantidad − / + del design system (§10).
///
/// Un solo componente para el detalle de producto y las líneas del carrito: el
/// mismo blanco táctil de 40 px, la misma cifra tabular en el centro y los
/// mismos textos de ayuda. Desactivar un extremo es pasar `null` en
/// [onDecrease] / [onIncrease]: el icono queda en el tono mínimo en lugar de
/// desaparecer, así el control no cambia de tamaño entre estados.
class EzyQuantityStepper extends StatelessWidget {
  const EzyQuantityStepper({
    super.key,
    required this.quantity,
    this.measureUnit,
    this.onDecrease,
    this.onIncrease,
    this.decreaseTooltip = 'Quitar una unidad',
    this.increaseTooltip = 'Agregar una unidad',
  });

  /// Cantidad vigente (`1`, `1.5`, `0.25` en productos a granel).
  final double quantity;

  /// Unidad de medida del catálogo (`pz`, `kg`). Vacía en el carrito, donde la
  /// unidad ya la muestran el nombre y el precio de la línea.
  final String? measureUnit;

  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  final String decreaseTooltip;
  final String increaseTooltip;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final unit = (measureUnit ?? '').isEmpty ? '' : ' ${measureUnit!}';

    return Container(
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepperButton(
            icon: Icons.remove,
            tooltip: decreaseTooltip,
            color: surfaces.textSecondary,
            onPressed: onDecrease,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${Money.formatQuantity(quantity)}$unit',
              style: EzyTextStyles.bodyStrong.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            tooltip: increaseTooltip,
            color: EzyColors.primary,
            onPressed: onIncrease,
          ),
        ],
      ),
    );
  }
}

/// Extremo del control: 40 px de lado, icono de 18 px y tono mínimo apagado.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(
        icon,
        size: 18,
        color: onPressed == null ? surfaces.textMuted : color,
      ),
    );
  }
}
