import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../data/models/service_order_item_draft.dart';
import 'service_order_catalog_picker.dart';
import 'service_order_labels.dart';

/// Editor de conceptos de la orden (mano de obra y refacciones).
///
/// Devuelve la lista definitiva de conceptos o `null` si el usuario cancela.
/// Los precios y el stock los calcula el servidor; aquí solo se captura
/// descripción, cantidad y precio unitario.
Future<List<ServiceOrderItemDraft>?> showServiceOrderItemsSheet(
  BuildContext context, {
  required List<ServiceOrderItemDraft> items,
}) {
  return showModalBottomSheet<List<ServiceOrderItemDraft>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ServiceOrderItemsSheet(items: items),
  );
}

class _ServiceOrderItemsSheet extends StatefulWidget {
  const _ServiceOrderItemsSheet({required this.items});

  final List<ServiceOrderItemDraft> items;

  @override
  State<_ServiceOrderItemsSheet> createState() =>
      _ServiceOrderItemsSheetState();
}

class _ServiceOrderItemsSheetState extends State<_ServiceOrderItemsSheet> {
  late final List<ServiceOrderItemDraft> _items =
      List<ServiceOrderItemDraft>.of(widget.items);

  double get _subtotal =>
      Money.round2(_items.fold<double>(0, (sum, item) => sum + item.lineTotal));

  Future<void> _addFromCatalog() async {
    final draft = await showServiceOrderCatalogPicker(context);

    if (draft == null || !mounted) {
      return;
    }

    setState(() => _items.add(draft));
  }

  Future<void> _addCustom() async {
    final draft = await showServiceOrderItemEditor(context);

    if (draft == null || !mounted) {
      return;
    }

    setState(() => _items.add(draft));
  }

  /// Edita cantidad, precio y descripción de un concepto.
  Future<void> _edit(int index) async {
    final updated = await showServiceOrderItemEditor(
      context,
      item: _items[index],
    );

    if (updated == null || !mounted) {
      return;
    }

    setState(() => _items[index] = updated);
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'Conceptos de la orden',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Las refacciones descuentan stock al guardar la orden.',
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: ServiceOrderLabels.items(_items.length),
            child: _items.isEmpty
                ? Text(
                    'Aún no hay conceptos. Agrega mano de obra o refacciones.',
                    style: EzyTextStyles.body.copyWith(
                      color: surfaces.textMuted,
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (var index = 0; index < _items.length; index++)
                        _ItemRow(
                          item: _items[index],
                          onEdit: () => _edit(index),
                          onRemove: () =>
                              setState(() => _items.removeAt(index)),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Agregar',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                EzyButton(
                  label: 'Del catálogo',
                  icon: Icons.inventory_2_outlined,
                  variant: EzyButtonVariant.outline,
                  onPressed: _addFromCatalog,
                ),
                const SizedBox(height: 8),
                EzyButton(
                  label: 'Concepto libre',
                  icon: Icons.add,
                  variant: EzyButtonVariant.outline,
                  onPressed: _addCustom,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Subtotal de conceptos',
            child: SectionRow(
              label: 'Subtotal',
              value: Money.format(_subtotal),
              emphasized: true,
            ),
          ),
          const SizedBox(height: 16),
          EzyButton(
            label: 'Listo',
            icon: Icons.check,
            onPressed: () => Navigator.of(context).pop(_items),
          ),
        ],
      ),
    );
  }
}

/// Fila de un concepto con su cantidad, precio y total.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  final ServiceOrderItemDraft item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: GestureDetector(
              onTap: onEdit,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    item.description,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      item.typeLabel,
                      '${Money.formatQuantity(item.quantity)} × '
                          '${Money.format(item.unitPrice)}',
                    ].join(' · '),
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Money.format(item.lineTotal),
            style: EzyTextStyles.moneyList.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Quitar concepto',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 18, color: surfaces.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Captura de un concepto: descripción, cantidad y precio unitario.
///
/// Con [item] edita el concepto existente; sin él captura uno libre.
Future<ServiceOrderItemDraft?> showServiceOrderItemEditor(
  BuildContext context, {
  ServiceOrderItemDraft? item,
}) {
  return showModalBottomSheet<ServiceOrderItemDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ItemEditorSheet(item: item),
  );
}

class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({this.item});

  final ServiceOrderItemDraft? item;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.item?.description ?? '');
  late final TextEditingController _quantityController = TextEditingController(
    text: Money.formatQuantity(widget.item?.quantity ?? 1),
  );
  late final TextEditingController _priceController = TextEditingController(
    text: MoneyField.format(widget.item?.unitPrice ?? 0),
  );

  double _quantity = 0;
  double _unitPrice = 0;

  @override
  void initState() {
    super.initState();
    _quantity = widget.item?.quantity ?? 1;
    _unitPrice = widget.item?.unitPrice ?? 0;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool get _isCustom => !(widget.item?.isFromCatalog ?? false);

  double get _lineTotal => Money.round2(_quantity * _unitPrice);

  bool get _canApply =>
      _quantity > 0 &&
      _unitPrice > 0 &&
      (!_isCustom || _descriptionController.text.trim().isNotEmpty);

  void _apply() {
    Navigator.of(context).pop(
      ServiceOrderItemDraft(
        description: _isCustom
            ? _descriptionController.text.trim()
            : widget.item!.description,
        quantity: _quantity,
        unitPrice: _unitPrice,
        itemableType: widget.item?.itemableType,
        itemableId: widget.item?.itemableId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.68,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            _isCustom ? 'Concepto libre' : 'Editar concepto',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isCustom)
            EzyTextField(
              label: 'Descripción',
              isRequired: true,
              controller: _descriptionController,
              hint: 'Ej. Cambio de pantalla',
              maxLength: 255,
              onChanged: (value) => setState(() {}),
            )
          else
            SectionRow(
              label: 'Concepto',
              value: widget.item!.description,
              emphasized: true,
            ),
          const SizedBox(height: 16),
          EzyTextField(
            label: 'Cantidad',
            isRequired: true,
            controller: _quantityController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (value) =>
                setState(() => _quantity = Money.parseInput(value)),
          ),
          const SizedBox(height: 16),
          MoneyField(
            label: 'Precio unitario',
            isRequired: true,
            controller: _priceController,
            onChanged: (value) => setState(() => _unitPrice = value),
          ),
          const SizedBox(height: 16),
          SectionRow(
            label: 'Total del concepto',
            value: Money.format(_lineTotal),
            emphasized: true,
          ),
          if (_quantity <= 0 || _unitPrice <= 0) ...<Widget>[
            const SizedBox(height: 8),
            const NoticeBanner(
              message: 'La cantidad y el precio unitario deben ser mayores a 0.',
              tone: EzySeverity.warn,
            ),
          ],
          const SizedBox(height: 16),
          EzyButton(
            label: 'Aplicar',
            icon: Icons.check,
            onPressed: _canApply ? _apply : null,
          ),
        ],
      ),
    );
  }
}
