import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/module_placeholder.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/application/auth_controller.dart';

/// Pestaña "Vender" (POS).
///
/// En esta entrega muestra el estado real del turno; el catálogo, el carrito y
/// el cobro llegan en la siguiente etapa.
class PointOfSaleScreen extends ConsumerWidget {
  const PointOfSaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(authControllerProvider).context;
    final permissions = ref.watch(permissionsProvider);

    if (accessContext == null) {
      return const Scaffold(
        body: EmptyState(title: 'No hay una sesión iniciada.'),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const AppScreenHeader(title: 'Punto de venta'),
            Expanded(
              child: ModulePlaceholder(
                icon: Icons.shopping_cart_outlined,
                title: 'Vender',
                description:
                    'Aquí se arma la venta: catálogo con búsqueda, carrito, '
                    'cliente, cobro mixto, apartados y pedidos. Los precios, el '
                    'stock y el cambio los calcula el servidor.',
                upcoming: <String>[
                  'Catálogo con categorías, variantes, promociones y stock por sucursal.',
                  'Carrito con descuento por línea y alta rápida de cliente.',
                  'Cobro en efectivo, tarjeta, transferencia y saldo a favor, con cambio.',
                  'Apartados y pedidos/comandas con fecha límite y de entrega.',
                ],
                footer: _SellStatus(
                  hasSession: accessContext.hasActiveSession,
                  canCreateSale: permissions.can('pos.create_sale'),
                  onOpenCashRegister: () =>
                      context.go(AppTab.cashRegister.path),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado del turno y del permiso de venta.
class _SellStatus extends StatelessWidget {
  const _SellStatus({
    required this.hasSession,
    required this.canCreateSale,
    required this.onOpenCashRegister,
  });

  final bool hasSession;
  final bool canCreateSale;
  final VoidCallback onOpenCashRegister;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Estado para vender',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (hasSession)
            const NoticeBanner(
              message: 'Turno de caja abierto: puedes vender.',
              tone: EzySeverity.success,
              icon: Icons.check_circle_outline,
            )
          else
            NoticeBanner(
              message:
                  'Necesitas una sesión de caja abierta para registrar ventas.',
              tone: EzySeverity.warn,
              icon: Icons.warning_amber_rounded,
              actionLabel: 'Ir a Caja',
              onAction: onOpenCashRegister,
            ),
          if (!canCreateSale) ...<Widget>[
            const SizedBox(height: 12),
            const NoticeBanner(
              message: 'Tu usuario no tiene permiso para esta acción.',
              tone: EzySeverity.info,
              icon: Icons.lock_outline,
            ),
          ],
        ],
      ),
    );
  }
}
