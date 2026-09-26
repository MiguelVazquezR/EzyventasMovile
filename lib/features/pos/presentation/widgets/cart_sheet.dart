import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permissions_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_amount.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_list_tile.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../application/cart_state.dart';
import 'cart_line_tile.dart';
import 'cart_summary.dart';
import 'customer_picker_sheet.dart';
import 'payment_sheet.dart';
import 'sale_result_view.dart';
import 'store_order_sheet.dart';

/// Abre el carrito del POS (líneas, cliente, totales y acciones de cobro).
Future<void> showCartSheet(BuildContext context) {
  return EzyBottomSheet.show<void>(
    context,
    maxHeightFactor: 0.96,
    builder: (sheetContext) => const CartSheet(),
  );
}

/// Carrito dentro de la hoja estándar: cabecera, líneas con scroll y el CTA de
/// cobro **fijo** al pie (§7.6).
class CartSheet extends ConsumerWidget {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final result = cart.result;

    if (result != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: <Widget>[
          SaleResultView(
            result: result,
            onDone: () {
              controller.consumeResult();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EzySheetHeader(
          title: 'Carrito',
          subtitle: cartSummaryLabel(cart),
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
              _CartTotalBand(cart: cart),
              const SizedBox(height: 12),
              const _CustomerRow(),
              const SizedBox(height: 16),
              Text(
                'PRODUCTOS',
                style: EzyTextStyles.cardTitle.copyWith(
                  color: context.surfaces.textBody,
                ),
              ),
              const SizedBox(height: 12),
              for (final line in cart.lines) CartLineTile(line: line),
              if (cart.isEmpty)
                const EmptyState(
                  compact: true,
                  icon: Icons.shopping_cart_outlined,
                  title: 'El carrito está vacío',
                  message:
                      'Agrega productos desde el catálogo para empezar la '
                      'venta.',
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
              const SizedBox(height: 8),
              EzyButton(
                label: 'Vaciar carrito',
                variant: EzyButtonVariant.text,
                onPressed: cart.isEmpty ? null : () => controller.clear(),
              ),
            ],
          ),
        ),
        // El cobro no se busca bajando: vive fijo al pie de la hoja.
        EzyActionBar(child: const _CheckoutSection()),
      ],
    );
  }
}

/// Franja del total: el monto que se va a cobrar, arriba y en el cuerpo del
/// panel, para no tener que bajar hasta el final del carrito.
class _CartTotalBand extends StatelessWidget {
  const _CartTotalBand({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaces.border),
      ),
      child: EzyAmount(
        value: cart.total,
        label: 'Total a cobrar',
        size: EzyAmountSize.hero,
      ),
    );
  }
}

/// Cliente de la venta (o público general con nombre opcional).
///
/// Es una **fila** del design system (`EzyListTile`) y no una card con título y
/// botón «Cambiar»: la fila entera abre el selector, que es una hoja inferior
/// que se arrastra hacia abajo para cerrarla —el gesto de las secciones de
/// Mercado Pago—, así que el chevron ya dice que se abre (§10).
class _CustomerRow extends ConsumerWidget {
  const _CustomerRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final customer = cart.customer;
    final guestName = cart.guestName.trim();

    final subtitle = customer != null
        ? <String>[
            'Saldo ${Money.format(customer.balance)}',
            if (customer.hasCredit)
              'Crédito ${Money.format(customer.availableCredit)}',
          ].join(' · ')
        : (guestName.isEmpty
              ? 'Toca para elegir un cliente.'
              : 'Público general · Toca para cambiar.');

    return EzyListTile(
      icon: Icons.person_outline,
      title: customer?.displayName ??
          (guestName.isEmpty ? 'Público general' : guestName),
      subtitle: subtitle,
      showDivider: false,
      onTap: () => showCustomerPickerSheet(context),
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
///
/// Las tres comparten una fila de 48 px y ninguna lleva icono (§8: `Cobrar` se
/// distingue por el naranja de la marca, no por el alto), para que el carrito
/// tenga el máximo de alto útil.
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
            message:
                'Necesitas una sesión de caja abierta para registrar ventas.',
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
            onPressed: null,
          ),
        ],
      );
    }

    final enabled = !cart.isEmpty && !cart.isSubmitting;

    // Las tres acciones caben en **una sola fila** de 48 px (sin icono): el pie
    // de la hoja le deja así unos 64 px más de alto al contenido del carrito.
    // `Cobrar` sigue siendo la acción primaria, pero por color (§1.1).
    return Row(
      children: <Widget>[
        Expanded(
          child: EzyButton(
            label: 'Cobrar',
            isLoading: cart.isSubmitting,
            onPressed: enabled
                ? () => showPaymentSheet(context, mode: PaymentMode.checkout)
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: EzyButton(
            label: 'Apartar',
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
            variant: EzyButtonVariant.outline,
            onPressed: enabled ? () => showStoreOrderSheet(context) : null,
          ),
        ),
      ],
    );
  }
}
