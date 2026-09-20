import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/account_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/cash/presentation/cash_register_screen.dart';
import '../../features/pos/presentation/point_of_sale_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/service_orders/presentation/service_order_form_screen.dart';
import '../../features/service_orders/presentation/service_orders_screen.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../auth/permissions_service.dart';

/// Rutas de la app.
///
/// El cascarón (`StatefulShellRoute.indexedStack`) mantiene el estado de cada
/// pestaña; las pestañas visibles se calculan con los permisos del servidor y un
/// acceso directo a una pestaña oculta redirige a la primera disponible (§4.1).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  final routerNotifier = ref.listen<AuthStatus>(
    authControllerProvider.select((state) => state.status),
    (previous, next) => refresh.value++,
  );

  final router = GoRouter(
    initialLocation: splashPath,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.uri.path;

      if (auth.isBootstrapping) {
        return location == splashPath ? null : splashPath;
      }

      if (!auth.isAuthenticated) {
        return location == loginPath ? null : loginPath;
      }

      final defaultPath = _defaultPath(ref);

      if (location == splashPath || location == loginPath || location == '/') {
        return defaultPath;
      }

      final tab = AppTab.fromLocation(location);
      if (tab != null && !ref.read(permissionsProvider).isTabVisible(tab)) {
        return defaultPath;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: splashPath,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: loginPath,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: serviceOrderNewPath,
        builder: (context, state) => const ServiceOrderFormScreen(),
      ),
      GoRoute(
        path: serviceOrderEditRoute,
        builder: (context, state) => ServiceOrderFormScreen(
          serviceOrderId: int.tryParse(
            state.pathParameters['serviceOrderId'] ?? '',
          ),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          _branch(AppTab.sell, const PointOfSaleScreen()),
          _branch(AppTab.serviceOrders, const ServiceOrdersScreen()),
          _branch(AppTab.cashRegister, const CashRegisterScreen()),
          _branch(AppTab.sales, const SalesScreen()),
          _branch(AppTab.account, const AccountScreen()),
        ],
      ),
    ],
  );

  ref.onDispose(() {
    routerNotifier.close();
    refresh.dispose();
    router.dispose();
  });

  return router;
});

const String splashPath = '/splash';
const String loginPath = '/login';

/// Alta de una orden (pantalla completa, fuera del cascarón de pestañas).
/// La pestaña en sí vive en `AppTab.serviceOrders.path` (`/service-orders`).
const String serviceOrderNewPath = '/service-orders/new';

/// Edición de una orden existente.
const String serviceOrderEditRoute = '/service-orders/:serviceOrderId/edit';

/// Ruta de edición de una orden concreta.
String serviceOrderEditPath(int serviceOrderId) =>
    '/service-orders/$serviceOrderId/edit';

StatefulShellBranch _branch(AppTab tab, Widget screen) {
  return StatefulShellBranch(
    routes: <RouteBase>[
      GoRoute(path: tab.path, builder: (context, state) => screen),
    ],
  );
}

/// Primera pestaña disponible; si ninguna lo está, se cae a "Cuenta".
String _defaultPath(Ref ref) =>
    ref.read(permissionsProvider).defaultTab?.path ?? AppTab.account.path;
