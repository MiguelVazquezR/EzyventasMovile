import 'package:ezyventas_app/features/home/data/models/expiring_layaway.dart';
import 'package:ezyventas_app/features/home/data/models/mobile_dashboard.dart';
import 'package:ezyventas_app/features/home/data/models/upcoming_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dashboard_fixtures.dart';

/// ¿Lanza [DashboardContractError] por el campo indicado?
Matcher contractErrorOn(String field) => throwsA(
  predicate(
    (error) => error is DashboardContractError && error.field == field,
    'error de contrato en «$field»',
  ),
);

void main() {
  group('MobileDashboard.fromJson', () {
    test('parsea el payload completo del propietario', () {
      final dashboard = MobileDashboard.fromJson(ownerDashboardJson());

      expect(dashboard.generatedAt, isNotNull);

      final sales = dashboard.sales!;
      expect(sales.todayTotal, 4820.0);
      expect(sales.todayCount, 12);
      expect(sales.averageTicket, closeTo(401.67, 0.001));
      expect(sales.yesterdayTotal, 3910.0);
      expect(sales.weeklyTrend, hasLength(7));
      expect(sales.weeklyTrend.first.day, 'lun.');
      expect(sales.weeklyTrend.first.total, 2100.0);
      expect(sales.weeklyTrend[2].hasSales, isFalse);
      expect(sales.weeklyTrend[5].hasSales, isTrue);

      expect(dashboard.layaways!.expiringCount, 2);
      expect(dashboard.orders!.upcomingDeliveriesCount, 3);
      expect(dashboard.receivables!.totalCustomerDebt, 1250.0);

      final inventory = dashboard.inventory!;
      expect(inventory.totalItems, 214);
      expect(inventory.healthyStockCount, 168);
      expect(inventory.lowStockCount, 39);
      expect(inventory.outOfStockCount, 7);
      expect(inventory.totalCost, 185400.0);
      expect(inventory.totalSaleValue, 312750.0);
      expect(inventory.lowStockProducts, hasLength(2));
      expect(inventory.lowStockProducts.first.name, 'Filtro de aceite HF-204');
      expect(inventory.lowStockProducts.first.sku, 'FLT-204');
      expect(inventory.lowStockProducts.first.currentStock, 2);
      expect(inventory.lowStockProducts.first.minStock, 5);
      expect(inventory.lowStockProducts.last.isOutOfStock, isFalse);

      expect(dashboard.serviceOrders!.total, 26);
      expect(dashboard.serviceOrders!.byStatus, hasLength(6));
      expect(dashboard.serviceOrders!.countFor('pendiente'), 4);
      expect(dashboard.serviceOrders!.countFor('entregado'), 15);
    });

    test('la sesión de caja se parsea con los tipos de §6', () {
      final cash = MobileDashboard.fromJson(ownerDashboardJson()).cashRegister;

      expect(cash.hasOpenSession, isTrue);
      expect(cash.session, isNotNull);
      expect(cash.session!.id, 41);
      expect(cash.session!.status, 'abierta');
      expect(cash.session!.openingCashBalance, 1500.0);
      expect(cash.session!.cashRegisterName, 'Caja 1');
      expect(cash.session!.opener!.name, 'José Pérez');
      // Los totales de la caja siguen siendo números, no texto decimal.
      expect(cash.session!.totals.cash, 2760.0);
      expect(cash.session!.totals.card, 800.0);
      expect(cash.session!.totals.total, 3560.0);
    });

    test('los bloques sin permiso llegan en null y no se asumen', () {
      final dashboard = MobileDashboard.fromJson(employeeDashboardJson());

      expect(dashboard.sales, isNull);
      expect(dashboard.layaways, isNull);
      expect(dashboard.orders, isNull);
      expect(dashboard.receivables, isNull);
      expect(dashboard.inventory, isNull);
      expect(dashboard.serviceOrders, isNull);
      // La caja viaja siempre: sin turno abierto, nunca `null`.
      expect(dashboard.cashRegister.hasOpenSession, isFalse);
      expect(dashboard.cashRegister.session, isNull);
    });

    test('una llave documentada ausente es error de contrato', () {
      final json = ownerDashboardJson()..remove('inventory');

      expect(() => MobileDashboard.fromJson(json), contractErrorOn('inventory'));

      final withoutCash = ownerDashboardJson()..remove('cash_register');
      expect(
        () => MobileDashboard.fromJson(withoutCash),
        contractErrorOn('cash_register'),
      );
    });

    test('una llave ausente dentro de un bloque también se reporta', () {
      final json = ownerDashboardJson();
      (json['sales']! as Map<String, dynamic>).remove('average_ticket');

      expect(
        () => MobileDashboard.fromJson(json),
        contractErrorOn('average_ticket'),
      );
    });

    test('tolera llaves desconocidas en cualquier nivel', () {
      final json = ownerDashboardJson();
      json['nuevo_bloque'] = <String, dynamic>{'x': 1};
      (json['sales']! as Map<String, dynamic>)['meta_extra'] = 'ignorado';

      expect(MobileDashboard.fromJson(json).sales!.todayTotal, 4820.0);
    });

    test('listas vacías son datos válidos, no ausencia', () {
      final json = ownerDashboardJson();
      (json['sales']! as Map<String, dynamic>)['weekly_trend'] =
          <Map<String, dynamic>>[];
      (json['inventory']! as Map<String, dynamic>)['low_stock_products'] =
          <Map<String, dynamic>>[];
      (json['service_orders']! as Map<String, dynamic>)['by_status'] =
          <String, dynamic>{};

      final dashboard = MobileDashboard.fromJson(json);

      expect(dashboard.sales!.weeklyTrend, isEmpty);
      expect(dashboard.inventory!.lowStockProducts, isEmpty);
      expect(dashboard.serviceOrders!.countFor('pendiente'), 0);
    });

    test('toJson devuelve el dinero como texto decimal', () {
      final json = MobileDashboard.fromJson(ownerDashboardJson()).toJson();

      final sales = json['sales']! as Map<String, dynamic>;
      expect(sales['today_total'], '4820.00');
      expect(sales['today_count'], 12);
      expect(sales['average_ticket'], '401.67');
      final trend = sales['weekly_trend']! as List<dynamic>;
      expect((trend.first as Map<String, dynamic>)['total'], '2100.00');
      expect(
        (json['receivables']! as Map<String, dynamic>)['total_customer_debt'],
        '1250.00',
      );

      final cash = json['cash_register']! as Map<String, dynamic>;
      final session = cash['session']! as Map<String, dynamic>;
      expect(session['opening_cash_balance'], 1500);
    });
  });

  group('ExpiringLayaway', () {
    test('parsea la ventana, las fechas y los saldos del servidor', () {
      final result = ExpiringLayawaysResult.fromJson(expiringLayawaysJson());

      expect(result.days, 3);
      expect(result.items, hasLength(2));

      final due = result.items.first;
      expect(due.id, 812);
      expect(due.folio, 'A-0142');
      expect(due.type, 'apartado');
      expect(due.status, 'apartado');
      expect(due.customerId, 57);
      expect(due.customerName, 'Ana Ramírez');
      expect(due.customerPhone, '4771112233');
      expect(due.totalAmount, 1850.0);
      expect(due.totalPaid, 500.0);
      expect(due.pendingAmount, 1350.0);
      expect(due.expirationDate, '2026-10-03');
      expect(due.daysRemaining, 0);
      expect(due.isOverdue, isFalse);
      expect(due.isDueToday, isTrue);

      final overdue = result.items.last;
      expect(overdue.type, 'credito');
      expect(overdue.status, 'pendiente');
      expect(overdue.customerPhone, isNull);
      expect(overdue.pendingAmount, 2000.0);
      expect(overdue.daysRemaining, -3);
      expect(overdue.isOverdue, isTrue);
      expect(overdue.isDueToday, isFalse);
    });

    test('una lista vacía se conserva vacía', () {
      final result = ExpiringLayawaysResult.fromJson(<String, dynamic>{
        'days': 3,
        'data': <Map<String, dynamic>>[],
      });

      expect(result.items, isEmpty);
      expect(result.days, 3);
    });
  });

  group('UpcomingDelivery', () {
    test('la fecha de entrega no se convierte a hora local', () {
      final result = UpcomingDeliveriesResult.fromJson(
        upcomingDeliveriesJson(),
      );

      expect(result.days, 3);
      expect(result.items, hasLength(2));

      final today = result.items.first;
      // El día de entrega es la parte `YYYY-MM-DD` del instante UTC: pasarlo a
      // hora local lo movería al día anterior en México.
      expect(today.deliveryDay, '2026-10-03');
      expect(today.isToday, isTrue);
      expect(today.daysRemaining, 0);
      expect(today.isOverdue, isFalse);
      expect(today.customerId, isNull);
      expect(today.customerName, 'Cliente invitado');
      expect(today.shippingAddress, isNull);
      expect(today.notes, isNull);
      expect(today.totalPaid, 0.0);
      expect(today.pendingAmount, 980.0);
      expect(today.hasPendingAmount, isTrue);

      final next = result.items.last;
      expect(next.deliveryDay, '2026-10-04');
      expect(next.daysRemaining, 1);
      expect(next.isToday, isFalse);
      expect(next.shippingAddress, 'Av. Reforma 220, col. Centro');
      expect(next.notes, 'Entregar después de las 6 pm');
      expect(next.totalPaid, 1000.0);
      expect(next.pendingAmount, 2150.0);
    });

    test('una lista vacía se conserva vacía', () {
      final result = UpcomingDeliveriesResult.fromJson(<String, dynamic>{
        'days': 3,
        'data': <Map<String, dynamic>>[],
      });

      expect(result.items, isEmpty);
      expect(result.days, 3);
    });
  });
}
