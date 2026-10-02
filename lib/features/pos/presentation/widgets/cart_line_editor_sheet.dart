import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../../core/widgets/server_image.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../data/models/cart_line.dart';

/// Abre el editor de una línea del carrito (§1–§8 del rediseño de la hoja).
///
/// Es una hoja inferior del sistema ([EzyBottomSheet]) sobre el lienzo de la
/// pantalla, con esquinas de 24 px arriba, asa de arrastre propia (40 × 5 px),
/// cabecera fija, cuerpo con scroll —vista previa, cantidad, descuento con
/// accesos rápidos y desglose financiero— y pie fijo con las acciones 1:2.
///
/// El contrato no cambia: el carrito se toca al guardar (`setQuantity` +
/// `setDiscountPerUnit` del `CartController`), al devolver la línea al catálogo
/// (`clearManualPrice`) y «Cancelar» cierra sin aplicar nada.
Future<void> showCartLineEditorSheet(
  BuildContext context, {
  required CartLine line,
}) {
  return EzyBottomSheet.show<void>(
    context,
    maxHeightFactor: 0.92,
    // §2: el lienzo de la hoja es el `background` (#1A1A1A en oscuro /
    // #E9EBF0 en claro) y no el panel del tema; el asa la pinta la hoja.
    backgroundColor: context.surfaces.background,
    showDragHandle: false,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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
    text: Money.formatPlain(widget.line.discountPerUnit),
  );

  double _quantity = 1;
  double _discount = 0;

  /// Error del campo del descuento (no puede pasar del precio de lista).
  String? _discountError;

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

  /// Tope de cantidad: el stock de la sucursal, cuando el catálogo lo reporta.
  double? get _stockCap {
    final stock = widget.line.stockLimit;
    return stock > 0 ? stock : null;
  }

  /// Unidad que se pinta bajo la cifra y en la fórmula del total.
  String get _unitLabel {
    final measure = widget.line.measureUnit.trim();
    return measure.isEmpty ? 'UNIDADES' : measure.toUpperCase();
  }

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

  /// Cantidad acotada a [min, stock]: es la que se valida antes de guardar.
  double _clamped(double value) {
    final rounded = value < _minimum ? _minimum : Money.round2(value);
    final cap = _stockCap;

    if (cap != null && rounded > cap) {
      return cap < _minimum ? _minimum : Money.round2(cap);
    }

    return rounded < _minimum ? _minimum : rounded;
  }

  /// Mueve la cantidad desde el contador: campo, cifra y desglose a la vez.
  void _stepQuantity(double delta) {
    final next = _clamped(_quantity + delta);
    setState(() {
      _quantity = next;
      _quantityController.text = Money.formatQuantity(next);
    });
  }

  /// Descuento capturado: nunca negativo ni mayor que el precio de lista.
  void _setDiscount(double value) {
    setState(() {
      if (value > widget.line.listPrice) {
        _discount = widget.line.listPrice;
        _discountError = 'No puede superar el precio de lista.';
        return;
      }

      _discount = value < 0 ? 0 : value;
      _discountError = null;
    });
  }

  /// «Volver al precio del catálogo» (§7): devuelve la línea a su precio de
  /// catálogo —promoción o mayoreo— conservando la cantidad capturada y cierra la
  /// hoja, porque no queda nada más que guardar.
  void _restoreCatalogPrice() {
    final controller = ref.read(cartControllerProvider.notifier);
    controller.setQuantity(_currentLine(), _clamped(_quantity));
    controller.clearManualPrice(_currentLine());
    Navigator.of(context).pop();
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

  /// Guarda: la misma secuencia del controlador de siempre, ya validada.
  void _save() {
    final controller = ref.read(cartControllerProvider.notifier);
    final canEditPrices = ref.read(permissionsProvider).can('pos.edit_prices');

    controller.setQuantity(_currentLine(), _clamped(_quantity));

    // Solo si el campo se tocó: si no, la promoción o el mayoreo que ya traía la
    // línea se conservan tal cual.
    if (canEditPrices && _discount != _initialDiscount) {
      controller.setDiscountPerUnit(_currentLine(), _discount);
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final canEditPrices = ref.watch(permissionsProvider).can('pos.edit_prices');
    final line = widget.line;
    // Misma cuenta que el carrito: `(lista − descuento) × cantidad`.
    final unitPrice = Money.round2(line.listPrice - _discount);
    final unitFinal = unitPrice < 0 ? 0.0 : unitPrice;
    final lineTotal = Money.round2(unitFinal * _quantity);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _DragHandle(),
        _EditorHeader(line: line, onClose: () => Navigator.of(context).pop()),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: <Widget>[
              _ProductPreviewCard(line: line),
              const SizedBox(height: 12),
              _QuantityCard(
                quantity: _quantity,
                controller: _quantityController,
                minimum: _minimum,
                stockCap: _stockCap,
                stockLimit: line.stockLimit,
                unitLabel: _unitLabel,
                onChanged: (value) =>
                    setState(() => _quantity = Money.parseInput(value)),
                onDecrease: () => _stepQuantity(-_step),
                onIncrease: () => _stepQuantity(_step),
              ),
              const SizedBox(height: 12),
              _DiscountCard(
                line: line,
                enabled: canEditPrices,
                discount: _discount,
                controller: _discountController,
                errorText: _discountError,
                onChanged: _setDiscount,
              ),
              const SizedBox(height: 12),
              _BreakdownCard(
                quantity: _quantity,
                unitLabel: _unitLabel,
                listPrice: line.listPrice,
                discount: _discount,
                unitPrice: unitFinal,
                lineTotal: lineTotal,
              ),
              if (line.isManualPrice) ...<Widget>[
                const SizedBox(height: 12),
                _RestoreCatalogPriceButton(onTap: _restoreCatalogPrice),
              ],
            ],
          ),
        ),
        _EditorFooter(
          onCancel: () => Navigator.of(context).pop(),
          onSave: _save,
        ),
      ],
    );
  }
}

