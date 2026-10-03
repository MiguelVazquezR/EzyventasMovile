import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/evidence_image.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../data/models/service_order_detail.dart';
import '../../data/models/service_order_form.dart';
import '../../data/models/service_order_item_draft.dart';
import 'service_order_evidence_picker.dart';
import 'service_order_form_controls.dart';

/// Conceptos de la orden (card 3 del prototipo): resumen de renglones y acceso
/// al editor de conceptos.
///
/// Cada renglón se pinta dentro de un relleno interno para distinguirlo del
/// fondo de la card; el subtotal cierra la sección. Cuando no hay conceptos se
/// explica de dónde salen y se ofrece el botón que abre la hoja de conceptos.
class ServiceOrderItemsSection extends StatelessWidget {
  const ServiceOrderItemsSection({
    super.key,
    required this.items,
    required this.subtotal,
    required this.onEdit,
  });

  final List<ServiceOrderItemDraft> items;
  final double subtotal;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return SoCard(
      title: 'Conceptos',
      trailing: items.isEmpty
          ? null
          : SoTextAction(
              label: 'Editar',
              icon: Icons.tune,
              onPressed: onEdit,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (items.isEmpty) ...<Widget>[
            const SoNote(
              text:
                  'Agrega servicios del catálogo o refacciones. Los productos '
                  'descuentan stock al guardar la orden.',
              icon: Icons.inventory_2_outlined,
              color: SoColors.info,
            ),
            const SizedBox(height: 14),
            SoOutlineButton(
              label: 'Agregar conceptos',
              icon: Icons.add,
              onPressed: onEdit,
            ),
          ] else ...<Widget>[
            for (final item in items) ...<Widget>[
              _ItemLine(item: item),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 4),
            Divider(height: 1, color: SoColors.structuralBorder(context)),
            const SizedBox(height: 12),
            SoInfoRow(
              label: 'Subtotal',
              value: Money.format(subtotal),
              emphasized: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Renglón del resumen: concepto, tipo, cantidad × precio y total de la línea.
class _ItemLine extends StatelessWidget {
  const _ItemLine({required this.item});

  final ServiceOrderItemDraft item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: SoColors.inner(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SoColors.structuralBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
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
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    SoTag(
                      label: item.typeLabel,
                      color: item.isPart ? SoColors.info : SoColors.primary,
                    ),
                    const SizedBox(width: 8),
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
          const SizedBox(width: 10),
          Text(
            Money.format(item.lineTotal),
            style: EzyTextStyles.moneyList.copyWith(
              color: SoColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Descuento de la orden (card 4 del prototipo): tipo, valor y monto que el
/// servidor recibe en `discount_value`.
class ServiceOrderDiscountSection extends StatelessWidget {
  const ServiceOrderDiscountSection({
    super.key,
    required this.type,
    required this.controller,
    required this.discountAmount,
    required this.onTypeChanged,
    required this.onValueChanged,
    this.subtotal = 0,
  });

  final ServiceOrderDiscountType type;
  final TextEditingController controller;
  final double discountAmount;

  /// Subtotal vigente; sirve para avisar cuando el descuento ya no cabe.
  final double subtotal;

  final ValueChanged<ServiceOrderDiscountType> onTypeChanged;
  final ValueChanged<double> onValueChanged;

  /// El servidor nunca deja el total en negativo.
  bool get _capped =>
      subtotal > 0 && discountAmount > 0 && discountAmount >= subtotal;

  @override
  Widget build(BuildContext context) {
    return SoCard(
      title: 'Descuento',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ServiceOrderSegmentedControl<ServiceOrderDiscountType>(
            values: ServiceOrderDiscountType.values,
            selected: type,
            labelOf: (value) => value.label,
            onSelected: onTypeChanged,
          ),
          const SizedBox(height: 14),
          MoneyField(
            label: type == ServiceOrderDiscountType.fixed
                ? 'Descuento en pesos'
                : 'Descuento en porcentaje',
            controller: controller,
            onChanged: onValueChanged,
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: SoColors.structuralBorder(context)),
          const SizedBox(height: 12),
          SoInfoRow(
            label: 'Descuento aplicado',
            value: Money.format(discountAmount),
            emphasized: true,
            color: discountAmount > 0 ? SoColors.success : null,
          ),
          if (_capped) ...<Widget>[
            const SizedBox(height: 10),
            const SoNote(
              text:
                  'El descuento se limita al subtotal: el total no puede '
                  'quedar en negativo.',
              icon: Icons.warning_amber_outlined,
            ),
          ],
        ],
      ),
    );
  }
}

/// Técnico asignado y su comisión (card 5 del prototipo).
class ServiceOrderTechnicianSection extends StatelessWidget {
  const ServiceOrderTechnicianSection({
    super.key,
    required this.assign,
    required this.nameController,
    required this.commissionController,
    required this.commissionType,
    required this.onAssignChanged,
    required this.onCommissionTypeChanged,
    required this.onCommissionValueChanged,
  });

  final bool assign;
  final TextEditingController nameController;
  final TextEditingController commissionController;
  final TechnicianCommissionType commissionType;
  final ValueChanged<bool> onAssignChanged;
  final ValueChanged<TechnicianCommissionType> onCommissionTypeChanged;
  final ValueChanged<double> onCommissionValueChanged;

  @override
  Widget build(BuildContext context) {
    return SoCard(
      title: 'Técnico',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Asignar técnico',
                  style: EzyTextStyles.bodyStrong.copyWith(
                    color: SoColors.textPrimary(context),
                  ),
                ),
              ),
              SoSwitch(value: assign, onChanged: onAssignChanged),
            ],
          ),
          if (assign) ...<Widget>[
            const SizedBox(height: 14),
            EzyTextField(
              label: 'Nombre del técnico',
              isRequired: true,
              controller: nameController,
              maxLength: 255,
            ),
            const SizedBox(height: 14),
            ServiceOrderSegmentedControl<TechnicianCommissionType>(
              values: TechnicianCommissionType.values,
              selected: commissionType,
              labelOf: (value) => value.label,
              onSelected: onCommissionTypeChanged,
            ),
            const SizedBox(height: 14),
            MoneyField(
              label: commissionType == TechnicianCommissionType.percentage
                  ? 'Comisión en porcentaje'
                  : 'Comisión en pesos',
              isRequired: true,
              controller: commissionController,
              onChanged: onCommissionValueChanged,
            ),
            const SizedBox(height: 10),
            const SoNote(
              text:
                  'La comisión por porcentaje se calcula sobre la mano de obra '
                  'del total final.',
              icon: Icons.percent,
              color: SoColors.info,
            ),
          ],
        ],
      ),
    );
  }
}


/// Evidencias del formulario (card 6): fotos guardadas y capturas nuevas.
class ServiceOrderEvidenceSection extends StatelessWidget {
  const ServiceOrderEvidenceSection({
    super.key,
    required this.detail,
    required this.photos,
    required this.deletedMediaIds,
    required this.isPicking,
    required this.onCamera,
    required this.onGallery,
    required this.onRemovePhoto,
    required this.onToggleDelete,
  });

