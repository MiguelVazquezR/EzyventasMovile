import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';

/// Opción de variante del catálogo (servicio o combinación de producto).
class VariantOption {
  const VariantOption({
    required this.id,
    required this.label,
    required this.price,
    required this.itemableType,
  });

  final int id;
  final String label;
  final double price;

  /// `App\Models\ServiceVariant` o `App\Models\ProductAttribute`.
  final String itemableType;
}

/// Selector de variante de un servicio o refacción.
///
/// Se usa cuando el concepto del catálogo tiene variantes: el stock y el precio
/// viven en la variante, no en el producto/servicio base.
Future<VariantOption?> showServiceOrderVariantPicker(
  BuildContext context, {
  required String title,
  required List<VariantOption> options,
}) {
  return showModalBottomSheet<VariantOption>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _VariantPickerSheet(
      title: title,
      options: options,
    ),
  );
}

class _VariantPickerSheet extends StatelessWidget {
  const _VariantPickerSheet({required this.title, required this.options});

  final String title;
  final List<VariantOption> options;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'Elegir variante',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          for (final option in options)
            GestureDetector(
              onTap: () => Navigator.of(context).pop(option),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surfaces.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: surfaces.border),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        option.label,
                        style: EzyTextStyles.bodyStrong.copyWith(
                          color: surfaces.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      Money.format(option.price),
                      style: EzyTextStyles.moneyList.copyWith(
                        color: surfaces.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