/// Asa de arrastre (§2): 40 × 5 px, esquinas completas y el gris fuerte del
/// sistema sobre el lienzo de la hoja.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Center(
        child: Container(
          width: 40,
          height: 5,
          decoration: BoxDecoration(
            color: context.surfaces.borderStrong,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// Cabecera fija (§2): título, chip «En Carrito», el producto que se edita y el
/// cierre. Va sobre `panel` con el filo inferior de 1 px.
class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.line, required this.onClose});

  final CartLine line;
  final VoidCallback onClose;

  /// «Editar línea: Filtro de aceite» — la hoja se identifica con la línea que
  /// edita; el nombre ya lleva la variante, así que un detalle con lo mismo solo
  /// gastaría alto.
  static const String _subtitle = 'Cantidad y descuento por unidad';

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: surfaces.panel,
        border: Border(bottom: BorderSide(color: surfaces.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Editar línea: ${line.description}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.bodyStrong.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: surfaces.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _StatusChip(
                      label: 'En Carrito',
                      color: EzyColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: surfaces.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CloseButton(onTap: onClose),
        ],
      ),
    );
  }
}

/// Chip de estado: fondo del color al 12 %, borde al 25 % y texto pleno.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: EzyTextStyles.badge.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Cerrar de la cabecera: 32 px de lado, círculo con el relleno interior.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Tooltip(
      message: 'Cerrar',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: surfaces.panelInner,
            shape: BoxShape.circle,
            border: Border.all(color: surfaces.border),
          ),
          child: Icon(
            Icons.close,
            size: 16,
            color: surfaces.textSecondary,
            semanticLabel: 'Cerrar',
          ),
        ),
      ),
    );
  }
}

/// Tarjeta base del cuerpo de la hoja (§3–§6): radio 16, `panel` y borde de 1 px.
class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
      ),
      child: child,
    );
  }
}

