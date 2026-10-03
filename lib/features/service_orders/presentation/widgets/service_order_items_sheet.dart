import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../data/models/service_order_item_draft.dart';
import 'service_order_catalog_picker.dart';
import 'service_order_form_controls.dart';

/// Editor de conceptos de la orden (mano de obra y refacciones).
///
/// Devuelve la lista definitiva de conceptos o `null` si el usuario cancela.
/// Flujo de cuatro hojas inferiores encadenadas: hub `Conceptos de la orden`,
/// catálogo (`service_order_catalog_picker.dart`), editor de concepto y selector
/// de variante (`service_order_variant_picker.dart`).
///
/// Sigue el sistema "Tesla UI / SoColors": lienzo canvas, cards `SoCard` de 24
/// px, relleno interno #2A2A2A/#F6F7F9 y el CTA `Listo` **anclado al pie**.
Future<List<ServiceOrderItemDraft>?> showServiceOrderItemsSheet(
  BuildContext context, {
  required List<ServiceOrderItemDraft> items,
}) {
  return showModalBottomSheet<List<ServiceOrderItemDraft>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: SoColors.canvas(context),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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

  Timer? _toastTimer;
  String? _toastMessage;

  double get _subtotal =>
      Money.round2(_items.fold<double>(0, (sum, item) => sum + item.lineTotal));

  Future<void> _addFromCatalog() async {
    final draft = await showServiceOrderCatalogPicker(context);

    if (draft == null || !mounted) {
      return;
    }

    setState(() => _items.add(draft));
    _toast('Concepto agregado');
  }

  Future<void> _addCustom() async {
    final draft = await showServiceOrderItemEditor(context);

    if (draft == null || !mounted) {
      return;
    }

    setState(() => _items.add(draft));
    _toast('Concepto agregado');
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

  /// Confirmación breve dentro de la hoja: en un modal el `SnackBar` del
  /// `Scaffold` queda detrás del propio sheet, así que se pinta aquí arriba.
  void _toast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _toastMessage = null);
      }
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsHeader = _items.isEmpty
        ? '0 CONCEPTOS'
        : '${_items.length} '
              '${_items.length == 1 ? 'CONCEPTO AGREGADO' : 'CONCEPTOS AGREGADOS'}';

    return Stack(
      children: <Widget>[
        DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.96,
          builder: (context, scrollController) => Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: <Widget>[
                    const SizedBox(height: 8),
                    SoSheetHeader(
                      title: 'Conceptos de la orden',
                      subtitle: 'Las refacciones descuentan stock al guardar la orden.',
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 16),
                    // El alta va arriba: con la lista larga no hay que bajar
                    // hasta el final para agregar el siguiente concepto.
                    SoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Icon(
                                Icons.playlist_add,
                                size: 14,
                                color: SoColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'AGREGAR CONCEPTO',
                                style: EzyTextStyles.microLabel.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: SoColors.textMuted(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  itemsHeader,
                                  style: EzyTextStyles.microLabel.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: SoColors.textMuted(context),
                                  ),
                                ),
                              ),
                              if (_items.isNotEmpty)
                                Text(
                                  'Toca para editar',
                                  style: EzyTextStyles.caption.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: SoColors.textMuted(context),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_items.isEmpty)
                            const NoticeBanner(
                              message:
                                  'Aún no hay conceptos. Agrega mano de obra '
                                  'o refacciones.',
                              tone: EzySeverity.info,
                            )
                          else
                            Column(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SoCard(
                      title: 'Subtotal de conceptos',
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Subtotal',
                                  style: EzyTextStyles.caption.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: SoColors.textSecondary(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Suma de mano de obra y refacciones',
                                  style: EzyTextStyles.caption.copyWith(
                                    fontSize: 11,
                                    color: SoColors.textMuted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Money.format(_subtotal),
                            style: EzyTextStyles.moneyList.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: SoColors.textPrimary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _SheetFooter(subtotal: _subtotal, onDone: _done),
            ],
          ),
        ),
        if (_toastMessage != null)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(child: _ToastPill(message: _toastMessage!)),
            ),
          ),
      ],
    );
  }
}

/// Renglón editable de un concepto: descripción, tipo con cantidad × precio y
/// total de la línea. Tocar el renglón (salvo la X) abre el editor.
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
    final typeColor = item.isPart
        ? SoColors.tone(context, SoColors.info)
        : (SoColors.isDark(context)
              ? const Color(0xFFF9B96F)
              : const Color(0xFFB45309));

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
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SoColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: <Widget>[
                      Text(
                        item.typeLabel,
                        style: EzyTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: typeColor,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: EzyTextStyles.caption.copyWith(
                          color: SoColors.textMuted(context),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          '${Money.formatQuantity(item.quantity)} × '
                          '${Money.format(item.unitPrice)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EzyTextStyles.caption.copyWith(
                            color: SoColors.textMuted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Money.format(item.lineTotal),
            style: EzyTextStyles.moneyList.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: SoColors.textPrimary(context),
            ),
          ),
          const SizedBox(width: 4),
          _RemoveButton(onTap: onRemove),
        ],
      ),
    );
  }
}

