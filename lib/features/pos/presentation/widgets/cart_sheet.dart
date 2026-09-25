import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permissions_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../application/cart_state.dart';
import 'cart_line_tile.dart';
import 'customer_picker_sheet.dart';
import 'payment_sheet.dart';
import 'sale_result_view.dart';
import 'store_order_sheet.dart';

/// Abre el carrito del POS (líneas, cliente, totales y acciones de cobro).
Future<void> showCartSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const CartSheet(),
  );
}

/// Carrito a pantalla completa dentro de un bottom sheet.
class CartSheet extends ConsumerWidget {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final result = cart.result;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          if (result != null) ...<Widget>[
            const SizedBox(height: 8),
            SaleResultView(
              result: result,
              onDone: () {
                controller.consumeResult();
                Navigator.of(context).pop();
              },
            ),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            _CartHeader(cart: cart),
            const SizedBox(height: 12),
            _CartTotalBand(cart: cart),
            const SizedBox(height: 16),
            const _CustomerCard(),
            const SizedBox(height: 8),
            Text(
              'PRODUCTOS',
              style: EzyTextStyles.cardTitle.copyWith(
                color: context.surfaces.textBody,
              ),
            ),
            const SizedBox(height: 12),
            for (final line in cart.lines) CartLineTile(line: line),
            if (cart.isEmpty)
              Text(
                'Agrega productos desde el catálogo para empezar la venta.',
                style: EzyTextStyles.body.copyWith(
                  color: context.surfaces.textSecondary,
                ),
              ),
            if (cart.notice != null) ...<Widget>[
              const SizedBox(height: 12),
              NoticeBanner(
                message: cart.notice!,
                tone: EzySeverity.warn,
                actionLabel: 'Ocultar',
                onAction: controller.consumeNotice,
              ),
            ],
            const SizedBox(height: 12),
            _TotalsCard(cart: cart),
            const SizedBox(height: 16),
            const _CheckoutSection(),
            const SizedBox(height: 8),
            EzyButton(
              label: 'Vaciar carrito',
              variant: EzyButtonVariant.text,
              onPressed: cart.isEmpty ? null : () => controller.clear(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Encabezado del carrito con el número de productos.
class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final products = cart.lines.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Carrito',
          style: EzyTextStyles.screenTitle.copyWith(
            color: surfaces.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$products producto${products == 1 ? '' : 's'} · '
          '${Money.formatQuantity(cart.itemCount)} artículos',
          style: EzyTextStyles.secondary.copyWith(
            color: surfaces.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Franja del total: el monto que se va a cobrar, arriba y en el color de la
/// marca (para no tener que bajar hasta el final del carrito).
class _CartTotalBand extends StatelessWidget {
  const _CartTotalBand({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: EzyColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EzyColors.primary.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.shopping_bag_outlined,
            size: 20,
            color: EzyColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Total a cobrar',
              style: EzyTextStyles.bodyStrong.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
          ),
          Text(
            Money.format(cart.total),
            style: EzyTextStyles.moneyMedium.copyWith(
              color: EzyColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cliente de la venta (o público general con nombre opcional).
class _CustomerCard extends ConsumerWidget {
  const _CustomerCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);

    return SectionCard(
      title: 'Cliente',
      trailing: TextButton(
        onPressed: () => showCustomerPickerSheet(context),
        child: const Text('Cambiar'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            cart.customer?.displayName ??
                (cart.guestName.trim().isEmpty
                    ? 'Público general'
                    : cart.guestName.trim()),
            style: EzyTextStyles.bodyStrong.copyWith(
              color: context.surfaces.textPrimary,
            ),
          ),
          if (cart.customer != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              <String>[
                'Saldo ${Money.format(cart.customer!.balance)}',
                if (cart.customer!.hasCredit)
                  'Crédito ${Money.format(cart.customer!.availableCredit)}',
              ].join(' · '),
              style: EzyTextStyles.caption.copyWith(
                color: context.surfaces.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Totales del carrito (subtotal, descuento y total).
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Totales',
      child: Column(
        children: <Widget>[
          SectionRow(label: 'Subtotal', value: Money.format(cart.subtotal)),
          if (cart.totalDiscount != 0)
            SectionRow(
              label: 'Descuento',
              value: '-${Money.format(cart.totalDiscount)}',
              valueStyle: EzyTextStyles.moneyList.copyWith(
                color: StatusPalette.text(context, EzySeverity.success),
              ),
            ),
          const Divider(height: 24),
          SectionRow(
            label: 'Total',
            value: Money.format(cart.total),
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

/// Acciones de cobro: venta, apartado y pedido.
///
/// Sin sesión de caja abierta el servidor responde `session_required`, así que
/// la app bloquea los botones y lleva al flujo de apertura.
class _CheckoutSection extends ConsumerWidget {
  const _CheckoutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);
    final canSell = permissions.can('pos.create_sale');

    if (!canSell) {
      return const NoticeBanner(
        message: 'Tu usuario no tiene permiso para esta acción.',
        tone: EzySeverity.info,
      );
    }

    if (session == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NoticeBanner(
            message: 'Necesitas una sesión de caja abierta para registrar ventas.',
            tone: EzySeverity.warn,
            actionLabel: 'Ir a Caja',
            onAction: () {
              Navigator.of(context).pop();
              context.go(AppTab.cashRegister.path);
            },
          ),
          const SizedBox(height: 12),
          EzyButton(
            label: 'Cobrar',
            icon: Icons.payments_outlined,
            height: 56,
            onPressed: null,
          ),
        ],
      );
    }

    final enabled = !cart.isEmpty && !cart.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EzyButton(
          label: 'Cobrar',
          icon: Icons.payments_outlined,
          isLoading: cart.isSubmitting,
          // El cobro es la acción principal: botón más alto y en el naranja de
          // la marca.
          height: 56,
          onPressed: enabled
              ? () => showPaymentSheet(context, mode: PaymentMode.checkout)
              : null,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: EzyButton(
                label: 'Apartar',
                icon: Icons.bookmark_add_outlined,
                // Azul: deja el producto reservado sin cobrarlo.
                variant: EzyButtonVariant.info,
                onPressed: enabled
                    ? () => showPaymentSheet(context, mode: PaymentMode.layaway)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: EzyButton(
                label: 'Pedido',
                icon: Icons.local_shipping_outlined,
                variant: EzyButtonVariant.outline,
                onPressed: enabled
                    ? () => showStoreOrderSheet(context)
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
