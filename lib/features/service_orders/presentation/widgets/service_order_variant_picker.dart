import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import 'service_order_form_controls.dart';

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
    backgroundColor: SoColors.canvas(context),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          const SizedBox(height: 8),
          SoSheetHeader(
            title: 'Elegir variante',
            subtitle: title,
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 16),
          SoMicroLabel(
            options.length == 1
                ? '1 VARIANTE DISPONIBLE'
                : '${options.length} VARIANTES DISPONIBLES',
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < options.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: 8),
            _VariantRow(
              option: options[index],
              onTap: () => Navigator.of(context).pop(options[index]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Opción de variante como fila seleccionable del design system.
class _VariantRow extends StatefulWidget {
  const _VariantRow({required this.option, required this.onTap});

  final VariantOption option;
  final VoidCallback onTap;

  @override
  State<_VariantRow> createState() => _VariantRowState();
}

class _VariantRowState extends State<_VariantRow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: SoColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed
                ? SoColors.primary
                : SoColors.structuralBorder(context),
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.radio_button_unchecked,
              size: 18,
              color: _pressed ? SoColors.primary : SoColors.textMuted(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EzyTextStyles.bodyStrong.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: SoColors.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Money.format(widget.option.price),
              style: EzyTextStyles.moneyList.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: SoColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
