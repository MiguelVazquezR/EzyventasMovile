import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../catalog/presentation/widgets/product_catalog_view.dart';

/// Pestana "Vender" (POS).
///
/// En esta etapa: catalogo con busqueda, categorias, stock y promociones, con
/// detalle de producto. El carrito y el cobro llegan en la siguiente etapa.
class PointOfSaleScreen extends ConsumerWidget {
  const PointOfSaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  title: 'Tu usuario no tiene permiso para esta accion.',
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
                      'Necesitas una sesion de caja abierta para registrar ventas.',
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
                  message: 'Tu usuario no tiene permiso para esta accion.',
                  tone: EzySeverity.info,
                  icon: Icons.lock_outline,
                ),
              ),
            const Expanded(child: ProductCatalogView()),
          ],
        ),
      ),
    );
  }
}