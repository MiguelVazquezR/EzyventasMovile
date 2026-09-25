import 'package:flutter/material.dart';

import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_selectable_tile.dart';

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
    builder: (sheetContext) =>
        _VariantPickerSheet(title: title, options: options),
  );
}

class _VariantPickerSheet extends StatelessWidget {
  const _VariantPickerSheet({required this.title, required this.options});

  final String title;
  final List<VariantOption> options;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          EzySheetHeader(
            title: 'Elegir variante',
            subtitle: title,
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          for (final option in options)
            EzySelectableTile(
              title: option.label,
              value: Money.format(option.price),
              isSelected: false,
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );
  }
}
