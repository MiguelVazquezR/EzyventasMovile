import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/field_label.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../application/cart_state.dart';
import '../../data/models/store_order_draft.dart';

/// Datos del pedido o comanda (`POST /pos/store-order`).
///
/// Devuelve `true` cuando el pedido quedó registrado (el folio lo muestra la
/// hoja del carrito).
Future<bool> showStoreOrderSheet(BuildContext context) async {
  final result = await EzyBottomSheet.show<bool>(
    context,
    maxHeightFactor: 0.96,
    builder: (sheetContext) => const _StoreOrderSheet(),
  );

  return result ?? false;
}

class _StoreOrderSheet extends ConsumerStatefulWidget {
  const _StoreOrderSheet();

  @override
  ConsumerState<_StoreOrderSheet> createState() => _StoreOrderSheetState();
}

class _StoreOrderSheetState extends ConsumerState<_StoreOrderSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _shippingController = TextEditingController(
    text: '0',
  );
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _deliveryController = TextEditingController();

  String _type = StoreOrderDraft.pedido;
  DateTime? _deliveryDate;
  double _shippingCost = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _shippingController.dispose();
    _notesController.dispose();
    _deliveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EzySheetHeader(
          title: _type == StoreOrderDraft.comanda ? 'Comanda' : 'Pedido',
          subtitle: 'El stock queda reservado; se cobra al entregar.',
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              SectionCard(
                title: 'Datos de contacto',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TypeSelector(
                      type: _type,
                      onChanged: (value) => setState(() => _type = value),
                    ),
                    const SizedBox(height: 16),
                    EzyTextField(
                      label: 'Nombre de quien recibe',
                      isRequired: true,
                      controller: _nameController,
                      errorText: _nameError(cart),
                      maxLength: 255,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    EzyTextField(
                      label: 'Teléfono',
                      hint: 'Opcional',
                      keyboardType: TextInputType.phone,
                      controller: _phoneController,
                      errorText: cart.errorFor('contact_info.phone'),
                      maxLength: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _DeliveryCard(
                cart: cart,
                deliveryController: _deliveryController,
                addressController: _addressController,
                shippingController: _shippingController,
                notesController: _notesController,
                onPickDate: _pickDeliveryDate,
                onShippingChanged: (value) =>
                    setState(() => _shippingCost = value),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Totales',
                child: Column(
                  children: <Widget>[
                    SectionRow(
                      label: 'Productos',
                      value: Money.format(cart.total),
                    ),
                    SectionRow(
                      label: 'Envío',
                      value: Money.format(_shippingCost),
                    ),
                    const Divider(height: 24),
                    SectionRow(
                      label: 'Total del pedido',
                      value: Money.format(cart.total + _shippingCost),
                      emphasized: true,
                    ),
                  ],
                ),
              ),
              if (cart.errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                NoticeBanner(message: cart.errorMessage!),
              ],
            ],
          ),
        ),
        // El alta del pedido es la acción principal de la hoja: 56 al pie.
        EzyActionBar(
          child: EzyButton(
            label: 'Registrar pedido',
            icon: Icons.check_outlined,
            height: 56,
            isLoading: cart.isSubmitting,
            onPressed: _canSubmit ? _submit : null,
          ),
        ),
      ],
    );
  }

  /// El servidor exige el nombre (mín. 2 caracteres) y la fecha de entrega.
  String? _nameError(CartState cart) {
    final name = _nameController.text.trim();

    // El botón ya está deshabilitado sin nombre: solo se marca el error cuando
    // el usuario escribió algo inválido o el servidor lo rechazó.
    if (name.isNotEmpty && name.length < 2) {
      return 'El nombre del contacto debe tener al menos 2 caracteres.';
    }

    return cart.errorFor('contact_info.name');
  }

  bool get _canSubmit =>
      _nameController.text.trim().length >= 2 && _deliveryDate != null;

  Future<void> _submit() async {
    final sessionId = ref.read(activeCashSessionProvider)?.id;
    if (sessionId == null) {
      return;
    }

    final result = await ref
        .read(cartControllerProvider.notifier)
        .submitOrder(
          sessionId: sessionId,
          order: StoreOrderDraft(
            contactName: _nameController.text,
            contactPhone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text,
            type: _type,
            deliveryDate: _deliveryDate!,
            shippingAddress: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text,
            shippingCost: _shippingCost,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        );

    if (result != null && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Fecha y hora de entrega (obligatoria para el servidor).
  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Fecha de entrega',
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deliveryDate ?? now),
      helpText: 'Hora de entrega',
    );

    if (time == null) {
      return;
    }

    final delivery = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _deliveryDate = delivery;
      _deliveryController.text = AppFormatters.dateTime(delivery);
    });
  }
}

/// Entrega: fecha y hora, dirección, costo de envío y notas.
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.cart,
    required this.deliveryController,
    required this.addressController,
    required this.shippingController,
    required this.notesController,
    required this.onPickDate,
    required this.onShippingChanged,
  });

  final CartState cart;
  final TextEditingController deliveryController;
  final TextEditingController addressController;
  final TextEditingController shippingController;
  final TextEditingController notesController;
  final VoidCallback onPickDate;
  final ValueChanged<double> onShippingChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Entrega',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EzyTextField(
            label: 'Fecha y hora de entrega',
            isRequired: true,
            readOnly: true,
            controller: deliveryController,
            hint: 'Seleccionar fecha…',
            errorText: cart.errorFor('delivery_date'),
            suffix: const Icon(Icons.event_outlined, size: 18),
            onTap: onPickDate,
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: 'Dirección de entrega',
            hint: 'Opcional',
            controller: addressController,
            errorText: cart.errorFor('shipping_address'),
            maxLines: 2,
            maxLength: 255,
          ),
          const SizedBox(height: 16),
          MoneyField(
            label: 'Costo de envío',
            controller: shippingController,
            onChanged: onShippingChanged,
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: 'Notas',
            hint: 'Opcional',
            controller: notesController,
            maxLines: 3,
            maxLength: 1000,
          ),
        ],
      ),
    );
  }
}

/// Tipo de pedido: retail (`pedido`) o modo comandas (`comanda`).
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.type, required this.onChanged});

  final String type;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const FieldLabel('Tipo'),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: EzyButton(
                label: 'Pedido',
                variant: type == StoreOrderDraft.pedido
                    ? EzyButtonVariant.primary
                    : EzyButtonVariant.outline,
                onPressed: () => onChanged(StoreOrderDraft.pedido),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: EzyButton(
                label: 'Comanda',
                variant: type == StoreOrderDraft.comanda
                    ? EzyButtonVariant.primary
                    : EzyButtonVariant.outline,
                onPressed: () => onChanged(StoreOrderDraft.comanda),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
