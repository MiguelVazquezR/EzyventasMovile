import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/evidence_image.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/ezy_text_field.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../cash/data/models/active_cash_session.dart';
import '../application/service_orders_controller.dart';
import '../data/models/service_order_detail.dart';
import '../data/models/service_order_form.dart';
import '../data/models/service_order_item_draft.dart';
import 'widgets/evidence_picker_row.dart';
import 'widgets/service_order_customer_picker.dart';
import 'widgets/service_order_form_sections.dart';
import 'widgets/service_order_items_sheet.dart';

/// Alta y edición de una orden de servicio (`POST` / `PUT`, contrato §9).
///
/// El servidor decide el folio, la venta vinculada, la deuda del cliente y el
/// stock; el formulario solo captura los campos del contrato y calcula los tres
/// totales que ese mismo contrato pide (`subtotal`, `discount_amount`,
/// `final_total`). Requiere una sesión de caja abierta: sin ella se avisa y se
/// ofrece ir a Caja en lugar de enviar la petición.
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
  TechnicianCommissionType _commissionType = TechnicianCommissionType.percentage;
  double _commissionValue = 0;
  ServiceOrderDiscountType _discountType = ServiceOrderDiscountType.fixed;
  double _discountValue = 0;
  List<ServiceOrderItemDraft> _items = const <ServiceOrderItemDraft>[];
  Map<String, dynamic> _customFields = const <String, dynamic>{};
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
    _customFields = Map<String, dynamic>.of(detail.customFields);
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

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _isPicking = true);

    final remaining = AppConfig.maxEvidenceImages - _photos.length;
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
  List<ServiceOrderCustomFieldDefinition> _customFieldDefinitions() {
    if (_isEditing) {
      return _loaded?.customFieldDefinitions ??
          const <ServiceOrderCustomFieldDefinition>[];
    }

    return ref.watch(serviceOrderCustomFieldsProvider).asData?.value ??
        const <ServiceOrderCustomFieldDefinition>[];
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
      customFields: _customFields,
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
      return _buildScaffold(_body(formState, session));
    }

    final detail = ref.watch(serviceOrderDetailProvider(id));

    return detail.when(
      loading: () => _buildScaffold(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (error, stackTrace) => _buildScaffold(
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

        return _buildScaffold(_body(formState, session));
      },
    );
  }

  Widget _buildScaffold(Widget body) {
    final surfaces = context.surfaces;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Regresar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: surfaces.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _isEditing ? 'Editar orden' : 'Nueva orden',
                      style: EzyTextStyles.screenTitle.copyWith(
                        color: surfaces.textPrimary,
                      ),
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

  /// Secciones del formulario (§8.1 y §8.3 del documento maestro).
  Widget _body(ServiceOrderFormState formState, ActiveCashSession? session) {
    final surfaces = context.surfaces;
    final form = _buildFormData();
    final definitions = _customFieldDefinitions();
    final fieldsError = !_isEditing &&
        ref.watch(serviceOrderCustomFieldsProvider).hasError;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
        SectionCard(
          title: 'Cliente',
          trailing: TextButton(
            onPressed: _pickCustomer,
            child: Text((_customerId ?? 0) > 0 ? 'Cambiar' : 'Seleccionar'),
          ),
          child: Column(
            children: <Widget>[
              SectionRow(
                label: 'Cliente',
                value: _nameController.text.trim().isEmpty
                    ? 'Sin capturar'
                    : _nameController.text.trim(),
                emphasized: true,
              ),
              if (_createCustomer)
                SectionRow(
                  label: 'Alta al guardar',
                  value: 'Crédito ${Money.format(_creditLimit)}',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Equipo y fallas',
          child: Column(
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
                hint: 'Seleccionar fecha…',
                suffix: const Icon(Icons.calendar_today_outlined, size: 18),
                onTap: _pickDate,
              ),
            ],
          ),
        ),
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
            values: _customFields,
            onChanged: (key, value) => setState(
              () => _customFields = <String, dynamic>{
                ..._customFields,
                key: value,
              },
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
        _TotalsSection(form: form),
        const SizedBox(height: 16),
        EzyButton(
          label: _isEditing ? 'Guardar cambios' : 'Crear orden',
          icon: Icons.save_outlined,
          isLoading: formState.isSubmitting,
          onPressed: form.isComplete && session != null && !formState.isSubmitting
              ? _submit
              : null,
        ),
        if (!form.isComplete) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Completa el equipo, las fallas y el cliente para guardar.',
            textAlign: TextAlign.center,
            style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
          ),
        ],
      ],
    );
  }
}

/// Totales que el formulario envía al servidor (`subtotal`,
/// `discount_amount` y `final_total`).
class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.form});

  final ServiceOrderFormData form;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Totales',
      child: Column(
        children: <Widget>[
          SectionRow(label: 'Subtotal', value: Money.format(form.subtotal)),
          if (form.discountAmount > 0)
            SectionRow(
              label: 'Descuento',
              value: '- ${Money.format(form.discountAmount)}',
            ),
          const Divider(height: 20),
          SectionRow(
            label: 'Total de la orden',
            value: Money.format(form.finalTotal),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}
