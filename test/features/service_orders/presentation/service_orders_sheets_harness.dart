import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/utils/evidence_image.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/cash/application/cash_register_controller.dart';
import 'package:ezyventas_app/features/cash/data/cash_register_repository.dart';
import 'package:ezyventas_app/features/cash/data/models/active_cash_session.dart';
import 'package:ezyventas_app/features/cash/data/models/bank_account.dart';
import 'package:ezyventas_app/features/pos/data/models/payment_draft.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_detail.dart';
import 'package:ezyventas_app/features/service_orders/application/service_orders_controller.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_detail.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_filters.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_mutation_results.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_summary.dart';
import 'package:ezyventas_app/features/service_orders/data/service_orders_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures y arnés compartidos por las pruebas de las hojas de **Órdenes de
/// servicio** (no es un archivo de pruebas: no tiene `main()`).
///
/// Las etiquetas que se comprueban con estos datos son las que el recorrido del
/// teléfono (`integration_test/qa_device_test.dart`) busca dentro del detalle
/// (cabecera con folio y `Cerrar`, panel de impresión con `Imprimir orden`), así
/// que un cambio de texto aquí rompería la corrida real.

/// Detalle real de `GET /service-orders/{id}` (contrato §9).
///
/// [customerBalance] va como texto decimal: negativo = deuda, positivo = saldo a
/// favor del cliente (lo usa la hoja de anticipo para ofrecer `use_balance`).
Map<String, dynamic> orderDetailFixture({
  String status = 'pendiente',
  String customerBalance = '-350.00',
  bool hasTransaction = true,
  double paidAmount = 700.0,
  double amountDue = 700.0,
}) => <String, dynamic>{
  'id': 314,
  'folio': 'OS-014',
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
  'total_paid': paidAmount,
  'amount_due': amountDue,
  'has_transaction': hasTransaction,
  'created_at': '2026-09-15T16:00:00.000000Z',
  'customer': <String, dynamic>{
    'id': 8,
    'name': 'Ana Ramírez',
    'phone': '4771112233',
    'email': 'ana@correo.com',
    'balance': customerBalance,
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
  'transaction': hasTransaction
      ? <String, dynamic>{
          'id': 1201,
          'folio': 'OS-V-006',
          'status': 'pendiente',
          'total': 1400.0,
          'total_paid': paidAmount,
          'remaining_due': amountDue,
          'payments': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 5520,
              'amount': '700.00',
              'payment_method': 'efectivo',
              'payment_date': '2026-09-15T16:10:00.000000Z',
              'bank_account': null,
            },
          ],
        }
      : null,
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

/// Detalle de una orden **antigua**: sin venta vinculada (`transaction: null`),
/// que es el caso que exige `POST /service-orders/{id}/ensure-transaction`.
Map<String, dynamic> legacyOrderDetailFixture() => <String, dynamic>{
  ...orderDetailFixture(),
  'has_transaction': false,
  'transaction': null,
};

/// `transaction` del detalle, ya tipado (lo devuelve el anticipo).
TransactionDetail orderTransactionFixture() =>
    TransactionDetail.fromJson(<String, dynamic>{
      'id': 1201,
      'folio': 'OS-V-006',
      'status': 'pendiente',
      'channel': 'punto_de_venta',
      'subtotal': 1400.0,
      'total_discount': 50.0,
      'shipping_cost': 0.0,
      'total': 1400.0,
      'total_paid': 700.0,
      'remaining_due': 700.0,
      'items_count': 1,
      'is_order': false,
      'invoiced': false,
      'created_at': '2026-09-15T16:00:00.000000Z',
      'items': <Map<String, dynamic>>[],
      'paid_amount': 700.0,
      'pending_balance': 700.0,
      'is_paid': false,
    });

/// Repositorio falso de órdenes: sirve el detalle y deja provocar el fallo de
/// cada acción sin tocar la red.
class FakeServiceOrdersRepository extends ServiceOrdersRepository {
  FakeServiceOrdersRepository({
    this.statusFailure,
    this.paymentFailure,
    this.diagnosisFailure,
    this.deleteFailure,
    bool isLegacy = false,
    String status = 'pendiente',
    String customerBalance = '-350.00',
  }) : _json = isLegacy
           ? legacyOrderDetailFixture()
           : orderDetailFixture(
               status: status,
               customerBalance: customerBalance,
             ),
       super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final Map<String, dynamic> _json;
  final ApiException? statusFailure;
  final ApiException? paymentFailure;
  final ApiException? diagnosisFailure;
  final ApiException? deleteFailure;