/// Rótulo de tarjeta: 11 px, MAYÚSCULAS y `w800`.
class _CardLabel extends StatelessWidget {
  const _CardLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: EzyTextStyles.microLabel.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: context.surfaces.textPrimary,
      ),
    );
  }
}

/// Vista previa del producto (§3): miniatura de 56 px, nombre, detalle y precios.
class _ProductPreviewCard extends StatelessWidget {
  const _ProductPreviewCard({required this.line});

  final CartLine line;

  /// Detalle corto bajo el nombre: la variante, la unidad de medida o el
  /// catálogo. La línea no trae categoría ni SKU, así que se usa lo que sí hay.
  String get _caption {
    final variant = line.variantLabel?.trim() ?? '';

    if (variant.isNotEmpty) {
      return variant;
    }

    final measure = line.measureUnit.trim();
    return measure.isEmpty ? 'Producto del catálogo' : 'Venta por $measure';
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final discounted = line.unitPrice != line.listPrice;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border, width: 1.5),
        boxShadow: EzyColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ProductThumb(url: line.imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  line.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: surfaces.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: surfaces.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Text(
                      Money.format(line.unitPrice),
                      style: EzyTextStyles.moneyList.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: EzyColors.primary,
                      ),
                    ),
                    if (discounted) ...<Widget>[
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura de la vista previa: 56 × 56 px con la foto o el icono del sistema.
class _ProductThumb extends StatelessWidget {
  const _ProductThumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final image = url?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
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

  Widget _placeholder(BuildContext context) => Center(
    child: Icon(
      Icons.image_outlined,
      size: 20,
      color: context.surfaces.textMuted,
    ),
  );
}

/// Tarjeta del stepper de cantidad (§4): rótulo, existencias, chip de stock y el
/// control − / cifra / + con blancos táctiles de 44 px.
class _QuantityCard extends StatelessWidget {
  const _QuantityCard({
    required this.quantity,
    required this.controller,
    required this.minimum,
    required this.stockCap,
    required this.stockLimit,
    required this.unitLabel,
    required this.onChanged,
    required this.onDecrease,
    required this.onIncrease,
  });

  final double quantity;
  final TextEditingController controller;
  final double minimum;
  final double? stockCap;
  final double stockLimit;
  final String unitLabel;
  final ValueChanged<String> onChanged;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  /// Existencias que reporta el catálogo; sin dato, la app no inventa un tope.
  String get _stockLegend {
    if (stockLimit <= 0) {
      return 'Existencias disponibles: sin dato del catálogo';
    }

    return 'Existencias disponibles: '
        '${Money.formatQuantity(stockLimit)} ${unitLabel.toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final cap = stockCap;
    final atMinimum = quantity <= minimum;
    final atTop = cap != null && quantity >= cap;
    final badgeColor = atTop
        ? StatusPalette.text(context, EzySeverity.danger)
        : StatusPalette.text(context, EzySeverity.success);

    return _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _CardLabel('CANTIDAD')),
              _StatusChip(
                label: atTop ? 'Stock al tope' : 'Stock OK',
                color: badgeColor,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _stockLegend,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.caption.copyWith(
              fontSize: 11,
              color: surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: surfaces.panelInner,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: surfaces.borderStrong),
            ),
            child: Row(
              children: <Widget>[
                _StepButton(
                  icon: Icons.remove,
                  tooltip: 'Quitar una unidad',
                  onTap: atMinimum ? null : onDecrease,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: EzyTextStyles.bodyStrong.copyWith(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: surfaces.textPrimary,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: onChanged,
                      ),
                      Text(
                        unitLabel,
                        style: EzyTextStyles.badge.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: surfaces.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StepButton(
                  icon: Icons.add,
                  tooltip: 'Agregar una unidad',
                  emphasized: true,
                  onTap: atTop ? null : onIncrease,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Extremo del stepper: 44 px de lado; el «+» lleva el tinte de marca y el
/// deshabilitado se queda en el tono mínimo.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: emphasized
                ? EzyColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? surfaces.textMuted
                : (emphasized ? EzyColors.primary : surfaces.textSecondary),
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta del descuento por unidad (§5): porcentaje, campo de 46 px y los
/// accesos rápidos en chips.
class _DiscountCard extends StatelessWidget {
  const _DiscountCard({
    required this.line,
    required this.enabled,
    required this.discount,
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  final CartLine line;
  final bool enabled;
  final double discount;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<double> onChanged;

  /// Presets en pesos: `$0` y los cortes de `$5`, `$10` y `$15`, acotados al
  /// precio de lista para no ofrecer un descuento que el catálogo rechaza.
  List<double> get _presets {
    const candidates = <double>[0, 5, 10, 15];
    final usable = candidates
        .where((value) => value <= line.listPrice)
        .toList(growable: false);

    return usable.isEmpty ? const <double>[0] : usable;
  }

  /// Porcentaje del precio de lista que representa el descuento capturado.
  double get _percent =>
      line.listPrice <= 0 ? 0 : (discount / line.listPrice) * 100;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final success = StatusPalette.text(context, EzySeverity.success);

    return _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _CardLabel('DESCUENTO POR UNIDAD')),
              if (discount > 0)
                Text(
                  '-${_percent.toStringAsFixed(1)}% descuento',
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _DiscountField(
            controller: controller,
            enabled: enabled,
            errorText: errorText,
            onChanged: (value) => onChanged(Money.parseInput(value)),
          ),
          const SizedBox(height: 6),
          Text(
            enabled
                ? 'Precio de lista ${Money.format(line.listPrice)} por unidad.'
                : 'Necesitas el permiso para editar precios.',
            style: EzyTextStyles.caption.copyWith(
              fontSize: 10.5,
              color: surfaces.textMuted,
            ),
          ),
          if (enabled) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'ACCESOS RÁPIDOS:',
              style: EzyTextStyles.microLabel.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: surfaces.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                for (final preset in _presets) ...<Widget>[
                  if (preset != _presets.first) const SizedBox(width: 8),
                  Expanded(
                    child: _PresetChip(
                      label: Money.format(preset),
                      selected: discount == preset,
                      onTap: () => onChanged(preset),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip de acceso rápido: 34 px de alto, resaltado en marca cuando está activo.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? EzyColors.primary.withValues(alpha: 0.12)
              : surfaces.panelInner,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? EzyColors.primary : surfaces.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: EzyTextStyles.moneyList.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
            color: selected ? EzyColors.primary : surfaces.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Campo del descuento: 46 px, `$` de marca a la izquierda y `MXN` al final.
class _DiscountField extends StatelessWidget {
  const _DiscountField({
    required this.controller,
    required this.enabled,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final error = errorText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: surfaces.panelInner,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error == null
                  ? surfaces.borderStrong
                  : StatusPalette.base(EzySeverity.danger),
            ),
          ),
          child: Row(
            children: <Widget>[
              const SizedBox(width: 12),
              Text(
                '\$',
                style: EzyTextStyles.moneyList.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: EzyColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textAlign: TextAlign.right,
                  style: EzyTextStyles.fieldValue.copyWith(
                    color: surfaces.textPrimary,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0.00',
                    hintStyle: EzyTextStyles.fieldValue.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'MXN',
                style: EzyTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: surfaces.textMuted,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
        if (error != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            error,
            style: EzyTextStyles.caption.copyWith(
              fontSize: 10.5,
              color: StatusPalette.text(context, EzySeverity.danger),
            ),
          ),
        ],
      ],
    );
  }
}

/// Desglose del cálculo (§6): de dónde sale el total de la línea, sin sorpresas.
/// Los dos primeros importes ya van multiplicados por la cantidad —igual que el
/// carrito— y el unitario se queda a la vista para leer el descuento por pieza.
class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.quantity,
    required this.unitLabel,
    required this.listPrice,
    required this.discount,
    required this.unitPrice,
    required this.lineTotal,
  });

  final double quantity;
  final String unitLabel;
  final double listPrice;
  final double discount;
  final double unitPrice;
  final double lineTotal;

  /// Unidad de la fórmula del total: en singular cuando la línea lleva una sola
  /// pieza («1 unidad»), y tal cual cuando es una medida («1 kg»).
  String get _quantityUnit {
    final unit = unitLabel.toLowerCase();
    final singular = quantity == 1 && unit.endsWith('s');

    return singular ? unit.substring(0, unit.length - 1) : unit;
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final success = StatusPalette.text(context, EzySeverity.success);
    // El desglose se lee como el carrito: los importes son de la línea entera.
    final listTotal = Money.round2(listPrice * quantity);
    final discountTotal = Money.round2(discount * quantity);

    return _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _CardLabel('DESGLOSE DE CÁLCULO'),
          const SizedBox(height: 6),
          _BreakdownRow(
            label: 'Precio de lista',
            value: Money.format(listTotal),
            labelColor: surfaces.textMuted,
            valueColor: surfaces.textPrimary,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Descuento aplicado',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.body.copyWith(
                      fontSize: 12.5,
                      color: surfaces.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const _StatusChip(label: 'Manual', color: EzyColors.success),
                const SizedBox(width: 8),
                Text(
                  '-${Money.format(discountTotal)}',
                  style: EzyTextStyles.moneyList.copyWith(
                    fontSize: 13,
                    color: success,
                  ),
                ),
              ],
            ),
          ),
          _BreakdownRow(
            label: 'Precio unitario final',
            value: Money.format(unitPrice),
            labelColor: surfaces.textSecondary,
            valueColor: EzyColors.primary,
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: surfaces.borderStrong),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Total de la línea',
                      style: EzyTextStyles.bodyStrong.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: surfaces.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '(${Money.formatQuantity(quantity)} '
                      '$_quantityUnit × ${Money.format(unitPrice)})',
                      style: EzyTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: surfaces.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                Money.format(lineTotal),
                style: EzyTextStyles.moneyMedium.copyWith(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: EzyColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila de solo lectura del desglose: etiqueta a la izquierda, monto a la derecha.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: EzyTextStyles.body.copyWith(
                fontSize: 12.5,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: EzyTextStyles.moneyList.copyWith(
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reversión al catálogo (§7): solo aparece cuando la línea trae un precio
/// capturado a mano —una promoción del catálogo no se «revierte»—.
class _RestoreCatalogPriceButton extends StatelessWidget {
  const _RestoreCatalogPriceButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: EzyColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EzyColors.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.restore, size: 14, color: EzyColors.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Volver al precio del catálogo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EzyTextStyles.bodyStrong.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: EzyColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pie fijo (§8): «Cancelar» a un tercio y **Guardar cambios** a dos tercios,
/// con el CTA 3D de marca anclado abajo y la sombra que lo despega del scroll.
class _EditorFooter extends StatelessWidget {
  const _EditorFooter({required this.onCancel, required this.onSave});

  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: surfaces.panel,
        border: Border(top: BorderSide(color: surfaces.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: EzyColors.black2.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: <Widget>[
            Expanded(child: _CancelButton(onTap: onCancel)),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: EzyPrimary3dButton(
                label: 'Guardar cambios',
                icon: Icons.check,
                onPressed: onSave,
                height: 52,
                maxWidth: double.infinity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Acción secundaria del pie: 52 px, contorno del sistema, sin relleno de marca.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surfaces.panelInner,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaces.borderStrong),
        ),
        child: Text(
          'Cancelar',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: EzyTextStyles.button.copyWith(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: surfaces.textSecondary,
          ),
        ),
      ),
    );
  }
}
// __SHEET_CHUNK_END__
