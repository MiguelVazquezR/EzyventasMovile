import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/service_orders/application/service_orders_controller.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_detail.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_filters.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_mutation_results.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_summary.dart';
import 'package:ezyventas_app/features/service_orders/data/service_orders_repository.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Detalle real de `GET /service-orders/{id}` (mismo formato del contrato §9).
Map<String, dynamic> detailFixture() => <String, dynamic>{
  'id': 314,
  'folio': 'OS-014',
  'customer_name': 'Ana Ramírez',
  'customer_phone': '4771112233',
  'item_description': 'iPhone 13, pantalla rota',
  'status': 'pendiente',
  'technician_name': 'Luis Torres',
  'received_at': '2026-09-15T16:00:00.000000Z',
  'promised_at': '2026-09-20T18:00:00.000000Z',
  'subtotal': '1450.00',
  'discount_amount': '50.00',
  'final_total': '1400.00',
  'total_paid': 700.0,
  'amount_due': 700.0,
  'has_transaction': true,
  'created_at': '2026-09-15T16:00:00.000000Z',
  'customer': <String, dynamic>{
    'id': 8,
    'name': 'Ana Ramírez',
    'phone': '4771112233',
    'email': 'ana@correo.com',
    'balance': '-350.00',
  },
  'customer_email': 'ana@correo.com',
  'customer_address': <String, dynamic>{'street': 'Av. Hidalgo 120'},
  'reported_problems': 'No enciende después de una caída',
  'technician_diagnosis': 'Display dañado',
  'technician_commission_type': 'percentage',
  'technician_commission_value': '20.00',
  'discount_type': 'fixed',
  'discount_value': '50.00',
  'custom_fields': <String, dynamic>{},
  'custom_field_definitions': <Map<String, dynamic>>[],
  'items': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 903,
      'description': 'Mica templada',
      'itemable_type': r'App\Models\Product',
      'itemable_id': 78,
      'quantity': 2.0,
      'unit_price': '100.00',
      'line_total': '200.00',
    },
  ],
  'media': <String, dynamic>{
    'initial_service_order_evidence': <Map<String, dynamic>>[],
    'closing_service_order_evidence': <Map<String, dynamic>>[],
  },
  'transaction': <String, dynamic>{
    'id': 1201,
    'folio': 'OS-V-006',
    'status': 'pendiente',
    'total': 1400.0,
    'total_paid': 700.0,
    'remaining_due': 700.0,
    'payments': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 5520,
        'amount': '700.00',
        'payment_method': 'efectivo',
        'payment_date': '2026-09-15T16:10:00.000000Z',
        'bank_account': null,
      },
    ],
  },
  'activities': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 9,
      'description': 'La orden de servicio ha sido actualizada',
      'event': 'updated',
      'causer': <String, dynamic>{'id': 7, 'name': 'María López'},
      'created_at': '2026-09-16T10:00:00.000000Z',
    },
  ],
};

/// Repositorio falso de órdenes: sirve para pintar el detalle y provocar el
/// `422` del cambio de estatus sin tocar la red.
class _FakeOrdersRepository extends ServiceOrdersRepository {
  _FakeOrdersRepository({this.statusFailure})
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final ApiException? statusFailure;

  ServiceOrderSummary? lastStatusSummary;

  @override
  Future<ServiceOrderDetail> fetchServiceOrder(int serviceOrderId) async =>
      ServiceOrderDetail.fromJson(detailFixture());

  @override
  Future<Paginated<ServiceOrderSummary>> fetchServiceOrders({
    ServiceOrderFilters filters = const ServiceOrderFilters(),
    int page = 1,
    int perPage = 20,
  }) async => Paginated<ServiceOrderSummary>.fromJson(
    <String, dynamic>{
      'data': <Map<String, dynamic>>[detailFixture()],
      'current_page': 1,
      'last_page': 1,
      'per_page': perPage,
      'total': 1,
    },
    ServiceOrderSummary.fromJson,
  );

  @override
  Future<ServiceOrderStatusResult> updateStatus({
    required int serviceOrderId,
    required String status,
    String? clientUuid,
  }) async {
    final failure = statusFailure;

    if (failure != null) {
      throw failure;
    }

    lastStatusSummary = ServiceOrderSummary.fromJson(<String, dynamic>{
      ...detailFixture(),
      'status': status,
    });

    return ServiceOrderStatusResult(
      message: 'Estatus de la orden actualizado correctamente.',
      summary: lastStatusSummary!,
    );
  }
}

