import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_chip.dart';
import 'package:ezyventas_app/core/widgets/ezy_search_field.dart';
import 'package:ezyventas_app/features/service_orders/application/service_orders_controller.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_filters_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'service_orders_sheets_harness.dart';

/// Barra de filtros del listado de órdenes, montada sobre una app mínima.
///
/// Pantalla ancha: los chips de estatus viven en una lista horizontal y el
/// `ListView` solo construye los visibles (en un teléfono, «Terminado» queda
/// fuera hasta desplazarla).
Future<FakeServiceOrdersRepository> pumpFiltersBar(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final orders = FakeServiceOrdersRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [serviceOrdersRepositoryProvider.overrideWithValue(orders)],
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: const Scaffold(body: ServiceOrderFiltersBar()),
      ),
    ),
  );

  await tester.pump();
  await tester.pump();

  return orders;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la búsqueda y los chips son del design system', (tester) async {
    await pumpFiltersBar(tester);

    final search = tester.widget<EzySearchField>(find.byType(EzySearchField));
    expect(search.hint, 'Buscar por folio, cliente o equipo…');

    // Los seis estatus del contrato y el chip del orden (sin filtros no hay
    // «Limpiar filtros»).
    expect(find.byType(EzyChip), findsNWidgets(7));
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('En progreso'), findsOneWidget);
    expect(find.text('Esperando refacción'), findsOneWidget);
    expect(find.text('Terminado'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    expect(find.text('Cancelado'), findsOneWidget);
    expect(find.text('Más recientes'), findsOneWidget);
    expect(find.text('Limpiar filtros'), findsNothing);
  });

  testWidgets('elegir un estatus filtra en el servidor y se puede soltar', (
    tester,
  ) async {
    final orders = await pumpFiltersBar(tester);

    await tester.tap(find.text('Terminado'));
    await settleSheet(tester);

    expect(orders.lastFilters?.status, 'terminado');
    expect(find.text('Limpiar filtros'), findsOneWidget);

    // Volver a tocar el mismo chip lo quita.
    await tester.tap(find.text('Terminado'));
    await settleSheet(tester);

    expect(orders.lastFilters?.status, isNull);
    expect(find.text('Limpiar filtros'), findsNothing);
  });

  testWidgets('limpiar filtros los quita todos', (tester) async {
    final orders = await pumpFiltersBar(tester);

    await tester.tap(find.text('Pendiente'));
    await settleSheet(tester);
    expect(orders.lastFilters?.hasFilters, isTrue);

    await tester.tap(find.text('Limpiar filtros'));
    await settleSheet(tester);

    expect(orders.lastFilters?.hasFilters, isFalse);
    expect(orders.lastFilters?.search, '');
    expect(find.text('Limpiar filtros'), findsNothing);
  });
}
