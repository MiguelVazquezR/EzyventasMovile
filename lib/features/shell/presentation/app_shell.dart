import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../auth/application/auth_controller.dart';

/// Cascarón de navegación: barra inferior persistente cuyas pestañas dependen de
/// los módulos contratados y de los permisos reales del servidor (§4.1).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final tabs = ref.watch(visibleTabsProvider);
    final location = GoRouterState.of(context).uri.path;

    if (tabs.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.lock_outline,
            title: 'Tu suscripción no tiene módulos activos.',
            message:
                'Contacta al administrador para renovar el plan. Puedes seguir '
                'entrando a «Cuenta» para revisar tu información.',
          ),
        ),
      );
    }

    final currentTab = AppTab.fromLocation(location) ?? tabs.first;
    final selectedIndex = tabs.contains(currentTab)
        ? tabs.indexOf(currentTab)
        : 0;

    // Con una sola pestaña disponible la barra inferior no aporta nada.
    if (tabs.length == 1) {
      return Scaffold(body: SafeArea(bottom: false, child: navigationShell));
    }

    return Scaffold(
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaces.panel,
          border: Border(top: BorderSide(color: surfaces.border)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            final tab = tabs[index];
            navigationShell.goBranch(AppTab.values.indexOf(tab));
          },
          destinations: <Widget>[
            for (final tab in tabs)
              NavigationDestination(
                icon: _DestinationIcon(tab: tab, isActive: false),
                selectedIcon: _DestinationIcon(tab: tab, isActive: true),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Icono de la pestaña; añade el punto pulsante de "turno abierto" en Caja.
class _DestinationIcon extends ConsumerWidget {
  const _DestinationIcon({required this.tab, required this.isActive});

  final AppTab tab;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = Icon(isActive ? tab.activeIcon : tab.icon);

    if (tab != AppTab.cashRegister) {
      return icon;
    }

    final hasSession = ref.watch(
      authControllerProvider.select((state) => state.context?.hasActiveSession ?? false),
    );

    if (!hasSession) {
      return icon;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        icon,
        Positioned(
          right: -2,
          top: -1,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: EzyColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