/// Permisos del servidor que la hoja usa para decidir qué acciones muestra.
const List<String> allOrderPermissions = <String>[
  'services.orders.access',
  'services.orders.see_details',
  'services.orders.create',
  'services.orders.edit',
  'services.orders.change_status',
  'services.orders.delete',
  'services.orders.see_customer_info',
  'services.orders.see_financial_info',
  'transactions.add_payment',
];

Widget _wrap(
  ServiceOrdersRepository repository, {
  bool withPermissions = true,
}) => ProviderScope(
  overrides: [
    serviceOrdersRepositoryProvider.overrideWithValue(repository),
    permissionsProvider.overrideWithValue(
      withPermissions
          ? PermissionsService.fromLists(
              permissions: allOrderPermissions,
              moduleKeys: const <String>['module_services'],
            )
          : const PermissionsService.empty(),
    ),
  ],
  child: MaterialApp(
    theme: EzyTheme.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () =>
                showServiceOrderDetailSheet(context, serviceOrderId: 314),
            child: const Text('Abrir detalle'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  /// Pantalla alta: la hoja del detalle entra completa y no hace falta
  /// desplazarla para comprobar todo lo que pinta.
  Future<void> useTallScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('el detalle pinta stepper, conceptos, saldo y anticipos', (
    tester,
  ) async {
    await useTallScreen(tester);
    await tester.pumpWidget(_wrap(_FakeOrdersRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir detalle'));
    await tester.pumpAndSettle();

    expect(find.text('OS-014'), findsOneWidget);
    expect(find.text('iPhone 13, pantalla rota'), findsWidgets);
    // Stepper completo (el estatus actual también sale en el badge).
    expect(find.text('PENDIENTE'), findsWidgets);
    expect(find.text('ENTREGADO'), findsOneWidget);
    expect(find.text('Display dañado'), findsOneWidget);
    // Acciones visibles con todos los permisos.
    expect(find.text('Cobrar ahora'), findsOneWidget);
    expect(find.text('Cambiar estatus'), findsOneWidget);
    expect(find.text('Editar orden'), findsOneWidget);
    expect(find.text('Eliminar orden'), findsOneWidget);
    // Conceptos, panel financiero (con utilidad) y anticipos de la venta.
    expect(find.text('Mica templada'), findsOneWidget);
    // El tipo de concepto se pinta en una etiqueta aparte (`Refacción`).
    expect(find.text('Refacción'.toUpperCase()), findsOneWidget);
    expect(find.text('Comisión del técnico'), findsOneWidget);
    expect(find.text('Utilidad neta'), findsOneWidget);
    expect(find.text('OS-V-006'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    // Historial de cambios (el título de la tarjeta va en micro-mayúsculas).
    expect(find.text('HISTORIAL'), findsOneWidget);
    expect(
      find.text('La orden de servicio ha sido actualizada'),
      findsOneWidget,
    );
  });

  testWidgets('sin permisos la hoja no ofrece ninguna acción', (tester) async {
    await useTallScreen(tester);
    await tester.pumpWidget(
      _wrap(_FakeOrdersRepository(), withPermissions: false),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir detalle'));
    await tester.pumpAndSettle();

    expect(find.text('OS-014'), findsOneWidget);
    expect(find.text('Cobrar ahora'), findsNothing);
    expect(find.text('Cambiar estatus'), findsNothing);
    expect(find.text('Editar orden'), findsNothing);
    expect(find.text('Eliminar orden'), findsNothing);
    // Sin `see_financial_info` tampoco se muestra la utilidad.
    expect(find.text('Utilidad neta'), findsNothing);
  });

  testWidgets('el 422 del estatus se muestra desde errors.status[0]', (
    tester,
  ) async {
    await useTallScreen(tester);
    await tester.pumpWidget(
      _wrap(
        _FakeOrdersRepository(
          statusFailure: ApiException.fromResponse(422, <String, dynamic>{
            'message': 'El estatus ya es el seleccionado.',
            'errors': <String, dynamic>{
              'status': <String>['El estatus ya es el seleccionado.'],
            },
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Abrir detalle'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cambiar estatus'));
    await tester.pumpAndSettle();

    // El paso actual es `pendiente`: el único paso hacia adelante natural de la
    // lista es `En progreso` (la etiqueta del stepper va en mayúsculas).
    await tester.tap(find.text('En progreso').last);
    await tester.pumpAndSettle();

    expect(find.text('El estatus ya es el seleccionado.'), findsOneWidget);
    expect(find.text('Ocultar'), findsOneWidget);
  });
}