  int statusCalls = 0;
  int paymentCalls = 0;
  int diagnosisCalls = 0;
  int deleteCalls = 0;
  int ensureCalls = 0;

  String? lastStatus;
  String? lastDiagnosis;
  int? lastSessionId;
  bool? lastUseBalance;
  List<PaymentDraft> lastPayments = const <PaymentDraft>[];
  ServiceOrderFilters? lastFilters;

  ServiceOrderDetail get detail => ServiceOrderDetail.fromJson(_json);

  @override
  Future<ServiceOrderDetail> fetchServiceOrder(int serviceOrderId) async =>
      detail;

  @override
  Future<Paginated<ServiceOrderSummary>> fetchServiceOrders({
    ServiceOrderFilters filters = const ServiceOrderFilters(),
    int page = 1,
    int perPage = 20,
  }) async {
    lastFilters = filters;

    return Paginated<ServiceOrderSummary>.fromJson(<String, dynamic>{
      'data': <Map<String, dynamic>>[_json],
      'current_page': 1,
      'last_page': 1,
      'per_page': perPage,
      'total': 1,
    }, ServiceOrderSummary.fromJson);
  }

  @override
  Future<ServiceOrderStatusResult> updateStatus({
    required int serviceOrderId,
    required String status,
    String? clientUuid,
  }) async {
    statusCalls++;
    lastStatus = status;

    final failure = statusFailure;
    if (failure != null) {
      throw failure;
    }

    return ServiceOrderStatusResult(
      message: 'Estatus de la orden actualizado correctamente.',
      summary: ServiceOrderSummary.fromJson(<String, dynamic>{
        ..._json,
        'status': status,
      }),
    );
  }

  @override
  Future<ServiceOrderMutationResult> saveDiagnosis({
    required int serviceOrderId,
    String? diagnosis,
    List<EvidenceImage> images = const <EvidenceImage>[],
  }) async {
    diagnosisCalls++;
    lastDiagnosis = diagnosis;

    final failure = diagnosisFailure;
    if (failure != null) {
      throw failure;
    }

    return ServiceOrderMutationResult(
      message: 'Diagnóstico y evidencias guardados correctamente.',
      detail: detail,
    );
  }

  @override
  Future<ServiceOrderPaymentResult> addPayment({
    required int serviceOrderId,
    required int sessionId,
    bool useBalance = false,
    List<PaymentDraft> payments = const <PaymentDraft>[],
    String? clientUuid,
  }) async {
    paymentCalls++;
    lastSessionId = sessionId;
    lastUseBalance = useBalance;
    lastPayments = payments;

    final failure = paymentFailure;
    if (failure != null) {
      throw failure;
    }

    return ServiceOrderPaymentResult(
      detail: detail,
      transaction: orderTransactionFixture(),
      receipt: null,
    );
  }

  @override
  Future<int> ensureTransaction(int serviceOrderId) async {
    ensureCalls++;

    return 1201;
  }