/// Botón de quitar: 28 × 28 px en caja redondeada con tinte rojo al pulsar. Lleva
/// tooltip porque el icono solo no explica la acción destructiva.
class _RemoveButton extends StatefulWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Quitar concepto',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: SoColors.danger.withValues(alpha: _pressed ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: SoColors.danger.withValues(alpha: _pressed ? 0.45 : 0.3),
            ),
          ),
          child: Icon(
            Icons.close,
            size: 16,
            color: SoColors.tone(context, SoColors.danger),
          ),
        ),
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
        color: SoColors.canvas(context),
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
                    Text(
                      'TOTAL DE CONCEPTOS',
                      style: EzyTextStyles.microLabel.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: SoColors.textMuted(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Money.format(subtotal),
                      style: EzyTextStyles.moneyList.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: SoColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: SoPrimaryButton(
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

/// Confirmación breve que se pinta dentro de la hoja.
class _ToastPill extends StatelessWidget {
  const _ToastPill({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = SoColors.tone(context, SoColors.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: SoColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SoColors.success.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            message,
            style: EzyTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
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
    backgroundColor: SoColors.canvas(context),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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
    text: Money.formatPlain(widget.item?.unitPrice ?? 0),
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
    final invalid = _quantity <= 0 || _unitPrice <= 0;

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
            title: _isCustom ? 'Concepto libre' : 'Editar concepto',
            onClose: () => Navigator.of(context).pop(),
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
                    hint: 'Ej. Cambio de pantalla iPhone 13',
                    maxLength: 255,
                    fillColor: SoColors.inner(context),
                    borderRadius: 14,
                    textStyle: EzyTextStyles.fieldValue.copyWith(
                      color: SoColors.textPrimary(context),
                    ),
                    onChanged: (value) => setState(() {}),
                  )
                else
                  _CatalogConceptBlock(item: widget.item!),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: EzyTextField(
                        label: 'Cantidad',
                        isRequired: true,
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        fillColor: SoColors.inner(context),
                        borderRadius: 14,
                        textStyle: EzyTextStyles.moneyList.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: SoColors.textPrimary(context),
                        ),
                        onChanged: (value) =>
                            setState(() => _quantity = Money.parseInput(value)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EzyTextField(
                        label: 'Precio unitario',
                        isRequired: true,
                        controller: _priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        prefixIcon: Icons.attach_money,
                        prefixIconColor: SoColors.primary,
                        fillColor: SoColors.inner(context),
                        borderRadius: 14,
                        textStyle: EzyTextStyles.moneyList.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: SoColors.textPrimary(context),
                        ),
                        onChanged: (value) => setState(
                          () => _unitPrice = Money.parseInput(value),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: SoColors.structuralBorder(context)),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'TOTAL DEL CONCEPTO',
                        style: EzyTextStyles.microLabel.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: SoColors.textMuted(context),
                        ),
                      ),
                    ),
                    Text(
                      Money.format(_lineTotal),
                      style: EzyTextStyles.moneyList.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: SoColors.primary,
                      ),
                    ),
                  ],
                ),
                if (invalid) ...<Widget>[
                  const SizedBox(height: 14),
                  const NoticeBanner(
                    message:
                        'La cantidad y el precio unitario deben ser mayores '
                        'a 0.',
                    tone: EzySeverity.warn,
                  ),
                ],
                const SizedBox(height: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoPrimaryButton(
            label: 'Aplicar',
            icon: Icons.check,
            onPressed: _canApply ? _apply : null,
          ),
        ],
      ),
    );
  }
}

/// Bloque de solo lectura del concepto tomado del catálogo: el nombre oficial no
/// se edita (el servidor lo recalcula), solo cantidad y precio.
class _CatalogConceptBlock extends StatelessWidget {
  const _CatalogConceptBlock({required this.item});

  final ServiceOrderItemDraft item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SoColors.inner(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoColors.structuralBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'CONCEPTO',
                  style: EzyTextStyles.microLabel.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: SoColors.textMuted(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.description,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: SoColors.textPrimary(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SoTag(
            label: item.typeLabel,
            color: item.isPart ? SoColors.info : SoColors.primary,
          ),
        ],
      ),
    );
  }
}
