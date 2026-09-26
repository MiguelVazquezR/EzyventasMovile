import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_drawer_scope.dart';
import '../../../core/widgets/empty_state.dart';
import '../../account/application/account_providers.dart';
import '../../auth/application/auth_controller.dart';
import 'widgets/app_drawer.dart';

/// Cascarón de navegación: menú lateral (`EzyAppDrawer`) sobre el índice de
/// pestañas del `StatefulShellRoute`.
///
/// Desde que la navegación vive en el menú lateral **no hay barra inferior** ni
/// FAB global: el catálogo del POS y los listados ganan el alto de la barra y del
/// botón, y las pestañas que antes no cabían (Vender y Caja) dejan de ser un caso
/// aparte, porque están en el mismo panel que las demás.
///
/// Cada pestaña monta su **propio** `Scaffold` (el POS cuelga del pie la barra
/// del carrito), así que el `Drawer` es de **este** `Scaffold` y se abre por
/// `AppDrawerScope`: la hamburguesa de las cabeceras llama al cascarón, no al
/// `Scaffold` de dentro, que no tiene menú.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  /// `Scaffold` del cascarón: es el dueño del `Drawer`.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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

  /// Al volver la app a primer plano se vuelven a pedir los contadores de la
  /// campana: el apartado que vence o el pedido que entra mientras el teléfono
  /// está guardado no se verían hasta reiniciar la app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    ref.read(notificationsControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(visibleTabsProvider);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const EzyAppDrawer(),
      body: AppDrawerScope(
        openDrawer: _openDrawer,
        child: SafeArea(
          bottom: false,
          child: tabs.isEmpty
              // Sin módulos contratados no hay pestaña que mostrar, pero el menú
              // sigue ahí: es la única forma de llegar a Cuenta para ver qué
              // falta.
              ? const EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Tu suscripción no tiene módulos activos.',
                  message:
                      'Contacta al administrador para renovar el plan. Puedes '
                      'seguir entrando a «Cuenta» para revisar tu información.',
                )
              : widget.navigationShell,
        ),
      ),
    );
  }

  /// Abre el menú lateral; lo llama la hamburguesa de las cabeceras.
  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();
}

