import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_amount.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_quantity_stepper.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../data/models/cart_line.dart';

/// Tarjeta de una línea del carrito (§2).
///
/// Tres renglones: el nombre con sus acciones a la derecha, el precio unitario
/// —con el de lista tachado y la pastilla del descuento cuando lo hay— y, al
/// pie, el contador del sistema junto al total de la línea.
///
/// Las acciones son los botones de icono del design system ([EzyIconButton] con
/// su `Tooltip`) y **no** el botón de texto «Editar cantidad y descuento» ni la
/// «x» de antes: el lápiz abre el editor de la línea y la papelera la quita del
/// carrito.
class CartLineTile extends ConsumerWidget {
  const CartLineTile({super.key, required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final controller = ref.read(cartControllerProvider.notifier);
    final variant = line.variantLabel;
    final reason = line.discountReason;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(16),
        // Mismo borde de 1 px que los pagos del cobro: las líneas del carrito no
        // llevan franjas ni sombras propias.
        border: Border.all(color: surfaces.border),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        color: surfaces.textPrimary,
                      ),
                    ),
                    if (variant != null && variant.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        variant,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.secondary.copyWith(
                          color: surfaces.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              EzyIconButton(
                icon: Icons.edit_outlined,
                tooltip: 'Editar cantidad y descuento',
                iconSize: 18,
                onTap: () => showCartLineEditorSheet(context, line: line),
              ),
              const SizedBox(width: 6),
              EzyIconButton(
                icon: Icons.delete_outline,
                tooltip: 'Quitar del carrito',
                iconSize: 18,
                color: StatusPalette.text(context, EzySeverity.danger),
                borderColor: StatusPalette.border(EzySeverity.danger),
                onTap: () => controller.removeLine(line),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Precio unitario: con descuento se tacha el de lista al lado y la
          // diferencia va en la pastilla del sistema, así el ahorro se lee de un
          // golpe sin sumar renglones de texto.
          Row(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        '${Money.format(line.unitPrice)} c/u',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.caption.copyWith(
                          color: surfaces.textMuted,
                        ),
                      ),
                    ),
                    if (line.hasDiscount) ...<Widget>[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          Money.format(line.listPrice),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EzyTextStyles.caption.copyWith(
                            color: surfaces.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (line.hasDiscount) ...<Widget>[
                const SizedBox(width: 8),
                EzyChip(
                  label: '-${Money.format(line.discountPerUnit)} c/u',
                  compact: true,
                  tone: EzySeverity.success,
                ),
              ],
            ],
          ),
          // El motivo lo pone el modelo (`Promoción de producto`, `Precio de
          // mayoreo`, `Descuento manual`): la tarjeta no inventa texto.
          if (line.hasDiscount && reason != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              reason,
              style: EzyTextStyles.caption.copyWith(
                color: StatusPalette.text(context, EzySeverity.success),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _QuantityStepper(line: line),
              const Spacer(),
              EzyAmount(value: line.lineTotal, size: EzyAmountSize.list),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cantidad con botones − / + (paso 1, o 0.5 en productos a granel).
///
/// El control en sí es el del design system; aquí solo se conecta con el
/// carrito (`incrementLine` / `decrementLine`).
class _QuantityStepper extends ConsumerWidget {
  const _QuantityStepper({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartControllerProvider.notifier);

    return EzyQuantityStepper(
      quantity: line.quantity,
      onDecrease: () => controller.decrementLine(line),
      onIncrease: () => controller.incrementLine(line),
    );
  }
}
/// Abre el editor de una línea del carrito (§3).
///
/// Es una hoja inferior del sistema ([EzyBottomSheet]) y no el diálogo de antes:
/// así el contador, el campo del descuento y el desglose caben sin apretarse y
/// el pie con «Cancelar» / «Guardar cambios» queda siempre a la vista. Se abre
/// con el lápiz de la tarjeta de la línea.
Future<void> showCartLineEditorSheet(
  BuildContext context, {
  required CartLine line,
}) {
  return EzyBottomSheet.show<void>(
    context,
    maxHeightFactor: 0.92,
    builder: (sheetContext) => _CartLineEditorSheet(line: line),
  );
}

/// Editor de la línea: cantidad y descuento por unidad (con `pos.edit_prices`).
class _CartLineEditorSheet extends ConsumerStatefulWidget {
  const _CartLineEditorSheet({required this.line});

  final CartLine line;

  @override
  ConsumerState<_CartLineEditorSheet> createState() =>
      _CartLineEditorSheetState();
}

class _CartLineEditorSheetState extends ConsumerState<_CartLineEditorSheet> {
  late final TextEditingController _quantityController = TextEditingController(
    text: Money.formatQuantity(widget.line.quantity),
  );
  late final TextEditingController _discountController = TextEditingController(
    text: MoneyField.format(widget.line.discountPerUnit),
  );

  double _quantity = 1;
  double _discount = 0;

  /// Descuento con el que se abrió la hoja.
  ///
  /// Al guardar se compara contra él: si el cajero no toca el campo, el precio de
  /// la línea se queda como está —una promoción o un precio de mayoreo **no** se
  /// vuelven un descuento manual solo por abrir el editor—.
  late final double _initialDiscount = widget.line.discountPerUnit;

  /// Paso del contador: 1 pieza, o 0.5 en los productos a granel.
  double get _step => widget.line.isBulk ? 0.5 : 1;

  /// Mínimo de la línea: media pieza —o un gramo— no se cobra.
  double get _minimum => widget.line.isBulk ? 0.01 : 1;

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

  /// Mueve la cantidad desde el contador: campo, cifra y desglose a la vez.
  void _stepQuantity(double delta) {
    final next = Money.round2(_quantity + delta);
    setState(() {
      _quantity = next < _minimum ? _minimum : next;
      _quantityController.text = Money.formatQuantity(_quantity);
    });
  }

  /// Línea vigente del carrito.
  ///
  /// Nunca se escribe sobre la copia con la que se abrió la hoja: al guardar
  /// pueden cambiar cantidad y descuento, y la segunda escritura tiene que partir
  /// de lo que dejó la primera (el carrito la busca por producto y variante).
  CartLine _currentLine() {
    for (final candidate in ref.read(cartControllerProvider).lines) {
      if (candidate.productId == widget.line.productId &&
          candidate.variantId == widget.line.variantId) {
        return candidate;
      }
    }

    return widget.line;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(cartControllerProvider.notifier);
    final canEditPrices = ref.watch(permissionsProvider).can('pos.edit_prices');
    final line = widget.line;
    // Misma cuenta que el carrito: `(lista − descuento) × cantidad`.
    final lineTotal = Money.round2((line.listPrice - _discount) * _quantity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EzySheetHeader(
          // §3: la hoja se identifica con la línea que edita; el nombre ya lleva
          // la variante, así que un subtítulo con lo mismo solo gastaría alto.
          title: 'Editar línea: ${line.description}',
          trailing: EzyIconButton(
            icon: Icons.close,
            tooltip: 'Cerrar',
            onTap: () => Navigator.of(context).pop(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: EzyTextField(
                      label: 'Cantidad',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.right,
                      controller: _quantityController,
                      helperText: line.isBulk
                          ? 'Producto a granel: admite decimales.'
                          : 'Stock disponible: '
                                '${Money.formatQuantity(line.stockLimit)}',
                      onChanged: (value) =>
                          setState(() => _quantity = Money.parseInput(value)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // El mismo contador de la tarjeta y del detalle del producto.
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: EzyQuantityStepper(
                      quantity: _quantity,
                      onDecrease: () => _stepQuantity(-_step),
                      onIncrease: () => _stepQuantity(_step),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MoneyField(
                label: 'Descuento por unidad',
                enabled: canEditPrices,
                controller: _discountController,
                helperText: canEditPrices
                    ? 'Precio de lista ${Money.format(line.listPrice)}'
                    : 'Necesitas el permiso para editar precios.',
                onChanged: (value) => setState(() => _discount = value),
              ),
              const SizedBox(height: 16),
              // Desglose de solo lectura: de dónde sale el total de la línea.
              SectionCard(
                inner: true,
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                child: Column(
                  children: <Widget>[
                    SectionRow(
                      label: 'Precio de lista',
                      value: Money.format(
                        Money.round2(line.listPrice * _quantity),
                      ),
                    ),
                    SectionRow(
                      label: 'Descuento aplicado',
                      value: '-${Money.format(
                        Money.round2(_discount * _quantity),
                      )}',
                      valueStyle: EzyTextStyles.moneyList.copyWith(
                        color: StatusPalette.text(context, EzySeverity.success),
                      ),
                    ),
                    const Divider(height: 20),
                    SectionRow(
                      label: 'Total de la línea',
                      value: Money.format(lineTotal),
                      emphasized: true,
                      valueStyle: EzyTextStyles.moneyMedium.copyWith(
                        color: EzyColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (line.isManualPrice) ...<Widget>[
                const SizedBox(height: 8),
                EzyButton(
                  label: 'Volver al precio del catálogo',
                  variant: EzyButtonVariant.text,
                  onPressed: () {
                    controller.clearManualPrice(line);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ],
          ),
        ),
        EzyActionBar(
          child: EzySheetActions(
            children: <Widget>[
              EzyButton(
                label: 'Cancelar',
                variant: EzyButtonVariant.outline,
                onPressed: () => Navigator.of(context).pop(),
              ),
              EzyButton(
                label: 'Guardar cambios',
                onPressed: () {
                  // El carrito ya acota mínimo y stock: aquí solo se evita
                  // mandar una cantidad vacía o en cero.
                  final quantity = _quantity < _minimum ? _minimum : _quantity;
                  controller.setQuantity(_currentLine(), quantity);

                  // Solo si el campo se tocó: si no, la promoción o el mayoreo
                  // que ya traía la línea se conservan tal cual.
                  if (canEditPrices && _discount != _initialDiscount) {
                    controller.setDiscountPerUnit(_currentLine(), _discount);
                  }

                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

