import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/search_debouncer.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../customers/application/customers_providers.dart';
import '../../../customers/data/models/customer.dart';

/// Cliente elegido para la orden.
///
/// `createCustomer` corresponde a `create_customer: true` del contrato: el
/// servidor da de alta al cliente con los datos capturados (y `credit_limit`).
class ServiceOrderCustomerSelection {
  const ServiceOrderCustomerSelection({
    this.customerId,
    this.name = '',
    this.email,
    this.phone,
    this.createCustomer = false,
    this.creditLimit = 0,
  });

  final int? customerId;
  final String name;
  final String? email;
  final String? phone;
  final bool createCustomer;
  final double creditLimit;

  bool get hasRegisteredCustomer => (customerId ?? 0) > 0;
}

/// Selector de cliente de la orden (`GET /customers?search=`).
Future<ServiceOrderCustomerSelection?> showServiceOrderCustomerPicker(
  BuildContext context, {
  String initialName = '',
  String? initialEmail,
  String? initialPhone,
}) {
  return showModalBottomSheet<ServiceOrderCustomerSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _CustomerPickerSheet(
      initialName: initialName,
      initialEmail: initialEmail,
      initialPhone: initialPhone,
    ),
  );
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet({
    required this.initialName,
    this.initialEmail,
    this.initialPhone,
  });

  final String initialName;
  final String? initialEmail;
  final String? initialPhone;

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  final SearchDebouncer _debouncer = SearchDebouncer();

  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late final TextEditingController _phoneController = TextEditingController(
    text: widget.initialPhone ?? '',
  );
  late final TextEditingController _emailController = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final TextEditingController _creditController = TextEditingController(
    text: MoneyField.format(0),
  );

  String _search = '';
  bool _createCustomer = false;
  double _creditLimit = 0;

  @override
  void dispose() {
    _debouncer.cancel();
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final customers = ref.watch(customerSearchProvider(_search));

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
            'Cliente de la orden',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Puedes elegir un cliente registrado o capturar los datos a mano.',
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                _debouncer.run(() => setState(() => _search = value.trim())),
            style: EzyTextStyles.fieldValue.copyWith(
              color: surfaces.textPrimary,
            ),
            decoration: const InputDecoration(
              hintText: 'Buscar cliente por nombre, correo o teléfono…',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          customers.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (error, stackTrace) => const NoticeBanner(
              message: 'No se pudieron cargar los clientes.',
            ),
            data: (page) => page.items.isEmpty
                ? const NoticeBanner(
                    message: 'No hay clientes que coincidan con la búsqueda.',
                    tone: EzySeverity.info,
                  )
                : Column(
                    children: <Widget>[
                      for (final customer in page.items)
                        _CustomerTile(
                          customer: customer,
                          onTap: () => Navigator.of(context).pop(
                            ServiceOrderCustomerSelection(
                              customerId: customer.id,
                              name: customer.displayName,
                              email: customer.email,
                              phone: customer.phone,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _ManualCustomerCard(
            nameController: _nameController,
            phoneController: _phoneController,
            emailController: _emailController,
            creditController: _creditController,
            createCustomer: _createCustomer,
            onToggleCreate: (value) => setState(() => _createCustomer = value),
            onCreditChanged: (value) => setState(() => _creditLimit = value),
            onApply: _nameController.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(
                    ServiceOrderCustomerSelection(
                      name: _nameController.text.trim(),
                      email: _emailController.text.trim(),
                      phone: _phoneController.text.trim(),
                      createCustomer: _createCustomer,
                      creditLimit: _creditLimit,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Cliente de la lista con su saldo y crédito disponible.
class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer, required this.onTap});

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaces.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              customer.displayName,
              style: EzyTextStyles.bodyStrong.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
            if (customer.phone != null) ...<Widget>[
              const SizedBox(height: 2),
              Text(
                customer.phone!,
                style: EzyTextStyles.secondary.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              <String>[
                'Saldo ${Money.format(customer.balance)}',
                if (customer.hasCredit)
                  'Crédito disponible ${Money.format(customer.availableCredit)}',
              ].join(' · '),
              style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Captura manual del cliente (orden de mostrador) o alta al vuelo
/// (`create_customer` + `credit_limit`).
class _ManualCustomerCard extends StatelessWidget {
  const _ManualCustomerCard({
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.creditController,
    required this.createCustomer,
    required this.onToggleCreate,
    required this.onCreditChanged,
    required this.onApply,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController creditController;
  final bool createCustomer;
  final ValueChanged<bool> onToggleCreate;
  final ValueChanged<double> onCreditChanged;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Capturar cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Field(label: 'Nombre', controller: nameController),
          const SizedBox(height: 12),
          _Field(label: 'Teléfono', controller: phoneController),
          const SizedBox(height: 12),
          _Field(
            label: 'Correo electrónico',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: createCustomer,
            onChanged: onToggleCreate,
            title: Text(
              'Dar de alta este cliente',
              style: EzyTextStyles.bodyStrong.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
            subtitle: Text(
              'El servidor crea el cliente al guardar la orden.',
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ),
          if (createCustomer) ...<Widget>[
            const SizedBox(height: 8),
            MoneyField(
              label: 'Límite de crédito',
              isRequired: true,
              controller: creditController,
              onChanged: onCreditChanged,
              helperText: 'Requerido al dar de alta un cliente nuevo.',
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: onApply,
            child: const Text('Usar estos datos'),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return EzyTextField(
      label: label,
      controller: controller,
      keyboardType: keyboardType,
      maxLength: 255,
    );
  }
}