  /// Orden en edición (`null` en el alta).
  final ServiceOrderDetail? detail;
  final List<EvidenceImage> photos;
  final Set<int> deletedMediaIds;
  final bool isPicking;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemovePhoto;
  final ValueChanged<int> onToggleDelete;

  @override
  Widget build(BuildContext context) {
    return ServiceOrderEvidencePicker(
      existing: detail?.initialEvidence ?? const <ServiceOrderMedia>[],
      photos: photos,
      deletedMediaIds: deletedMediaIds,
      isPicking: isPicking,
      onCamera: onCamera,
      onGallery: onGallery,
      onRemovePhoto: onRemovePhoto,
      onToggleDelete: onToggleDelete,
    );
  }
}

/// Campos personalizados de la orden (card 7, `custom_field_definitions`).
///
/// Las definiciones solo las entrega el detalle de una orden existente, así que
/// se renderizan al editar; en el alta no hay definiciones que mostrar.
class ServiceOrderCustomFieldsSection extends StatelessWidget {
  const ServiceOrderCustomFieldsSection({
    super.key,
    required this.definitions,
    required this.values,
    required this.onChanged,
  });

  final List<ServiceOrderCustomFieldDefinition> definitions;
  final Map<String, dynamic> values;
  final void Function(String key, Object? value) onChanged;

  @override
  Widget build(BuildContext context) {
    return SoCard(
      title: 'Campos personalizados',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var index = 0; index < definitions.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: 16),
            _CustomField(
              definition: definitions[index],
              value: values[definitions[index].key],
              onChanged: (value) => onChanged(definitions[index].key, value),
            ),
          ],
        ],
      ),
    );
  }
}

/// Campo personalizado según su tipo (`text`, `number`, `switch`).
class _CustomField extends StatefulWidget {
  const _CustomField({
    required this.definition,
    required this.value,
    required this.onChanged,
  });

  final ServiceOrderCustomFieldDefinition definition;
  final Object? value;
  final ValueChanged<Object?> onChanged;

  @override
  State<_CustomField> createState() => _CustomFieldState();
}

class _CustomFieldState extends State<_CustomField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value?.toString() ?? '',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;

    if (definition.isSwitch) {
      return Row(
        children: <Widget>[
          Expanded(
            child: Text(
              definition.name,
              style: EzyTextStyles.bodyStrong.copyWith(
                color: SoColors.textPrimary(context),
              ),
            ),
          ),
          SoSwitch(
            value: _isTruthy(widget.value),
            onChanged: (value) => widget.onChanged(value),
          ),
        ],
      );
    }

    return EzyTextField(
      label: definition.name,
      isRequired: definition.isRequired,
      controller: _controller,
      keyboardType: definition.isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      maxLength: 255,
      onChanged: (raw) =>
          widget.onChanged(definition.isNumber ? Money.parseInput(raw) : raw),
    );
  }

  static bool _isTruthy(Object? value) {
    if (value is bool) {
      return value;
    }

    final text = value?.toString();

    return text == 'true' || text == '1';
  }
}

