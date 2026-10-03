import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/router/app_router.dart';
import 'package:ezyventas_app/features/home/data/dashboard_repository.dart';
import 'package:ezyventas_app/features/home/presentation/expiring_layaways_screen.dart';
import 'package:ezyventas_app/features/home/presentation/home_screen.dart';
import 'package:ezyventas_app/features/home/presentation/upcoming_deliveries_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../data/dashboard_fixtures.dart';
import 'home_harness.dart';

void main() {
  setUpAll(() async {
    // La cabecera pinta la hora del «Actualizado …» con el formato del design
    // system (§10), que necesita los datos de locale de es_MX.
    Intl.defaultLocale = 'es_MX';
    await initializeDateFormatting('es_MX');
  });

  testWidgets('el propietario ve todas las tarjetas del inicio', (tester) async {
    await pumpDashboardScreen(
      tester,
      repository: FakeDashboardRepository(),
      screen: const HomeScreen(),
    );

    // Venta de hoy con el ticket promedio y el cierre de ayer.
    expect(find.text('VENTA DE HOY'), findsOneWidget);
    expect(find.text(r'$4,820.00 MXN'), findsOneWidget);
    expect(find.text('12 ventas'), findsOneWidget);
    expect(find.text(r'Ticket promedio $401.67'), findsOneWidget);
    expect(find.text('Ayer'), findsOneWidget);

    // Tendencia semanal: los 7 días del servidor.
    expect(find.text('TENDENCIA SEMANAL'), findsOneWidget);
    expect(find.text('lun.'), findsOneWidget);
    expect(find.text('dom.'), findsOneWidget);

    // Alertas: los cuatro bloques con permiso.
    expect(find.text('Apartados por vencer'), findsOneWidget);
    expect(find.text('Vencidos o en 3 días'), findsOneWidget);
    expect(find.text('Pedidos por entregar'), findsOneWidget);
    expect(find.text('Saldo por cobrar'), findsOneWidget);
    expect(find.text(r'$1,250.00'), findsOneWidget);
    expect(find.text('Stock crítico'), findsOneWidget);

    // Inventario, órdenes de servicio y caja.
    expect(find.text('INVENTARIO'), findsOneWidget);
    expect(find.text('214 artículos con stock'), findsOneWidget);
    expect(find.text('Filtro de aceite HF-204'), findsOneWidget);
    expect(find.text('2 de 5'), findsOneWidget);
    expect(find.text('ÓRDENES DE SERVICIO'), findsOneWidget);
    expect(find.text('CAJA'), findsOneWidget);
    expect(find.text('TURNO ABIERTO'), findsOneWidget);
    expect(find.text('Caja 1'), findsOneWidget);
    expect(find.text('Ver caja'), findsOneWidget);
  });

  testWidgets('los bloques en null no dibujan tarjeta (sin permiso)', (
    tester,
  ) async {
    await pumpDashboardScreen(
      tester,
      repository: FakeDashboardRepository(
        dashboard: employeeDashboardJson(),
      ),
      screen: const HomeScreen(),
    );

    expect(find.text('VENTA DE HOY'), findsNothing);
    expect(find.text('TENDENCIA SEMANAL'), findsNothing);
    expect(find.text('Apartados por vencer'), findsNothing);
    expect(find.text('Pedidos por entregar'), findsNothing);
    expect(find.text('Saldo por cobrar'), findsNothing);
    expect(find.text('Stock crítico'), findsNothing);
    expect(find.text('INVENTARIO'), findsNothing);
    expect(find.text('ÓRDENES DE SERVICIO'), findsNothing);

    // El turno de caja viaja siempre: sin sesión la barra cambia a «Abrir caja».
    expect(find.text('CAJA'), findsOneWidget);
    expect(find.text('SIN TURNO ABIERTO'), findsOneWidget);
    expect(find.text('Abrir caja'), findsOneWidget);
  });

  testWidgets('un cero real sí dibuja la tarjeta', (tester) async {
    final json = ownerDashboardJson();
    (json['layaways']! as Map<String, dynamic>)['expiring_count'] = 0;
    (json['inventory']! as Map<String, dynamic>)['low_stock_products'] =
        <Map<String, dynamic>>[];

    await pumpDashboardScreen(
      tester,
      repository: FakeDashboardRepository(dashboard: json),
      screen: const HomeScreen(),
    );

    // `0` y una lista vacía son datos: la tarjeta se dibuja igual.
    expect(find.text('Apartados por vencer'), findsOneWidget);
    expect(find.text('Ningún artículo por debajo del mínimo.'), findsOneWidget);
  });

  testWidgets('un error de red se muestra con «Reintentar» y se recupera', (
    tester,
  ) async {
    final repository = FakeDashboardRepository(failure: ApiException.network());

    await pumpDashboardScreen(
      tester,
      repository: repository,
      screen: const HomeScreen(),
    );

    expect(
      find.textContaining('No pudimos conectar con el servidor'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('VENTA DE HOY'), findsNothing);

    repository.failure = null;
    await tester.tap(find.text('Reintentar'));
    await pumpFrames(tester);

    expect(find.text('VENTA DE HOY'), findsOneWidget);
    expect(repository.dashboardCalls, 2);
  });

  testWidgets('pull-to-refresh vuelve a pedir GET /dashboard', (tester) async {
    final repository = FakeDashboardRepository();

    await pumpDashboardScreen(
      tester,
      repository: repository,
      screen: const HomeScreen(),
      // Pantalla de teléfono: la lista es desplazable y el gesto tiene
      // sobretirón real.
      surfaceSize: const Size(420, 800),
    );
    expect(repository.dashboardCalls, 1);

    await tester.fling(find.text('VENTA DE HOY'), const Offset(0, 320), 1000);
    await pumpFrames(tester, frames: 15);

    expect(repository.dashboardCalls, 2);
  });

  testWidgets('la tarjeta de apartados abre su listado con 3 días', (
    tester,
  ) async {
    final repository = FakeDashboardRepository();
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: expiringLayawaysPath,
          builder: (context, state) => const ExpiringLayawaysScreen(),
        ),
        GoRoute(
          path: upcomingDeliveriesPath,
          builder: (context, state) => const UpcomingDeliveriesScreen(),
        ),
      ],
    );

    await pumpDashboardScreen(tester, repository: repository, router: router);

    await tester.tap(find.text('Apartados por vencer'));
    await pumpFrames(tester);

    expect(find.text('Apartados y créditos'), findsOneWidget);
    expect(find.text('Ana Ramírez'), findsOneWidget);
    expect(repository.requestedExpiringDays, <int>[dashboardDefaultDays]);

    router.dispose();
  });
}
