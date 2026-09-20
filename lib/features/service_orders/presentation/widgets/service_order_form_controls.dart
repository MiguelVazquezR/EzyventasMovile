import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Control segmentado pill del design system (sustituye al `SelectButton` web).
///
/// Se usa para elegir el tipo de descuento, el tipo de comisión y el catálogo
/// del que sale un concepto.
class ServiceOrderSegmentedControl<T> extends StatelessWidget {
  const ServiceOrderSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          for (final value in values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(value),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: value == selected
                        ? EzyColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    labelOf(value),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.caption.copyWith(
                      color: value == selected
                          ? EzyColors.white
                          : surfaces.textSecondary,
                      fontWeight: value == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
