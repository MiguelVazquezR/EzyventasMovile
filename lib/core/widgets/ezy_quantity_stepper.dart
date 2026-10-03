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
///
/// Con [EzyQuantityStepperStyle.box] el control cambia de piel —caja de radio
/// 12 px, fondo `panelInner`, borde fuerte y el «+» resaltado en el naranja de
/// marca— para el detalle de producto (§5 de su rediseño), sin tocar el pill
/// que usan las líneas del carrito.
enum EzyQuantityStepperStyle {
  /// Pill de 999: el control de las líneas del carrito.
  pill,

  /// Caja de 12 px con el «+» resaltado: el del detalle de producto.
  box,
}

class EzyQuantityStepper extends StatelessWidget {
  const EzyQuantityStepper({
    super.key,
    required this.quantity,
    this.measureUnit,
    this.onDecrease,
    this.onIncrease,
    this.decreaseTooltip = 'Quitar una unidad',
    this.increaseTooltip = 'Agregar una unidad',
    this.style = EzyQuantityStepperStyle.pill,
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

  /// Piel del control: el pill del carrito o la caja del detalle de producto.
  final EzyQuantityStepperStyle style;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final unit = (measureUnit ?? '').isEmpty ? '' : ' ${measureUnit!}';
    final boxed = style == EzyQuantityStepperStyle.box;

    return Container(
      decoration: BoxDecoration(
        color: boxed ? surfaces.panelInner : surfaces.panel,
        borderRadius: BorderRadius.circular(boxed ? 12 : 999),
        border: Border.all(
          color: boxed ? surfaces.borderStrong : surfaces.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepperButton(
            icon: Icons.remove,
            tooltip: decreaseTooltip,
            color: surfaces.textSecondary,
            onPressed: onDecrease,
            size: boxed ? 36 : 40,
            iconSize: boxed ? 16 : 18,
            radius: boxed ? 10 : 999,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: boxed ? 4 : 6),
            child: Text(
              '${Money.formatQuantity(quantity)}$unit',
              style: EzyTextStyles.bodyStrong.copyWith(
                fontSize: boxed ? 13 : null,
                fontWeight: boxed ? FontWeight.w900 : null,
                color: surfaces.textPrimary,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            tooltip: increaseTooltip,
            color: EzyColors.primary,
            onPressed: onIncrease,
            size: boxed ? 36 : 40,
            iconSize: boxed ? 16 : 18,
            radius: boxed ? 10 : 999,
            // §5: el «+» es la acción principal del control y va resaltado.
            background: boxed
                ? EzyColors.primary.withValues(alpha: 0.15)
                : null,
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
    this.size = 40,
    this.iconSize = 18,
    this.radius = 999,
    this.background,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onPressed;

  /// Lado del blanco táctil (36 px en la caja del detalle de producto).
  final double size;
  final double iconSize;

  /// Radio del resaltado del extremo.
  final double radius;

  /// Relleno del extremo; solo lo lleva el «+» de la caja.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      style: IconButton.styleFrom(
        backgroundColor: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      icon: Icon(
        icon,
        size: iconSize,
        color: onPressed == null ? surfaces.textMuted : color,
      ),
    );
  }
}
