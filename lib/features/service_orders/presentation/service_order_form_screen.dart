import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/evidence_image.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/ezy_text_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../cash/data/models/active_cash_session.dart';
import '../application/service_orders_controller.dart';
import '../data/models/custom_fields_bag.dart';
import '../data/models/service_order_detail.dart';
import '../data/models/service_order_form.dart';
import '../data/models/service_order_item_draft.dart';
import 'widgets/evidence_picker_row.dart';
import 'widgets/service_order_customer_picker.dart';
import 'widgets/service_order_form_controls.dart';
import 'widgets/service_order_form_sections.dart';
import 'widgets/service_order_items_sheet.dart';
import 'widgets/service_order_labels.dart';

/// Alta y edición de una orden de servicio (`POST` / `PUT`, contrato §9).
///
/// El servidor decide el folio, la venta vinculada, la deuda del cliente y el
/// stock; el formulario solo captura los campos del contrato y calcula los tres
/// totales que ese mismo contrato pide (`subtotal`, `discount_amount`,
/// `final_total`). Requiere una sesión de caja abierta: sin ella se avisa y se
/// ofrece ir a Caja en lugar de enviar la petición.
///
/// La pantalla sigue el prototipo validado "Tesla UI / EzyColors": cabecera fija
/// sin `AppBar`, lienzo propio (`SoColors.canvas`), ocho cards sobre el mismo
/// sistema de controles (`SoCard`, `SoInfoRow`, `SoPrimaryButton`) y un pie que
/// explica qué hace el servidor al guardar.
class ServiceOrderFormScreen extends ConsumerStatefulWidget {
  const ServiceOrderFormScreen({super.key, this.serviceOrderId});

  /// `null` = alta; con id = edición.
  final int? serviceOrderId;

  @override
  ConsumerState<ServiceOrderFormScreen> createState() =>
      _ServiceOrderFormScreenState();
}

