import 'package:flutter/material.dart';

/// Pestañas del cascarón de navegación (§4.1 del documento maestro).
///
/// Cada pestaña declara la condición exacta que la hace visible: módulo
/// contratado (`module_keys`) **y** permiso efectivo del servidor.
enum AppTab {
  sell(
    path: '/sell',
    label: 'Vender',
    icon: Icons.shopping_cart_outlined,
    activeIcon: Icons.shopping_cart,
    moduleKey: 'module_pos',
    permission: 'pos.access',
  ),
  serviceOrders(
    path: '/service-orders',
    label: 'Órdenes',
    icon: Icons.build_outlined,
    activeIcon: Icons.build,
    moduleKey: 'module_services',
    permission: 'services.orders.access',
  ),
  cashRegister(
    path: '/cash-register',
    label: 'Caja',
    icon: Icons.account_balance_outlined,
    activeIcon: Icons.account_balance,
    moduleKey: null,
    permission: 'pos.access',
  ),
  sales(
    path: '/sales',
    label: 'Ventas',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
    moduleKey: null,
    permission: 'transactions.access',
  ),
  account(
    path: '/account',
    label: 'Cuenta',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    moduleKey: null,
    permission: null,
  );

  const AppTab({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.moduleKey,
    required this.permission,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Módulo que debe estar contratado (`null` = no requiere módulo).
  final String? moduleKey;

  /// Permiso requerido (`null` = siempre visible).
  final String? permission;

  bool get isAlwaysVisible => moduleKey == null && permission == null;

  /// Pestaña solicitada por una ruta, si corresponde a alguna.
  static AppTab? fromLocation(String location) {
    for (final tab in AppTab.values) {
      if (location == tab.path || location.startsWith('${tab.path}/')) {
        return tab;
      }
    }

    return null;
  }
}

/// Consulta de permisos y módulos que el servidor entregó en `login` / `me`.
///
/// La app **oculta** lo que el usuario no puede hacer; el servidor siempre
/// revalida. Aquí no se codifica ningún rol.
class PermissionsService {
  const PermissionsService({
    required this.permissions,
    required this.moduleKeys,
  });

  const PermissionsService.empty()
    : permissions = const <String>{},
      moduleKeys = const <String>{};

  final Set<String> permissions;
  final Set<String> moduleKeys;

  factory PermissionsService.fromLists({
    required List<String> permissions,
    required List<String> moduleKeys,
  }) => PermissionsService(
    permissions: permissions.toSet(),
    moduleKeys: moduleKeys.toSet(),
  );

  /// `true` si el permiso efectivo está en la lista del servidor.
  bool can(String permission) => permissions.contains(permission);

  bool canAny(Iterable<String> candidates) =>
      candidates.any(permissions.contains);

  bool canAll(Iterable<String> candidates) =>
      candidates.every(permissions.contains);

  /// `true` si el negocio contrató el módulo (`module_pos`, `module_services`).
  bool hasModule(String moduleKey) => moduleKeys.contains(moduleKey);

  /// Pestañas visibles para este usuario, en orden.
  List<AppTab> get visibleTabs => AppTab.values.where(isTabVisible).toList(
    growable: false,
  );

  bool isTabVisible(AppTab tab) {
    if (tab.isAlwaysVisible) {
      return true;
    }

    if (tab.moduleKey != null && !hasModule(tab.moduleKey!)) {
      return false;
    }

    final permission = tab.permission;

    return permission == null || can(permission);
  }

  /// Primera pestaña disponible (destino por defecto tras el login).
  AppTab? get defaultTab {
    final tabs = visibleTabs;

    return tabs.isEmpty ? null : tabs.first;
  }
}
