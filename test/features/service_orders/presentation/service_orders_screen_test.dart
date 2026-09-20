import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/service_orders/application/service_orders_controller.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_filters.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_summary.dart';
import 'package:ezyventas_app/features/service_orders/data/service_orders_repository.dart';
import 'package:ezyventas_app/features/service_orders/presentation/service_orders_screen.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_status_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Repositorio falso: no toca red ni almacenamiento seguro.
class _FakeServiceOrdersRepository extends ServiceOrdersRepository {
  _FakeServiceOrdersRepository({this.items = const <ServiceOrderSummary>[], this.failure})
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final List<ServiceOrderSummary> items;
  final ApiException? failure;

  ServiceOrderFilters? lastFilters;

  @override
  Future<Paginated<ServiceOrderSummary>> fetchServiceOrders({
    ServiceOrderFilters filters = const ServiceOrderFilters(),
    int page = 1,
    int perPage = 20,
  }) async {
    lastFilters = filters;

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return Paginated<ServiceOrderSummary>(
      items: items,
      currentPage: 1,
      lastPage: 1,
      perPage: perPage,
      total: items.length,
    );
  }
}

ServiceOrderSummary _order({
  int id = 314,
  String folio = 'OS-014',
  String status = 'en_progreso',
  double amountDue = 700,
}) => ServiceOrderSummary.fromJson(<String, dynamic>{
  'id': id,
  'folio': folio,
  'customer_name': 'Ana Ramírez',
  'customer_phone': '4771112233',
  'item_description': 'iPhone 13, pantalla rota',
  'status': status,
  'technician_name': 'Luis Torres',
  'received_at': '2026-09-15T16:00:00.000000Z',
  'promised_at': '2026-09-20T18:00:00.000000Z',
  'subtotal': '1450.00',
  'discount_amount': '50.00',
  'final_total': '1400.00',
  'total_paid': 1400 - amountDue,
  'amount_due': amountDue,
  'has_transaction': true,
  'created_at': '2026-09-15T16:00:00.000000Z',
});

Widget _wrap(ServiceOrdersRepository repository) => ProviderScope(
  overrides: [
    serviceOrdersRepositoryProvider.overrideWithValue(repository),
  ],
  child: MaterialApp(theme: EzyTheme.dark(), home: const ServiceOrdersScreen()),
);

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `NumberFormat`/`DateFormat` de
    // es-MX lanzan `LocaleDataException` al pintar la tarjeta.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('lista las órdenes con folio, estatus y saldo pendiente', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(_FakeServiceOrdersRepository(items: <ServiceOrderSummary>[_order()])),
    );
    await tester.pumpAndSettle();

    expect(find.text('OS-014'), findsOneWidget);
    expect(find.text('Ana Ramírez'), findsOneWidget);
    expect(find.text('iPhone 13, pantalla rota'), findsOneWidget);
    expect(find.text('EN PROGRESO'), findsOneWidget);
    expect(find.text(r'Saldo $700.00'), findsOneWidget);
    expect(find.text('1 orden en esta sucursal'), findsOneWidget);
  });

  testWidgets('estado vacío con la frase aprobada (§12)', (tester) async {
    await tester.pumpWidget(_wrap(_FakeServiceOrdersRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No hay órdenes de servicio'), findsOneWidget);
    expect(
      find.text(
        'No hay órdenes de servicio que coincidan con la búsqueda.',
      ),
      findsNothing,
      reason: 'sin filtros no se habla de búsqueda',
    );
  });

  testWidgets('muestra el message del servidor cuando falla la carga', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _FakeServiceOrdersRepository(
          failure: ApiException.fromResponse(403, <String, dynamic>{
            'message': 'Tu usuario no tiene permiso para esta acción.',
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Tu usuario no tiene permiso para esta acción.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('el stepper marca el paso actual y los cumplidos', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EzyTheme.dark(),
        home: const Scaffold(
          body: ServiceOrderStatusStepper(status: 'terminado'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Los cinco pasos del flujo, con el actual y los cumplidos a la vista.
    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('EN PROGRESO'), findsOneWidget);
    expect(find.text('ESPERANDO REFACCIÓN'), findsOneWidget);
    expect(find.text('TERMINADO'), findsOneWidget);
    expect(find.text('ENTREGADO'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(3));
  });

  testWidgets('una orden cancelada bloquea el stepper con banda roja', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EzyTheme.dark(),
        home: const Scaffold(
          body: ServiceOrderStatusStepper(status: 'cancelado'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CANCELADO'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
  });
}
