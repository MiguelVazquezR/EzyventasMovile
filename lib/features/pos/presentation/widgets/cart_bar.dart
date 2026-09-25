import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_amount.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../application/cart_state.dart';
import 'cart_sheet.dart';

/// Barra inferior del POS con el resumen del carrito y el acceso al cobro (§8).
///
/// Solo aparece con el permiso `pos.create_sale`; sin sesión de caja abierta
/// avisa que hay que abrir el turno (el servidor respondería
/// `session_required`).
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final cart = ref.watch(cartControllerProvider);
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);

    if (!permissions.can('pos.create_sale')) {
      return const SizedBox.shrink();
    }

    final hasSession = session != null;
    final isEmpty = cart.isEmpty;

    return EzyActionBar(
      child: Row(
        children: <Widget>[
          _CartBadge(isEmpty: isEmpty),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => showCartSheet(context),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    hasSession ? _summary(cart) : 'Sin turno abierto',
                    style: EzyTextStyles.caption.copyWith(
                      color: hasSession
                          ? surfaces.textMuted
                          : EzyColors.warning,
                    ),
                  ),
                  const SizedBox(height: 2),
                  EzyAmount(value: cart.total, size: EzyAmountSize.large),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          EzyButton(
            label: isEmpty ? 'Carrito vacío' : 'Ver carrito',
            icon: Icons.shopping_cart_outlined,
            expand: false,
            onPressed: () => showCartSheet(context),
          ),
        ],
      ),
    );
  }

  /// `3 productos · 5 artículos`: cuántas líneas y cuántas piezas lleva el
  /// carrito (el conteo de piezas admite granel, así que se muestran los dos).
  static String _summary(CartState cart) {
    final lines = cart.lines.length;
    final products = '$lines producto${lines == 1 ? '' : 's'}';
    final items = Money.formatQuantity(cart.itemCount);
    final unit = cart.itemCount == 1 ? 'artículo' : 'artículos';

    return '$products · $items $unit';
  }
}

/// Carrito en miniatura de la barra: se enciende cuando hay algo que cobrar.
class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.isEmpty});

  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isEmpty
            ? surfaces.panelInner
            : EzyColors.primary.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(
          color: isEmpty
              ? surfaces.borderStrong
              : EzyColors.primary.withValues(alpha: 0.6),
        ),
      ),
      child: Icon(
        Icons.shopping_cart_outlined,
        size: 20,
        color: isEmpty ? surfaces.textMuted : EzyColors.primary,
      ),
    );
  }
}
