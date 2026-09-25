import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../data/models/cart_line.dart';

/// Línea del carrito: cantidad ±, descuento por unidad y total de la línea.
class CartLineTile extends ConsumerWidget {
  const CartLineTile({super.key, required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final controller = ref.read(cartControllerProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(16),
        // Franja de la marca a la izquierda: separa cada producto del carrito.
        border: Border(
          top: BorderSide(color: surfaces.border),
          right: BorderSide(color: surfaces.border),
          bottom: BorderSide(color: surfaces.border),
          left: BorderSide(
            color: EzyColors.primary.withValues(alpha: 0.55),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      line.productName,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        color: surfaces.textPrimary,
                      ),
                    ),
                    if (line.variantLabel != null &&
                        line.variantLabel!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        line.variantLabel!,
                        style: EzyTextStyles.secondary.copyWith(
                          color: surfaces.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      '${Money.format(line.unitPrice)} c/u',
                      style: EzyTextStyles.caption.copyWith(
                        color: surfaces.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => controller.removeLine(line),
                tooltip: 'Quitar del carrito',
                icon: Icon(Icons.close, size: 18, color: surfaces.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _QuantityStepper(line: line),
              const Spacer(),
              Text(
                Money.format(line.lineTotal),
                style: EzyTextStyles.moneyList.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ],
          ),
          if (line.hasDiscount) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Descuento ${Money.format(line.discountPerUnit)} por unidad · '
              '${line.discountReason ?? ''}',
              style: EzyTextStyles.caption.copyWith(
                color: StatusPalette.text(context, EzySeverity.success),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) =>
                    _CartLineEditorDialog(line: line),
              ),
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Editar cantidad y descuento',
                style: EzyTextStyles.caption.copyWith(
                  color: EzyColors.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: EzyColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cantidad con botones − / + (paso 1, o 0.5 en productos a granel).
class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartControllerProvider.notifier);
    final surfaces = context.surfaces;

    return Container(
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            onPressed: () => controller.decrementLine(line),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Quitar una unidad',
            icon: Icon(
              Icons.remove,
              size: 18,
              color: surfaces.textSecondary,
            ),
          ),
          Text(
            Money.formatQuantity(line.quantity),
            style: EzyTextStyles.bodyStrong.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => controller.incrementLine(line),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: 'Agregar una unidad',
            icon: const Icon(Icons.add, size: 18, color: EzyColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Editor de la línea: cantidad y descuento por unidad (con `pos.edit_prices`).
class _CartLineEditorDialog extends ConsumerStatefulWidget {
  const _CartLineEditorDialog({required this.line});

  final CartLine line;

  @override
  ConsumerState<_CartLineEditorDialog> createState() =>
      _CartLineEditorDialogState();
}

class _CartLineEditorDialogState extends ConsumerState<_CartLineEditorDialog> {
  late final TextEditingController _quantityController = TextEditingController(
    text: Money.formatQuantity(widget.line.quantity),
  );
  late final TextEditingController _discountController = TextEditingController(
    text: MoneyField.format(widget.line.discountPerUnit),
  );

  double _quantity = 1;
  double _discount = 0;

  @override
  void initState() {
    super.initState();
    _quantity = widget.line.quantity;
    _discount = widget.line.discountPerUnit;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final controller = ref.read(cartControllerProvider.notifier);
    final canEditPrices = ref.watch(permissionsProvider).can('pos.edit_prices');

    return AlertDialog(
      title: Text(widget.line.productName),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            EzyTextField(
              label: 'Cantidad',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.right,
              controller: _quantityController,
              helperText: widget.line.isBulk
                  ? 'Producto a granel: admite decimales.'
                  : 'Stock disponible: '
                        '${Money.formatQuantity(widget.line.stockLimit)}',
              onChanged: (value) => setState(
                () => _quantity = Money.parseInput(value),
              ),
            ),
            const SizedBox(height: 16),
            MoneyField(
              label: 'Descuento por unidad',
              enabled: canEditPrices,
              controller: _discountController,
              helperText: canEditPrices
                  ? 'Precio de lista ${Money.format(widget.line.listPrice)}'
                  : 'Necesitas el permiso para editar precios.',
              onChanged: (value) => setState(() => _discount = value),
            ),
            const SizedBox(height: 12),
            Text(
              'Total de la línea',
              style: EzyTextStyles.microLabel.copyWith(
                color: surfaces.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              Money.format(
                Money.round2((widget.line.listPrice - _discount) * _quantity),
              ),
              textAlign: TextAlign.right,
              style: EzyTextStyles.moneyMedium.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
            if (widget.line.isManualPrice)
              TextButton(
                onPressed: () {
                  controller.clearManualPrice(widget.line);
                  Navigator.of(context).pop();
                },
                child: const Text('Volver al precio del catálogo'),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            controller.setQuantity(widget.line, _quantity);
            if (canEditPrices) {
              controller.setDiscountPerUnit(widget.line, _discount);
            }
            Navigator.of(context).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
