import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_quantity_stepper.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/server_image.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../data/models/cart_line.dart';

/// Tarjeta de una línea del carrito (§2 y §4 del rediseño).
///
/// Renglones: miniatura de 76 px con el detalle del producto y sus acciones
/// rápidas, el precio unitario —con el de lista tachado—, la pastilla del
/// descuento y, al pie, el contador de cantidad junto al total de la línea.
///
/// El lápiz abre el editor de la línea y la papelera la quita del carrito: los
/// dos siguen llamando al mismo `CartController` de siempre.
class CartLineTile extends ConsumerWidget {
  const CartLineTile({super.key, required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final controller = ref.read(cartControllerProvider.notifier);
    final variant = line.variantLabel;
    final reason = line.discountReason;
    final dangerText = StatusPalette.text(context, EzySeverity.danger);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border, width: 1.5),
        boxShadow: EzyColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Thumbnail(url: line.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: EzyTextStyles.bodyStrong.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: surfaces.textPrimary,
                                ),
                              ),
                              if (variant != null && variant.isNotEmpty)
                                ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(
                                    variant,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: EzyTextStyles.caption.copyWith(
                                      fontSize: 11.5,
                                      color: surfaces.textSecondary,
                                    ),
                                  ),
                                ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _QuickAction(
                          icon: Icons.edit_outlined,
                          tooltip: 'Editar cantidad y descuento',
                          onTap: () =>
                              showCartLineEditorSheet(context, line: line),
                        ),
                        const SizedBox(width: 6),
                        _QuickAction(
                          icon: Icons.delete_outline,
                          tooltip: 'Quitar del carrito',
                          color: dangerText,
                          background: StatusPalette.soft(EzySeverity.danger),
                          border: StatusPalette.border(EzySeverity.danger),
                          onTap: () => controller.removeLine(line),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Text(
                          '${Money.format(line.unitPrice)} c/u',
                          style: EzyTextStyles.moneyList.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: EzyColors.primary,
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
                                fontSize: 11,
                                color: surfaces.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (line.hasDiscount) ...<Widget>[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _DiscountPill(
                          label:
                              '- ${Money.format(line.discountPerUnit)} c/u'
                              '${reason == null || reason.isEmpty ? '' : ' • $reason'}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: surfaces.border),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _LineStepper(line: line),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'TOTAL LÍNEA',
                    style: EzyTextStyles.microLabel.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Money.format(line.lineTotal),
                    style: EzyTextStyles.moneyList.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: EzyColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pastilla del descuento de la línea: ahorro por unidad y su motivo.
class _DiscountPill extends StatelessWidget {
  const _DiscountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final success = StatusPalette.text(context, EzySeverity.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.success),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(EzySeverity.success)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.local_offer_outlined, size: 12, color: success),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.caption.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acción rápida de la tarjeta: 28 px de lado, con su `Tooltip`.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.background,
    this.border,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final Color? background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: background ?? surfaces.panelInner,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border ?? surfaces.border),
          ),
          child: Icon(
            icon,
            size: 15,
            color: color ?? surfaces.textSecondary,
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

/// Contador de la línea: radio 12, botones táctiles y el «+» con el tinte de
/// marca. Llama a los mismos `incrementLine` / `decrementLine` del carrito.
class _LineStepper extends ConsumerWidget {
  const _LineStepper({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final controller = ref.read(cartControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepperButton(
            icon: Icons.remove,
            tooltip: 'Quitar una unidad',
            onTap: () => controller.decrementLine(line),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 34),
            child: Text(
              Money.formatQuantity(line.quantity),
              textAlign: TextAlign.center,
              style: EzyTextStyles.bodyStrong.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: surfaces.textPrimary,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            tooltip: 'Agregar una unidad',
            emphasized: true,
            onTap: () => controller.incrementLine(line),
          ),
        ],
      ),
    );
  }
}

/// Extremo del contador: 30 px de lado; el «+» lleva el tinte de marca.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: emphasized
                ? EzyColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color: emphasized ? EzyColors.primary : surfaces.textSecondary,
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

/// Miniatura de una línea del carrito (§4): 76 × 76 con la foto del producto o
/// de su variante y el icono del sistema cuando no hay imagen.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});

  final String? url;

  static const double _side = 76;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final image = url?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: _side,
        height: _side,
        decoration: BoxDecoration(
          color: surfaces.panelInner,
          borderRadius: BorderRadius.circular(12),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surfaces.border),
        ),
        child: image.isEmpty
            ? _placeholder(context)
            : ServerImage(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(context),
              ),
      ),
    );
  }

  /// Placeholder cuando el producto no tiene foto en el catálogo.
  Widget _placeholder(BuildContext context) => Center(
    child: Icon(Icons.image_outlined, size: 20, color: context.surfaces.textMuted),
  );
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
                      value:
                          '-${Money.format(Money.round2(_discount * _quantity))}',
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
        // §8: el pie del editor reparte la acciones 1:2 —«Cancelar» a un tercio
        // del ancho y el CTA 3D «Guardar cambios» a dos tercios—, así el guardado
        // queda bajo el pulgar y el descarte no se toca de más.
        EzyActionBar(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _CancelButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: EzyPrimary3dButton(
                  label: 'Guardar cambios',
                  icon: Icons.check,
                  height: 50,
                  labelFontSize: 13.5,
                  maxWidth: double.infinity,
                  onPressed: () {
                    // El carrito ya acota mínimo y stock: aquí solo se evita
                    // mandar una cantidad vacía o en cero.
                    final quantity = _quantity < _minimum
                        ? _minimum
                        : _quantity;
                    controller.setQuantity(_currentLine(), quantity);

                    // Solo si el campo se tocó: si no, la promoción o el mayoreo
                    // que ya traía la línea se conservan tal cual.
                    if (canEditPrices && _discount != _initialDiscount) {
                      controller.setDiscountPerUnit(_currentLine(), _discount);
                    }

                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// «Cancelar» del pie del editor (§8): un tercio del ancho, 50 px de alto y el
/// gris interior del sistema —no compite con el CTA de marca—.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surfaces.panelInner,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaces.borderStrong),
        ),
        child: Text(
          'Cancelar',
          style: EzyTextStyles.bodyStrong.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: surfaces.textSecondary,
          ),
        ),
      ),
    );
  }
}
