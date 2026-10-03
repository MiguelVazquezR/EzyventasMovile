import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/features/home/presentation/expiring_layaways_screen.dart';
import 'package:ezyventas_app/features/home/presentation/upcoming_deliveries_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'home_harness.dart';

void main() {
  setUpAll(() async {
    // Las fechas de las filas se pintan con el formato del design system (§10).
    Intl.defaultLocale = 'es_MX';
    await initializeDateFormatting('es_MX');
  });

  group('ExpiringLayawaysScreen', () {
    testWidgets('pinta las filas con los días que calculó el servidor', (
      tester,
    ) async {
      await pumpDashboardScreen(
        tester,
        repository: FakeDashboardRepository(),
        screen: const ExpiringLayawaysScreen(),
      );

      expect(find.text('Apartados y créditos'), findsOneWidget);
      expect(find.text('Próximos 3 días'), findsOneWidget);

      // Vence hoy: fecha local del servidor, saldos en texto decimal.
      expect(find.text('VENCE HOY'), findsOneWidget);
      expect(find.text('Ana Ramírez'), findsOneWidget);
      expect(find.textContaining('Apartado · Vence 3 oct 2026'), findsOneWidget);
      expect(find.textContaining('4771112233'), findsOneWidget);
      expect(find.text(r'$1,350.00'), findsOneWidget);

      // Vencida: se marca con los días que trae `days_remaining`.
      expect(find.text('VENCIDO HACE 3 DÍAS'), findsOneWidget);
      expect(find.text('Refaccionaria del Valle'), findsOneWidget);
      expect(find.textContaining('Crédito · Vence'), findsOneWidget);
      expect(find.text(r'$2,000.00'), findsOneWidget);
    });

    testWidgets('sin filas muestra el estado vacío', (tester) async {
      await pumpDashboardScreen(
        tester,
        repository: FakeDashboardRepository(
          expiringRows: <Map<String, dynamic>>[],
        ),
        screen: const ExpiringLayawaysScreen(),
      );

      expect(find.text('Nada por vencer'), findsOneWidget);
      expect(
        find.textContaining('No hay apartados ni créditos por vencer'),
        findsOneWidget,
      );
      expect(find.text('Ana Ramírez'), findsNothing);
    });

    testWidgets('el 403 del servidor se muestra tal cual con reintentar', (
      tester,
    ) async {
      await pumpDashboardScreen(
        tester,
        repository: FakeDashboardRepository(
          failure: const ApiException(
            message: 'Tu usuario no tiene permiso para esta acción.',
            statusCode: 403,
          ),
        ),
        screen: const ExpiringLayawaysScreen(),
      );

      expect(
        find.text('Tu usuario no tiene permiso para esta acción.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('el filtro vuelve a pedir el listado con los días elegidos', (
      tester,
    ) async {
      final repository = FakeDashboardRepository();

      await pumpDashboardScreen(
        tester,
        repository: repository,
        screen: const ExpiringLayawaysScreen(),
      );
      expect(repository.requestedExpiringDays, <int>[3]);

      await tester.tap(find.text('7 días'));
      await tester.pumpAndSettle();

      expect(repository.requestedExpiringDays, <int>[3, 7]);
      expect(find.text('Próximos 7 días'), findsOneWidget);
    });
  });

  group('UpcomingDeliveriesScreen', () {
    testWidgets('pinta las entregas sin convertir la fecha a hora local', (
      tester,
    ) async {
      await pumpDashboardScreen(
        tester,
        repository: FakeDashboardRepository(),
        screen: const UpcomingDeliveriesScreen(),
      );

      expect(find.text('Pedidos por entregar'), findsOneWidget);
      expect(find.text('Próximos 3 días'), findsOneWidget);

      // `2026-10-03T00:00:00Z` se pinta como 3 de octubre: el día del negocio.
      expect(find.text('ENTREGA HOY'), findsOneWidget);
      expect(find.text('Cliente invitado'), findsOneWidget);
      expect(find.textContaining('Entrega 3 oct 2026'), findsOneWidget);
      expect(find.text(r'$980.00'), findsNWidgets(2));

      expect(find.text('ENTREGA MAÑANA'), findsOneWidget);
      expect(find.text('Ana Ramírez'), findsOneWidget);
      expect(find.textContaining('Entrega 4 oct 2026'), findsOneWidget);
      expect(
        find.textContaining('Dirección: Av. Reforma 220, col. Centro'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Nota: Entregar después de las 6 pm'),
        findsOneWidget,
      );
      // Se cobra lo pendiente, no el total.
      expect(find.text(r'$2,150.00'), findsOneWidget);
    });

    testWidgets('sin filas muestra el estado vacío', (tester) async {
      await pumpDashboardScreen(
        tester,
        repository: FakeDashboardRepository(
          deliveryRows: <Map<String, dynamic>>[],
        ),
        screen: const UpcomingDeliveriesScreen(),
      );

      expect(find.text('Ninguna entrega pendiente'), findsOneWidget);
      expect(
        find.textContaining('No hay entregas vencidas ni programadas'),
        findsOneWidget,
      );
      expect(find.text('Cliente invitado'), findsNothing);
    });
  });
}