class _ServiceOrderFormScreenState
    extends ConsumerState<ServiceOrderFormScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _equipmentController = TextEditingController();
  final TextEditingController _problemsController = TextEditingController();
  final TextEditingController _promisedController = TextEditingController();
  final TextEditingController _technicianController = TextEditingController();
  final TextEditingController _commissionController = TextEditingController();
  final TextEditingController _discountController = TextEditingController(
    text: MoneyField.format(0),
  );

  int? _customerId;
  bool _createCustomer = false;
  double _creditLimit = 0;
  DateTime? _promisedAt;
  bool _assignTechnician = false;
  TechnicianCommissionType _commissionType =
      TechnicianCommissionType.percentage;
  double _commissionValue = 0;
  ServiceOrderDiscountType _discountType = ServiceOrderDiscountType.fixed;
  double _discountValue = 0;
  List<ServiceOrderItemDraft> _items = const <ServiceOrderItemDraft>[];

  /// Bolsa `custom_fields` del formulario (§2.2): se inicializa con una entrada
  /// por definición (§5) y se reenvía **completa** en el `POST`/`PUT`.
  CustomFieldsBag? _customFieldsBag;

  /// La bolsa ya se armó con definiciones reales (el alta las carga async).
  bool _customFieldsBagIsComplete = false;
  List<EvidenceImage> _photos = <EvidenceImage>[];
  final Set<int> _deletedMediaIds = <int>{};
  ServiceOrderDetail? _loaded;
  bool _isPicking = false;

  bool get _isEditing => widget.serviceOrderId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _equipmentController.dispose();
    _problemsController.dispose();
    _promisedController.dispose();
    _technicianController.dispose();
    _commissionController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  /// Precarga el formulario con la orden que se edita (una sola vez).
  void _prefill(ServiceOrderDetail detail) {
    if (_loaded != null) {
      return;
    }

    _loaded = detail;

    _nameController.text = detail.customerLabel;
    _phoneController.text = detail.customer?.phone ?? '';
    _emailController.text = detail.customerEmail ?? '';
    _equipmentController.text = detail.itemDescription;
    _problemsController.text = detail.reportedProblems;
    _technicianController.text = detail.technicianName ?? '';
    _customerId = detail.customer?.id;
    _promisedAt = detail.promisedAt;
    _promisedController.text = detail.promisedAt == null
        ? ''
        : AppFormatters.date(detail.promisedAt);
    _assignTechnician = detail.hasTechnician;
    _commissionType = TechnicianCommissionType.fromValue(
      detail.technicianCommissionType,
    );
    _commissionValue = detail.technicianCommissionValue;
    _commissionController.text = MoneyField.format(_commissionValue);
    _items = detail.items
        .map(ServiceOrderItemDraft.fromItem)
        .toList(growable: false);
    _discountType = ServiceOrderDiscountType.fromValue(detail.discountType);
    _discountValue = detail.discountValue;
    _discountController.text = MoneyField.format(_discountValue);
  }

  Future<void> _pickCustomer() async {
    final selection = await showServiceOrderCustomerPicker(
      context,
      initialName: _nameController.text,
      initialEmail: _emailController.text,
      initialPhone: _phoneController.text,
    );

    if (selection == null || !mounted) {
      return;
    }

    setState(() {
      _customerId = selection.customerId;
      _createCustomer = selection.createCustomer;
      _creditLimit = selection.creditLimit;
      _nameController.text = selection.name;
      _phoneController.text = selection.phone ?? '';
      _emailController.text = selection.email ?? '';
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _promisedAt ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 3),
      helpText: 'Fecha prometida de entrega',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _promisedAt = picked;
      _promisedController.text = AppFormatters.date(picked);
    });
  }

  Future<void> _editItems() async {
    final items = await showServiceOrderItemsSheet(context, items: _items);

    if (items == null || !mounted) {
      return;
    }

    setState(() => _items = items);
  }

  /// Cupos libres de evidencia: el máximo del servidor menos las fotos que
  /// viajarían si la orden se guardara ahora (guardadas vigentes + capturas).
  int get _remainingSlots {
    final kept = (_loaded?.initialEvidence ?? const <ServiceOrderMedia>[])
        .where((media) => !_deletedMediaIds.contains(media.id))
        .length;
    final free = AppConfig.maxEvidenceImages - kept - _photos.length;

    return free < 0 ? 0 : free;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final remaining = _remainingSlots;

    if (remaining <= 0) {
      return;
    }

    setState(() => _isPicking = true);

    final picked = await captureEvidence(
      context,
      source: source,
      remaining: remaining,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _photos = <EvidenceImage>[..._photos, ...picked];
      _isPicking = false;
    });
  }

  /// Campos personalizados del módulo que hay que dibujar.
  ///
  /// En la edición vienen dentro del detalle de la orden; en el alta se piden a
  /// `GET /service-orders/custom-fields` (§9), porque todavía no hay orden de la
  /// que sacarlos.
  List<CustomFieldDefinition> _customFieldDefinitions() {
    if (_isEditing) {
      return _loaded?.customFieldDefinitions ??
          const <CustomFieldDefinition>[];
    }

    return ref.watch(serviceOrderCustomFieldsProvider).asData?.value ??
        const <CustomFieldDefinition>[];
  }

  /// Bolsa inicializada una sola vez con las definiciones y lo ya guardado (§5).
  ///
  /// No se deriva al vuelo del formulario: se guarda en el estado y se reenvía
  /// completa, que es lo que el `PUT` espera (reemplaza el JSON entero). En el
  /// alta las definiciones llegan por red, así que la bolsa se rearma la primera
  /// vez que el endpoint responde con contenido.
  CustomFieldsBag _customFieldsBagFor(List<CustomFieldDefinition> definitions) {
    final bag = _customFieldsBag;

    if (bag != null && (_customFieldsBagIsComplete || definitions.isEmpty)) {
      return bag;
    }

    final initialized = CustomFieldsBag.initialFor(
      definitions,
      stored: _loaded?.customFields ?? const <String, dynamic>{},
    );

    _customFieldsBag = initialized;
    _customFieldsBagIsComplete = definitions.isNotEmpty;

    return initialized;
  }

  /// Arma el payload del contrato con lo capturado en pantalla.
  ServiceOrderFormData _buildFormData() {
    final loaded = _loaded;

    return ServiceOrderFormData(
      customerId: _customerId,
      createCustomer: !_isEditing && _createCustomer,
      creditLimit: _creditLimit,
      customerName: _nameController.text.trim(),
      customerEmail: _emailController.text,
      customerPhone: _phoneController.text,
      addressStreet: loaded?.customerAddress?.street,
      addressCity: loaded?.customerAddress?.city,
      itemDescription: _equipmentController.text,
      reportedProblems: _problemsController.text,
      promisedAt: _promisedAt,
      assignTechnician: _assignTechnician,
      technicianName: _technicianController.text,
      commissionType: _commissionType,
      commissionValue: _commissionValue,
      items: _items,
      discountType: _discountType,
      discountValue: _discountValue,
      customFields: _customFieldsBag?.toJson() ?? const <String, dynamic>{},
      evidence: _photos,
      deletedMediaIds: _deletedMediaIds.toList(growable: false),
    );
  }

  Future<void> _submit() async {
    final sessionId = ref.read(activeCashSessionProvider)?.id;
    if (sessionId == null) {
      return;
    }

    final saved = await ref
        .read(serviceOrderFormControllerProvider.notifier)
        .submit(
          form: _buildFormData(),
          sessionId: sessionId,
          serviceOrderId: widget.serviceOrderId,
        );

    if (!mounted || saved == null) {
      return;
    }

    Navigator.of(context).pop(saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Orden ${saved.folio} actualizada.'
              : 'Orden de servicio creada. Folio ${saved.folio}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(serviceOrderFormControllerProvider);
    final session = ref.watch(activeCashSessionProvider);
    final id = widget.serviceOrderId;

    if (id == null) {
      return _scaffold(_body(formState, session));
    }

    final detail = ref.watch(serviceOrderDetailProvider(id));

    return detail.when(
      loading: () => _scaffold(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stackTrace) => _scaffold(
        Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorNotice(
            message: 'No se pudo cargar la orden.',
            onRetry: () => ref.invalidate(serviceOrderDetailProvider(id)),
          ),
        ),
      ),
      data: (detail) {
        _prefill(detail);

        return _scaffold(_body(formState, session));
      },
    );
  }

  /// Lienzo del prototipo: cabecera fija sin `AppBar` y fondo propio.
  ///
  /// La cabecera muestra el título y, al editar, el folio con su estatus; el
  /// cuerpo hace scroll debajo para que las acciones nunca se pierdan.
  Widget _scaffold(Widget body) {
    final loaded = _loaded;

    return Scaffold(
      backgroundColor: SoColors.canvas(context),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 16, 10),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Regresar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: SoColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _isEditing ? 'Editar orden' : 'Nueva orden',
                          style: EzyTextStyles.screenTitle.copyWith(
                            color: SoColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loaded == null
                              ? 'El folio lo genera el servidor al guardar.'
                              : 'Folio ${loaded.summary.folio} · '
                                    '${loaded.summary.statusLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EzyTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: SoColors.textMuted(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  /// Cards 1 a 7 y el cierre de la pantalla (§8.1 y §8.3 del documento maestro).
  Widget _body(ServiceOrderFormState formState, ActiveCashSession? session) {
    final form = _buildFormData();
    final definitions = _customFieldDefinitions();
    final customFields = _customFieldsBagFor(definitions);
    final fieldsError =
        !_isEditing && ref.watch(serviceOrderCustomFieldsProvider).hasError;
    final canSubmit =
        form.isComplete && session != null && !formState.isSubmitting;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: <Widget>[
        if (session == null) ...<Widget>[
          NoticeBanner(
            message:
                'Necesitas una sesión de caja abierta para guardar la orden '
                '(el servidor crea la venta vinculada).',
            tone: EzySeverity.warn,
            actionLabel: 'Ir a caja',
            onAction: () => context.go(AppTab.cashRegister.path),
          ),
          const SizedBox(height: 12),
        ],
        if (formState.errorMessage != null) ...<Widget>[
          NoticeBanner(
            message: formState.errorMessage!,
            actionLabel: 'Ocultar',
            onAction: ref
                .read(serviceOrderFormControllerProvider.notifier)
                .consumeError,
          ),
          const SizedBox(height: 12),
        ],
        _clientCard(),
        const SizedBox(height: 12),
        _equipmentCard(),
        const SizedBox(height: 12),
        ServiceOrderItemsSection(
          items: _items,
          subtotal: form.subtotal,
          onEdit: _editItems,
        ),
        const SizedBox(height: 12),
        ServiceOrderDiscountSection(
          type: _discountType,
          controller: _discountController,
          discountAmount: form.discountAmount,
          subtotal: form.subtotal,
          onTypeChanged: (type) => setState(() => _discountType = type),
          onValueChanged: (value) => setState(() => _discountValue = value),
        ),
        const SizedBox(height: 12),
        ServiceOrderTechnicianSection(
          assign: _assignTechnician,
          nameController: _technicianController,
          commissionController: _commissionController,
          commissionType: _commissionType,
          onAssignChanged: (value) => setState(() => _assignTechnician = value),
          onCommissionTypeChanged: (type) =>
              setState(() => _commissionType = type),
          onCommissionValueChanged: (value) =>
              setState(() => _commissionValue = value),
        ),
        const SizedBox(height: 12),
        ServiceOrderEvidenceSection(
          detail: _loaded,
          photos: _photos,
          deletedMediaIds: _deletedMediaIds,
          isPicking: _isPicking,
          onCamera: () => _pickPhoto(ImageSource.camera),
          onGallery: () => _pickPhoto(ImageSource.gallery),
          onRemovePhoto: (index) => setState(() => _photos.removeAt(index)),
          onToggleDelete: (mediaId) => setState(() {
            if (!_deletedMediaIds.remove(mediaId)) {
              _deletedMediaIds.add(mediaId);
            }
          }),
        ),
        if (definitions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          ServiceOrderCustomFieldsSection(
            definitions: definitions,
            values: customFields.values,
            onChanged: (key, value) => setState(
              () => _customFieldsBag = customFields.withValue(key, value),
            ),
          ),
        ] else if (fieldsError) ...<Widget>[
          const SizedBox(height: 12),
          const NoticeBanner(
            message:
                'No se pudieron cargar los campos personalizados del módulo. '
                'Puedes crear la orden y capturarlos al editarla.',
            tone: EzySeverity.warn,
          ),
        ],
        const SizedBox(height: 12),
        _totalsCard(form),
        const SizedBox(height: 16),
        SoPrimaryButton(
          label: _isEditing ? 'Guardar cambios' : 'Crear orden',
          icon: Icons.save_outlined,
          isLoading: formState.isSubmitting,
          onPressed: canSubmit ? _submit : null,
        ),
        const SizedBox(height: 10),
        SoNote(
          text: form.isComplete
              ? 'Al guardar, el servidor genera el folio, vincula la venta y '
                    'descuenta el stock de las refacciones.'
              : 'Completa el equipo, las fallas y el cliente para poder '
                    'guardar la orden.',
          icon: form.isComplete
              ? Icons.cloud_done_outlined
              : Icons.rule_folder_outlined,
          color: form.isComplete ? SoColors.info : SoColors.warn,
        ),
      ],
    );
  }

  /// Card 1: cliente de la orden, con acceso al selector y aviso de alta.
  Widget _clientCard() {
    final name = _nameController.text.trim();
    final contact = <String>[
      if (_phoneController.text.trim().isNotEmpty) _phoneController.text.trim(),
      if (_emailController.text.trim().isNotEmpty) _emailController.text.trim(),
    ].join(' · ');

    return SoCard(
      title: 'Cliente',
      trailing: SoTextAction(
        label: (_customerId ?? 0) > 0 ? 'Cambiar' : 'Seleccionar',
        icon: Icons.person_search_outlined,
        onPressed: _pickCustomer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (name.isEmpty)
            const SoNote(
              text:
                  'Sin cliente asignado: búscalo en el catálogo o créalo con '
                  '"Dar de alta" desde el selector.',
              icon: Icons.person_outline,
              color: SoColors.info,
            )
          else ...<Widget>[
            Text(
              name,
              style: EzyTextStyles.bodyStrong.copyWith(
                color: SoColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              contact.isEmpty ? 'Sin teléfono ni correo' : contact,
              style: EzyTextStyles.caption.copyWith(
                color: SoColors.textMuted(context),
              ),
            ),
          ],
          if (_createCustomer) ...<Widget>[
            const SizedBox(height: 12),
            SoInfoRow(
              label: 'Alta al guardar',
              value: 'Crédito ${Money.format(_creditLimit)}',
              emphasized: true,
              color: SoColors.success,
            ),
          ],
        ],
      ),
    );
  }

  /// Card 2: equipo recibido, fallas reportadas y promesa de entrega.
  Widget _equipmentCard() {
    return SoCard(
      title: 'Equipo y fallas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EzyTextField(
            label: 'Equipo recibido',
            isRequired: true,
            controller: _equipmentController,
            hint: 'Ej. iPhone 13, pantalla rota',
            maxLength: 255,
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: 'Fallas reportadas',
            isRequired: true,
            controller: _problemsController,
            hint: 'Ej. No enciende después de una caída',
            maxLines: 3,
            onChanged: (value) => setState(() {}),
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: 'Promesa de entrega',
            controller: _promisedController,
            readOnly: true,
            hint: 'Sin promesa',
            suffix: const Icon(Icons.calendar_today_outlined, size: 18),
            onTap: _pickDate,
          ),
          const SizedBox(height: 10),
          const SoNote(
            text:
                'La promesa es opcional; si se vence, el listado marca la '
                'orden como entrega tardía.',
            icon: Icons.event_available_outlined,
            color: SoColors.info,
          ),
        ],
      ),
    );
  }

  /// Card 8: totales reactivos que el formulario manda al servidor (§9).
  ///
  /// Se recalculan con cada tecla (`ServiceOrderFormData.subtotal`,
  /// `discountAmount` y `finalTotal`) para que lo que se ve sea exactamente lo
  /// que viaja en el payload; el descuento ya viene limitado al subtotal.
  Widget _totalsCard(ServiceOrderFormData form) {
    final hasDiscount = form.discountAmount > 0;

    return SoCard(
      title: 'Totales',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SoInfoRow(
            label: 'Conceptos',
            value: ServiceOrderLabels.items(_items.length),
          ),
          const SizedBox(height: 8),
          SoInfoRow(label: 'Subtotal', value: Money.format(form.subtotal)),
          if (hasDiscount) ...<Widget>[
            const SizedBox(height: 8),
            SoInfoRow(
              label: _discountType == ServiceOrderDiscountType.percentage
                  ? 'Descuento (${Money.formatQuantity(_discountValue)} %)'
                  : 'Descuento',
              value: '- ${Money.format(form.discountAmount)}',
              color: SoColors.tone(context, SoColors.danger),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: SoColors.inner(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: SoColors.structuralBorder(context)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Total de la orden',
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: SoColors.textPrimary(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Money.format(form.finalTotal),
                  style: EzyTextStyles.moneyMedium.copyWith(
                    color: SoColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
