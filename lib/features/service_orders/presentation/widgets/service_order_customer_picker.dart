import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../../../core/widgets/ezy_selectable_tile.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../customers/application/customers_providers.dart';
import '../../../customers/data/models/customer.dart';
import 'service_order_form_controls.dart';

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
///
/// La hoja sigue el prototipo validado "Tesla UI / EzyColors": lienzo gris con
/// las piezas en relieve —buscador, clientes y captura manual—, al 90 % del
/// alto, y el CTA 3D del módulo, verde cuando la orden da de alta al cliente.
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
    // Lienzo del módulo: las piezas llevan relleno de panel (`SoColors.card`) y
    // así se despegan del fondo gris; con el panel del tema —del mismo color
    // que ellas— la hoja quedaría plana.
    backgroundColor: SoColors.canvas(context),
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
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _creditController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customerSearchProvider(_search));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.90,
      minChildSize: 0.50,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        // El asa de arrastre, el radio 24 y el recorte los pinta el tema de
        // hojas; aquí solo se ajusta el aire interior.
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          EzySheetHeader(
            title: 'Cliente de la orden',
            subtitle:
                'Puedes elegir un cliente registrado o capturar los datos '
                'a mano.',
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          EzySearchField(
            hint: 'Buscar cliente por nombre, correo o teléfono…',
            height: 46,
            radius: 12,
            // Sobre el lienzo el campo necesita relleno de panel: el suyo por
            // defecto (`panelInner`) es del color del lienzo en modo oscuro.
            fillColor: SoColors.card(context),
            borderColor: SoColors.structuralBorder(context),
            onChanged: (value) => setState(() => _search = value.trim()),
          ),
          const SizedBox(height: 18),
          _clientsHeader(customers),
          const SizedBox(height: 10),
          _clientsBody(customers),
          const SizedBox(height: 20),
          _ManualCustomerCard(
            nameController: _nameController,
            phoneController: _phoneController,
            emailController: _emailController,
            creditController: _creditController,
            createCustomer: _createCustomer,
            onToggleCreate: (value) => setState(() => _createCustomer = value),
            onCreditChanged: (value) => setState(() => _creditLimit = value),
            // El nombre habilita «Usar estos datos»: sin reconstruir la tarjeta
            // el botón seguiría deshabilitado después de escribirlo.
            onNameChanged: (value) => setState(() {}),
            onApply: _nameController.text.trim().isEmpty ? null : _applyManual,
          ),
        ],
      ),
    );
  }

  /// Micro-título de la lista con el recuento de resultados a la derecha: la
  /// señal de que la búsqueda corrió aunque no haya coincidencias.
  Widget _clientsHeader(AsyncValue<Paginated<Customer>> customers) {
    return SoMicroLabel(
      'Clientes registrados',
      trailing: customers.when(
        loading: () => const SoTag(label: 'Buscando…', color: SoColors.info),
        error: (error, stackTrace) =>
            const SoTag(label: 'Sin datos', color: SoColors.danger),
        data: (page) {
          final total = page.total > 0 ? page.total : page.items.length;

          return SoTag(
            label: total == 0
                ? 'Sin resultados'
                : '$total ${total == 1 ? 'cliente' : 'clientes'}',
            color: total == 0 ? SoColors.info : SoColors.primary,
          );
        },
      ),
    );
  }

  /// Los cuatro estados de la consulta (`GET /customers?search=`): cargando,
  /// error, vacío y resultados. Los tres primeros van dentro de una pieza
  /// (`SoCard`) para no dejar el lienzo gris sin contenido.
  Widget _clientsBody(AsyncValue<Paginated<Customer>> customers) {
    return customers.when(
      loading: () => SoCard(
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Buscando clientes…',
                style: EzyTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: SoColors.textSecondary(context),
                ),
              ),
            ),
          ],
        ),
      ),
      error: (error, stackTrace) => const SoCard(
        child: SoNote(
          text: 'No se pudieron cargar los clientes.',
          icon: Icons.error_outline,
          color: SoColors.danger,
        ),
      ),
      data: (page) => page.items.isEmpty
          ? const SoCard(
              child: SoNote(
                text: 'No hay clientes que coincidan con la búsqueda.',
                icon: Icons.person_search_outlined,
                color: SoColors.info,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final customer in page.items)
                  _CustomerTile(
                    customer: customer,
                    onTap: () => _choose(customer),
                  ),
              ],
            ),
    );
  }

  /// Cliente registrado elegido: vuelve con su id y sus datos de contacto.
  void _choose(Customer customer) {
    Navigator.of(context).pop(
      ServiceOrderCustomerSelection(
        customerId: customer.id,
        name: customer.displayName,
        email: customer.email,
        phone: customer.phone,
      ),
    );
  }

  /// Datos capturados a mano; con `create_customer` el servidor lo da de alta.
  void _applyManual() {
    Navigator.of(context).pop(
      ServiceOrderCustomerSelection(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        createCustomer: _createCustomer,
        creditLimit: _creditLimit,
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
    // El saldo se tiñe según el estado: rojo si debe, verde si trae saldo a
    // favor, gris neutro si está en cero.
    final Color? captionColor = customer.hasDebt
        ? SoColors.tone(context, SoColors.danger)
        : customer.hasBalanceInFavor
        ? SoColors.tone(context, SoColors.success)
        : null;

    return EzySelectableTile(
      // Sobre el lienzo gris la fila se rellena de panel: así se lee como pieza
      // y no como un hueco del fondo.
      fillColor: SoColors.card(context),
      title: customer.displayName,
      subtitle: customer.phone,
      caption: <String>[
        'Saldo ${Money.format(customer.balance)}',
        if (customer.hasCredit)
          'Crédito disponible ${Money.format(customer.availableCredit)}',
      ].join(' · '),
      captionColor: captionColor,
      isSelected: false,
      onTap: onTap,
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
    required this.onNameChanged,
    required this.onApply,
  });

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController creditController;
  final bool createCustomer;
  final ValueChanged<bool> onToggleCreate;
  final ValueChanged<double> onCreditChanged;
  final ValueChanged<String> onNameChanged;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    // Los campos van dentro de la pieza (`SoCard`): relleno interno y borde
    // estructural, como los renglones de conceptos del módulo.
    final fill = SoColors.inner(context);
    final border = SoColors.structuralBorder(context);

    return SoCard(
      title: 'Capturar cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EzyTextField(
            label: 'Nombre',
            controller: nameController,
            maxLength: 255,
            onChanged: onNameChanged,
            textInputAction: TextInputAction.next,
            fieldHeight: 46,
            borderRadius: 12,
            borderColor: border,
            fillColor: fill,
          ),
          const SizedBox(height: 12),
          EzyTextField(
            label: 'Teléfono',
            controller: phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 255,
            textInputAction: TextInputAction.next,
            fieldHeight: 46,
            borderRadius: 12,
            borderColor: border,
            fillColor: fill,
          ),
          const SizedBox(height: 12),
          EzyTextField(
            label: 'Correo electrónico',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            maxLength: 255,
            fieldHeight: 46,
            borderRadius: 12,
            borderColor: border,
            fillColor: fill,
          ),
          const SizedBox(height: 12),
          _createToggle(context),
          if (createCustomer) ...<Widget>[
            const SizedBox(height: 12),
            MoneyField(
              label: 'Límite de crédito',
              isRequired: true,
              controller: creditController,
              onChanged: onCreditChanged,
              helperText: 'Requerido al dar de alta un cliente nuevo.',
              // El `$` en verde ata el campo con el aviso y con la pieza: el
              // cliente es nuevo.
              prefixColor: SoColors.tone(context, SoColors.success),
              suffixText: 'MXN',
              fieldHeight: 46,
              borderRadius: 12,
              borderColor: border,
              fillColor: fill,
            ),
            const SizedBox(height: 10),
            const SoNote(
              text:
                  'El cliente se dará de alta con estos datos al guardar la '
                  'orden.',
              icon: Icons.person_add_alt,
              color: SoColors.success,
            ),
          ],
          const SizedBox(height: 14),
          // Botón 3D del módulo: naranja de marca y verde cuando la orden dará
          // de alta al cliente nuevo.
          SoPrimaryButton(
            label: 'Usar estos datos',
            icon: Icons.check,
            baseColor: createCustomer ? SoColors.success : SoColors.primary,
            onPressed: onApply,
          ),
        ],
      ),
    );
  }

  /// Fila del alta al vuelo; se tiñe de verde al encenderse para que el cambio
  /// se lea sin tener que mirar el interruptor.
  Widget _createToggle(BuildContext context) {
    return Material(
      // `Material` transparente: el `SoCard` pinta su propio fondo y sin él el
      // *ripple* del interruptor quedaría debajo del fondo.
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: createCustomer
              ? SoColors.success.withValues(alpha: 0.12)
              : SoColors.inner(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: createCustomer
                ? SoColors.success.withValues(alpha: 0.40)
                : SoColors.structuralBorder(context),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Dar de alta este cliente',
                    style: EzyTextStyles.bodyStrong.copyWith(
                      fontSize: 14,
                      color: SoColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'El servidor crea el cliente al guardar la orden.',
                    style: EzyTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: SoColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SoSwitch(value: createCustomer, onChanged: onToggleCreate),
          ],
        ),
      ),
    );
  }
}
