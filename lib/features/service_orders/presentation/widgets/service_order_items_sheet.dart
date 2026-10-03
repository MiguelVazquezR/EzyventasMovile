import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../data/models/service_order_item_draft.dart';
import 'service_order_catalog_picker.dart';
import 'service_order_form_controls.dart';
import 'service_order_labels.dart';

/// Editor de conceptos de la orden (mano de obra y refacciones).
///
/// Devuelve la lista definitiva de conceptos o `null` si el usuario cancela.
/// Los precios y el stock los calcula el servidor; aquí solo se captura
/// descripción, cantidad y precio unitario.
///
/// La hoja sigue el prototipo validado "Tesla UI / EzyColors": alto del 90 %,
/// los dos botones de alta arriba —catálogo y concepto libre—, cada concepto en
/// un renglón editable y el CTA `Listo` **anclado al pie**, fuera del scroll,
/// para que no dependa de haber bajado hasta el final.
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

  void _remove(int index) => setState(() => _items.removeAt(index));

  void _done() => Navigator.of(context).pop(_items);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      builder: (context, scrollController) => Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: <Widget>[
                const SizedBox(height: 8),
                EzySheetHeader(
                  title: 'Conceptos de la orden',
                  subtitle:
                      'Las refacciones descuentan stock al guardar la orden.',
                  trailing: EzyIconButton(
                    icon: Icons.close,
                    tooltip: 'Cerrar',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                // El alta va arriba: con la lista larga no hay que bajar hasta
                // el final para agregar el siguiente concepto.
                SoCard(
                  title: 'Agregar',
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: SoOutlineButton(
                          label: 'Del catálogo',
                          icon: Icons.inventory_2_outlined,
                          onPressed: _addFromCatalog,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SoOutlineButton(
                          label: 'Concepto libre',
                          icon: Icons.add,
                          onPressed: _addCustom,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SoCard(
                  title: ServiceOrderLabels.items(_items.length),
                  child: _items.isEmpty
                      ? const SoNote(
                          text:
                              'Aún no hay conceptos. Agrega mano de obra o '
                              'refacciones.',
                          icon: Icons.add_circle_outline,
                          color: SoColors.info,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            for (
                              var index = 0;
                              index < _items.length;
                              index++
                            ) ...<Widget>[
                              if (index > 0) const SizedBox(height: 8),
                              _ItemRow(
                                item: _items[index],
                                onEdit: () => _edit(index),
                                onRemove: () => _remove(index),
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                SoCard(
                  title: 'Subtotal de conceptos',
                  child: SoInfoRow(
                    label: 'Subtotal',
                    value: Money.format(_subtotal),
                    emphasized: true,
                  ),
                ),
              ],
            ),
          ),
          _SheetFooter(subtotal: _subtotal, onDone: _done),
        ],
      ),
    );
  }
}

/// Renglón editable de un concepto: descripción, tipo con cantidad × precio y
/// total de la línea.
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: SoColors.inner(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoColors.structuralBorder(context)),
      ),
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: SoColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    <String>[
                      item.typeLabel,
                      '${Money.formatQuantity(item.quantity)} × '
                          '${Money.format(item.unitPrice)}',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.caption.copyWith(
                      color: SoColors.textMuted(context),
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
              color: SoColors.textPrimary(context),
            ),
          ),
          EzyIconButton(
            icon: Icons.close,
            size: 36,
            iconSize: 18,
            tooltip: 'Quitar concepto',
            onTap: onRemove,
          ),
        ],
      ),
    );
  }
}

/// CTA del editor anclado al pie, **fuera** del scroll: resume el total de los
/// conceptos y cierra la hoja devolviendo la lista.
class _SheetFooter extends StatelessWidget {
  const _SheetFooter({required this.subtotal, required this.onDone});

  final double subtotal;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SoColors.card(context),
        border: Border(
          top: BorderSide(color: SoColors.structuralBorder(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SoMicroLabel('Total de conceptos'),
                    const SizedBox(height: 2),
                    Text(
                      Money.format(subtotal),
                      style: EzyTextStyles.moneyList.copyWith(
                        color: SoColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: EzyButton(
                  label: 'Listo',
                  icon: Icons.check,
                  onPressed: onDone,
                ),
              ),
            ],
          ),
        ),
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
    final border = SoColors.structuralBorder(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.68,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          EzySheetHeader(
            title: _isCustom ? 'Concepto libre' : 'Editar concepto',
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          SoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
                  SoInfoRow(
                    label: 'Concepto',
                    value: widget.item!.description,
                    emphasized: true,
                  ),
                const SizedBox(height: 16),
                EzyTextField(
                  label: 'Cantidad',
                  isRequired: true,
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                const SizedBox(height: 14),
                Divider(height: 1, color: border),
                const SizedBox(height: 12),
                SoInfoRow(
                  label: 'Total del concepto',
                  value: Money.format(_lineTotal),
                  emphasized: true,
                ),
                if (_quantity <= 0 || _unitPrice <= 0) ...<Widget>[
                  const SizedBox(height: 10),
                  const SoNote(
                    text:
                        'La cantidad y el precio unitario deben ser '
                        'mayores a 0.',
                  ),
                ],
              ],
            ),
          ),
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
