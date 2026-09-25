import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../customers/application/customers_providers.dart';
import '../../../customers/data/models/customer.dart';
import '../../application/cart_controller.dart';

/// Selector de cliente del cobro (`GET /customers`).
///
/// Guarda la elección en el carrito; "Público general" lo deja sin cliente y
/// permite capturar un nombre para el ticket (`guest_name`).
Future<void> showCustomerPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
            'Cliente de la venta',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Necesitas un cliente para dejar saldo pendiente o usar su saldo '
            'a favor.',
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
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
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (error, stackTrace) => const ErrorNotice(
              message: 'No se pudieron cargar los clientes.',
            ),
            data: (page) {
              if (page.items.isEmpty) {
                return Text(
                  'Sin resultados.',
                  style: EzyTextStyles.body.copyWith(
                    color: surfaces.textSecondary,
                  ),
                );
              }

              return Column(
                children: <Widget>[
                  for (final customer in page.items)
                    _CustomerTile(
                      customer: customer,
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
          TextButton(
            onPressed: onSelected,
            child: const Text('Vender sin cliente'),
          ),
        ],
      ),
    );
  }
}

/// Cliente de la lista con su saldo y crédito disponible.
class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.isSelected,
    required this.onTap,
  });

  final Customer customer;
  final bool isSelected;
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
          color: isSelected
              ? EzyColors.primary.withValues(alpha: 0.12)
              : surfaces.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? EzyColors.primary.withValues(alpha: 0.5)
                : surfaces.border,
          ),
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
