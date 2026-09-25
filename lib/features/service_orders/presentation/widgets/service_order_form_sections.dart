import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/evidence_image.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/section_card.dart';
import '../../data/models/service_order_detail.dart';
import '../../data/models/service_order_form.dart';
import '../../data/models/service_order_item_draft.dart';
import 'evidence_photo_strip.dart';
import 'evidence_picker_row.dart';
import 'service_order_form_controls.dart';

/// Conceptos de la orden: resumen y acceso al editor de conceptos.
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
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Refacciones y mano de obra',
      trailing: TextButton(
        onPressed: onEdit,
        child: const Text('Editar conceptos'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (items.isEmpty)
            Text(
              'Agrega servicios del catálogo o refacciones. Los productos '
              'descuentan stock al guardar.',
              style: EzyTextStyles.body.copyWith(color: surfaces.textMuted),
            )
          else ...<Widget>[
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${Money.formatQuantity(item.quantity)} × '
                        '${item.description}',
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.body.copyWith(
                          color: surfaces.textBody,
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
                  ],
                ),
              ),
          ],
          const SizedBox(height: 4),
          SectionRow(
            label: 'Subtotal',
            value: Money.format(subtotal),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

/// Descuento de la orden: tipo, valor y monto que el servidor recibe.
class ServiceOrderDiscountSection extends StatelessWidget {
  const ServiceOrderDiscountSection({
    super.key,
    required this.type,
    required this.controller,
    required this.discountAmount,
    required this.onTypeChanged,
    required this.onValueChanged,
  });

  final ServiceOrderDiscountType type;
  final TextEditingController controller;
  final double discountAmount;
  final ValueChanged<ServiceOrderDiscountType> onTypeChanged;
  final ValueChanged<double> onValueChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
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
          const SizedBox(height: 16),
          MoneyField(
            label: type == ServiceOrderDiscountType.fixed
                ? 'Descuento en pesos'
                : 'Descuento en porcentaje',
            controller: controller,
            onChanged: onValueChanged,
          ),
          const SizedBox(height: 8),
          SectionRow(
            label: 'Descuento aplicado',
            value: Money.format(discountAmount),
          ),
        ],
      ),
    );
  }
}

/// Técnico asignado y su comisión (porcentaje o monto fijo).
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
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Técnico',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // `Material` transparente: el `SectionCard` pinta su propio fondo, así
          // que sin él el *ripple* del interruptor quedaría debajo y Flutter
          // avisa en debug («ListTile background color or ink splashes …»).
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: assign,
              onChanged: onAssignChanged,
              title: Text(
                'Asignar técnico',
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ),
          ),
          if (assign) ...<Widget>[
            const SizedBox(height: 8),
            EzyTextField(
              label: 'Nombre del técnico',
              isRequired: true,
              controller: nameController,
              maxLength: 255,
            ),
            const SizedBox(height: 16),
            ServiceOrderSegmentedControl<TechnicianCommissionType>(
              values: TechnicianCommissionType.values,
              selected: commissionType,
              labelOf: (value) => value.label,
              onSelected: onCommissionTypeChanged,
            ),
            const SizedBox(height: 16),
            MoneyField(
              label: commissionType == TechnicianCommissionType.percentage
                  ? 'Comisión en porcentaje'
                  : 'Comisión en pesos',
              isRequired: true,
              controller: commissionController,
              onChanged: onCommissionValueChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// Evidencias del formulario: las guardadas (se pueden marcar para borrar) y
/// las fotos nuevas que suben con la orden.
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
    final surfaces = context.surfaces;
    final existing = detail?.initialEvidence ?? const <ServiceOrderMedia>[];

    return SectionCard(
      title: 'Evidencias',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (existing.isNotEmpty) ...<Widget>[
            Text(
              'Guardadas · toca la X para eliminarlas al guardar',
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            EvidenceMediaStrip(
              items: existing,
              markedForDeletion: deletedMediaIds,
              onToggleDelete: onToggleDelete,
            ),
            const SizedBox(height: 16),
          ],
          if (photos.isNotEmpty) ...<Widget>[
            DraftEvidenceStrip(images: photos, onRemove: onRemovePhoto),
            const SizedBox(height: 16),
          ],
          EvidencePickerRow(
            remaining: AppConfig.maxEvidenceImages - photos.length,
            isBusy: isPicking,
            onCamera: onCamera,
            onGallery: onGallery,
          ),
        ],
      ),
    );
  }
}

/// Campos personalizados de la orden (`custom_field_definitions`).
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
    return SectionCard(
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
      // `Material` transparente: el `SwitchListTile` vive dentro de un
      // `SectionCard` (con fondo propio) y sin él el *ripple* queda oculto.
      return Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isTruthy(widget.value),
          onChanged: widget.onChanged,
          title: Text(definition.name),
        ),
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
