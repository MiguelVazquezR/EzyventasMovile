import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermisosService.visibleTabs', () {
    test('propietario con POS y órdenes ve las cinco pestañas', () {
      const service = PermissionsService.empty();
      final owner = PermissionsService.fromLists(
        permissions: <String>[
          'pos.access',
          'pos.create_sale',
          'transactions.access',
          'services.orders.access',
        ],
        moduleKeys: <String>['module_pos', 'module_services'],
      );

      expect(owner.visibleTabs, AppTab.values);
      expect(owner.defaultTab, AppTab.sell);
      expect(service.visibleTabs, <AppTab>[AppTab.account]);
    });

    test('empleado limitado: solo POS, caja y ventas', () {
      final employee = PermissionsService.fromLists(
        permissions: <String>['pos.access', 'transactions.access'],
        moduleKeys: <String>['module_pos'],
      );

      expect(employee.visibleTabs, <AppTab>[
        AppTab.sell,
        AppTab.cashRegister,
        AppTab.sales,
        AppTab.account,
      ]);
      expect(employee.isTabVisible(AppTab.serviceOrders), isFalse);
      expect(employee.can('services.orders.access'), isFalse);
    });

    test('técnico sin POS: solo órdenes y cuenta', () {
      final technician = PermissionsService.fromLists(
        permissions: <String>['services.orders.access'],
        moduleKeys: <String>['module_services'],
      );

      expect(technician.visibleTabs, <AppTab>[
        AppTab.serviceOrders,
        AppTab.account,
      ]);
    });

    test('un permiso de un módulo no contratado no habilita su pestaña', () {
      // La suscripción no tiene `module_services`, así que la pestaña Órdenes
      // queda oculta aunque el permiso venga en la lista (el servidor filtra,
      // la app se protege igual).
      final employee = PermissionsService.fromLists(
        permissions: <String>['services.orders.access', 'pos.access'],
        moduleKeys: <String>[],
      );

      expect(employee.isTabVisible(AppTab.serviceOrders), isFalse);
      expect(employee.isTabVisible(AppTab.sell), isFalse);
      // §4.1: la pestaña Caja solo depende de `pos.access`.
      expect(employee.visibleTabs, <AppTab>[
        AppTab.cashRegister,
        AppTab.account,
      ]);
    });

    test('suscripción vencida (sin permisos ni módulos): solo cuenta', () {
      const expired = PermissionsService.empty();

      expect(expired.visibleTabs, <AppTab>[AppTab.account]);
      expect(expired.can('pos.access'), isFalse);
      expect(expired.hasModule('module_pos'), isFalse);
    });
  });

  group('PermissionsService helpers', () {
    final service = PermissionsService.fromLists(
      permissions: <String>[
        'pos.access',
        'pos.create_sale',
        'pos.edit_prices',
        'system.branches.switch',
      ],
      moduleKeys: <String>['module_pos'],
    );

    test('can / canAny / canAll', () {
      expect(service.can('pos.access'), isTrue);
      expect(service.can('pos.cancel_sale'), isFalse);
      expect(service.canAny(<String>['pos.cancel_sale', 'pos.access']), isTrue);
      expect(service.canAll(<String>['pos.access', 'pos.create_sale']), isTrue);
      expect(service.canAll(<String>['pos.access', 'pos.cancel_sale']), isFalse);
    });

    test('hasModule', () {
      expect(service.hasModule('module_pos'), isTrue);
      expect(service.hasModule('module_services'), isFalse);
    });
  });

  group('AppTab.fromLocation', () {
    test('reconoce la pestaña y sus subrutas', () {
      expect(AppTab.fromLocation('/sell'), AppTab.sell);
      expect(AppTab.fromLocation('/account/profile'), AppTab.account);
      expect(AppTab.fromLocation('/service-orders/12'), AppTab.serviceOrders);
    });

    test('devuelve null fuera del cascarón', () {
      expect(AppTab.fromLocation('/login'), isNull);
      expect(AppTab.fromLocation('/splash'), isNull);
    });
  });
}
