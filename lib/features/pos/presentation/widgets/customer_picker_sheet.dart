import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../../../core/widgets/ezy_selectable_tile.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../customers/application/customers_providers.dart';
import '../../application/cart_controller.dart';

/// Selector de cliente del cobro (`GET /customers`).
///
/// Guarda la elección en el carrito; "Público general" lo deja sin cliente y
/// permite capturar un nombre para el ticket (`guest_name`).
Future<void> showCustomerPickerSheet(BuildContext context) {
  return EzyBottomSheet.show<void>(
    context,
    builder: (sheetContext) => const _CustomerPickerSheet(),
  );
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final TextEditingController _guestController = TextEditingController();

  String _search = '';

  @override
  void initState() {
    super.initState();
    _guestController.text = ref.read(cartControllerProvider).guestName;
  }

  @override
  void dispose() {
    _guestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final customers = ref.watch(customerSearchProvider(_search));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EzySheetHeader(
          title: 'Cliente de la venta',
          subtitle:
              'Necesitas un cliente para dejar saldo pendiente o usar su '
              'saldo a favor.',
          trailing: EzyIconButton(
            icon: Icons.close,
            tooltip: 'Cerrar',
            onTap: () => Navigator.of(context).pop(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              _GuestOption(
                isSelected: cart.customer == null,
                controller: _guestController,
                onSelected: () {
                  controller.setGuestName(_guestController.text);
                  controller.setCustomer(null);
                  Navigator.of(context).pop();
                },
              ),
              const SizedBox(height: 12),
              EzySearchField(
                hint: 'Buscar cliente por nombre o teléfono…',
                onChanged: (value) => setState(() => _search = value.trim()),
              ),
              const SizedBox(height: 12),
              customers.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, stackTrace) => ErrorNotice(
                  message: 'No se pudieron cargar los clientes.',
                  onRetry: () =>
                      ref.invalidate(customerSearchProvider(_search)),
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const EmptyState(
                      compact: true,
                      icon: Icons.person_search_outlined,
                      title: 'Sin resultados',
                      message:
                          'No hay clientes que coincidan con la búsqueda. Prueba '
                          'con otro nombre o teléfono.',
                    );
                  }

                  return Column(
                    children: <Widget>[
                      for (final customer in page.items)
                        EzySelectableTile(
                          title: customer.displayName,
                          subtitle: customer.phone,
                          caption: <String>[
                            'Saldo ${Money.format(customer.balance)}',
                            if (customer.hasCredit)
                              'Crédito disponible '
                                  '${Money.format(customer.availableCredit)}',
                          ].join(' · '),
                          isSelected: cart.customer?.id == customer.id,
                          onTap: () {
                            controller.setCustomer(customer);
                            Navigator.of(context).pop();
                          },
                        ),
                      Text(
                        '${page.total} cliente${page.total == 1 ? '' : 's'}',
                        style: EzyTextStyles.caption.copyWith(
                          color: surfaces.textMuted,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Venta sin cliente registrado (`guest_name`).
class _GuestOption extends StatelessWidget {
  const _GuestOption({
    required this.isSelected,
    required this.controller,
    required this.onSelected,
  });

  final bool isSelected;
  final TextEditingController controller;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Público general',
      trailing: isSelected
          ? Text(
              'Seleccionado',
              style: EzyTextStyles.caption.copyWith(color: EzyColors.primary),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EzyTextField(
            label: 'Nombre para el ticket',
            hint: 'Opcional',
            controller: controller,
            maxLength: 255,
          ),
          const SizedBox(height: 12),
          EzyButton(
            label: 'Vender sin cliente',
            variant: EzyButtonVariant.text,
            onPressed: onSelected,
          ),
        ],
      ),
    );
  }
}