  @override
  Future<void> deleteServiceOrder(int serviceOrderId) async {
    deleteCalls++;

    final failure = deleteFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

/// Permisos que el servidor entrega al módulo de órdenes (los que la hoja usa
/// para decidir qué acciones muestra).
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

/// Turno de caja abierto (`active_session` del contrato de caja): sin él la
/// orden no puede recibir anticipos.
ActiveCashSession openOrderShift() =>
    ActiveCashSession.fromJson(<String, dynamic>{
      'id': 41,
      'status': 'abierta',
      'opened_at': '2026-09-18T13:00:00-06:00',
      'opening_cash_balance': 500,
      'totals': <String, dynamic>{
        'cash': 0,
        'card': 0,
        'transfer': 0,
        'balance': 0,
      },
    });

/// Cuenta bancaria del negocio (`GET /bank-accounts`).
List<BankAccount> orderBankAccounts() => <BankAccount>[
  BankAccount.fromJson(<String, dynamic>{
    'id': 2,
    'name': 'Cuenta principal - BBVA (...4471)',
    'bank_name': 'BBVA',
    'account_name': 'Cuenta principal',
    'balance': '5000.00',
  }),
];

/// Repositorio falso de caja: solo sirve las cuentas bancarias del selector.
class FakeOrderCashRepository extends CashRegisterRepository {
  FakeOrderCashRepository(this.accounts)
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final List<BankAccount> accounts;

  @override
  Future<List<BankAccount>> fetchBankAccounts() async => accounts;
}

/// Overrides comunes de las hojas de Órdenes: repositorio, permisos, turno de
/// caja y cuentas bancarias.
///
/// App mínima con el botón que abre la hoja que se está probando. Los overrides
/// van literales dentro del `ProviderScope` porque Riverpod 3 no expone el tipo
/// de la lista.
Widget serviceOrdersSheetApp({
  required String openLabel,
  required void Function(BuildContext context) open,
  required ServiceOrdersRepository repository,
  List<String> permissions = allOrderPermissions,
  ActiveCashSession? session,
  List<BankAccount> banks = const <BankAccount>[],
}) => ProviderScope(
  overrides: [
    serviceOrdersRepositoryProvider.overrideWithValue(repository),
    permissionsProvider.overrideWithValue(
      PermissionsService.fromLists(
        permissions: permissions,
        moduleKeys: const <String>['module_services'],
      ),
    ),
    activeCashSessionProvider.overrideWithValue(session),
    cashRegisterRepositoryProvider.overrideWithValue(
      FakeOrderCashRepository(banks),
    ),
  ],
  child: MaterialApp(
    theme: EzyTheme.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => open(context),
            child: Text(openLabel),
          ),
        ),
      ),
    ),
  ),
);

/// Contenedor con los mismos overrides que [serviceOrdersSheetApp], para
/// preparar el estado del controlador antes de abrir una hoja: el detalle
/// cargado, porque las hojas de estatus, anticipo y diagnóstico trabajan sobre
/// el id que vive en el controlador.
ProviderContainer serviceOrdersContainer({
  required ServiceOrdersRepository repository,
  List<String> permissions = allOrderPermissions,
  ActiveCashSession? session,
  List<BankAccount> banks = const <BankAccount>[],
}) => ProviderContainer(
  overrides: [
    serviceOrdersRepositoryProvider.overrideWithValue(repository),
    permissionsProvider.overrideWithValue(
      PermissionsService.fromLists(
        permissions: permissions,
        moduleKeys: const <String>['module_services'],
      ),
    ),
    activeCashSessionProvider.overrideWithValue(session),
    cashRegisterRepositoryProvider.overrideWithValue(
      FakeOrderCashRepository(banks),
    ),
  ],
);

/// Igual que [serviceOrdersSheetApp] pero colgado de un contenedor propio.
Widget serviceOrdersSheetAppIn({
  required ProviderContainer container,
  required String openLabel,
  required void Function(BuildContext context) open,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    theme: EzyTheme.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => open(context),
            child: Text(openLabel),
          ),
        ),
      ),
    ),
  ),
);

/// Pantalla alta: las hojas (hasta 0.96 del alto) pintan todo sin desplazarse.
///
/// El detalle de una orden es la hoja más larga del módulo (cabecera, stepper,
/// acciones, cliente, conceptos, importes, anticipos, evidencias e historial),
/// así que necesita más alto que las hojas de Ventas: si no cabe, el `ListView`
/// deja sin construir las últimas tarjetas y la prueba no las ve.
Future<void> useTallScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(440, 4400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Abre la hoja del botón [openLabel] y deja pasar la animación de entrada.
///
/// Se usa `pump` y **no** `pumpAndSettle`: el punto pulsante del estatus
/// (`en_progreso`) anima en bucle, así que `pumpAndSettle` nunca terminaría.
Future<void> openSheet(WidgetTester tester, String openLabel) async {
  await tester.tap(find.text(openLabel));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Deja pasar la animación de una acción posterior (cierre, cambio de estado).
Future<void> settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
