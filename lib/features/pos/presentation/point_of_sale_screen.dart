import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../cash/application/cash_register_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/presentation/widgets/product_catalog_view.dart';
import 'widgets/cart_bar.dart';

/// Pestaña "Vender" (POS): catálogo + carrito + cobro.
///
/// El cobro exige una sesión de caja abierta: si no la hay, la barra del
/// carrito avisa y la pestaña Caja ofrece abrir el turno.
class PointOfSaleScreen extends ConsumerStatefulWidget {
  const PointOfSaleScreen({super.key});

  @override
  ConsumerState<PointOfSaleScreen> createState() => _PointOfSaleScreenState();
}

class _PointOfSaleScreenState extends ConsumerState<PointOfSaleScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver la app a primer plano se refresca el turno: si otro usuario lo
  /// cerró desde la web, el POS vuelve a la pantalla de apertura.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    ref.read(cashRegisterControllerProvider.notifier).refresh();
    ref.read(productsControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeCashSessionProvider);
    final permissions = ref.watch(permissionsProvider);

    if (!permissions.can('pos.access')) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              const AppScreenHeader(title: 'Punto de venta'),
              const Expanded(
                child: EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Tu usuario no tiene permiso para esta acción.',
                  message:
                      'Pide al administrador el permiso de acceso al punto de venta.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const AppScreenHeader(title: 'Punto de venta'),
            if (session == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: NoticeBanner(
                  message:
                      'Necesitas una sesión de caja abierta para registrar ventas.',
                  tone: EzySeverity.warn,
                  icon: Icons.warning_amber_rounded,
                  actionLabel: 'Ir a Caja',
                  onAction: () => context.go(AppTab.cashRegister.path),
                ),
              ),
            if (!permissions.can('pos.create_sale'))
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: NoticeBanner(
                  message: 'Tu usuario no tiene permiso para esta acción.',
                  tone: EzySeverity.info,
                  icon: Icons.lock_outline,
                ),
              ),
            const Expanded(child: ProductCatalogView()),
            const CartBar(),
          ],
        ),
      ),
    );
  }
}
