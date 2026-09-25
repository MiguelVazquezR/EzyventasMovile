import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/cash/application/cash_register_controller.dart';
import 'package:ezyventas_app/features/cash/data/cash_register_repository.dart';
import 'package:ezyventas_app/features/cash/data/models/active_cash_session.dart';
import 'package:ezyventas_app/features/cash/data/models/bank_account.dart';
import 'package:ezyventas_app/features/pos/data/models/payment_draft.dart';
import 'package:ezyventas_app/features/sales/application/sales_controller.dart';
import 'package:ezyventas_app/features/sales/data/models/refund_method.dart';
import 'package:ezyventas_app/features/sales/data/models/sales_mutation_results.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_detail.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_filters.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_summary.dart';
import 'package:ezyventas_app/features/sales/data/sales_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixtures y arnés compartidos por las pruebas de las hojas de **Ventas**
/// (no es un archivo de pruebas: no tiene `main()`).
///
/// Las etiquetas que se comprueban con estos datos son las que el recorrido del
/// teléfono (`integration_test/qa_device_test.dart`) busca dentro del detalle,
/// así que un cambio de texto aquí rompería la corrida real.

/// Detalle completo (`GET /transactions/{id}`, contrato §8): el listado más
/// ítems, pagos y desglose de saldo ya resuelto por el servidor.
///
/// [customerBalance] va como texto decimal: negativo = deuda, positivo = saldo a
/// favor del cliente (lo usan la hoja de abono y la de anulación).
Map<String, dynamic> transactionDetailFixture({
  String customerBalance = '-350.00',
  String status = 'pendiente',
  String channel = 'punto_de_venta',
  double total = 270.0,
  double paidAmount = 70.0,
  double pendingBalance = 200.0,
  bool isPaid = false,
}) => <String, dynamic>{
  'id': 987,
  'folio': 'V-014',
  'status': status,
  'channel': channel,
  'user': <String, dynamic>{'id': 7, 'name': 'María López'},
  'contact_info': null,
  'delivery_date': null,
  'layaway_expiration_date': null,
  'subtotal': '270.00',
  'total_discount': '30.00',
  'shipping_cost': '0.00',
  'total': total,
  'total_paid': paidAmount,
  'remaining_due': pendingBalance,
  'items_count': 2,
  'is_order': false,
  'invoiced': false,
  'created_at': '2026-09-18T14:35:00.000000Z',
  'branch': <String, dynamic>{'id': 2, 'name': 'Sucursal Centro'},
  'customer': <String, dynamic>{
    'id': 8,
    'name': 'Ana Ramírez',
    'balance': customerBalance,
    'credit_limit': '2000.00',
  },
  'notes': 'Entregar por la tarde',
  'shipping_address': null,
  'total_tax': '0.00',
  'paid_amount': paidAmount,
  'pending_balance': pendingBalance,
  'is_paid': isPaid,
  'invoice': null,
  'cash_register_session': <String, dynamic>{'id': 41},
  'items': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 5510,
      'description': 'Filtro de aceite',
      'itemable_type': r'App\Models\Product',
      'itemable_id': 45,
      'quantity': 2,
      'unit_price': '135.00',
      'discount_amount': '15.00',
      'discount_reason': 'Promoción de producto',
      'tax_amount': '0.00',
      'line_total': '240.00',
    },
    <String, dynamic>{
      'id': 5511,
      'description': 'Aceite 1L',
      'itemable_type': r'App\Models\Service',
      'itemable_id': 12,
      'quantity': 1.5,
      'unit_price': '80.00',
      'discount_amount': '0.00',
      'discount_reason': null,
      'tax_amount': '0.00',
      'line_total': '120.00',
    },
  ],
  'payments': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 3312,
      'amount': '70.00',
      'payment_method': 'efectivo',
      'status': 'completado',
      'payment_date': '2026-09-18T14:35:00.000000Z',
      'notes': null,
      'bank_account': null,
    },
    <String, dynamic>{
      'id': 3313,
      'amount': '150.00',
      'payment_method': 'transferencia',
      'status': 'completado',
      'payment_date': '2026-09-18T15:00:00.000000Z',
      'notes': 'Voucher 1234',
      'bank_account': <String, dynamic>{
        'id': 2,
        'name': 'Cuenta principal - BBVA (...4471)',
        'bank_name': 'BBVA',
        'account_name': 'Cuenta principal',
        'balance': '5000.00',
      },
    },
  ],
};

/// Detalle tipado de la venta de las pruebas.
TransactionDetail transactionDetail({
  String customerBalance = '-350.00',
  String status = 'pendiente',
  double total = 270.0,
  double paidAmount = 70.0,
  double pendingBalance = 200.0,
  bool isPaid = false,
}) => TransactionDetail.fromJson(
  transactionDetailFixture(
    customerBalance: customerBalance,
    status: status,
    total: total,
    paidAmount: paidAmount,
    pendingBalance: pendingBalance,
    isPaid: isPaid,
  ),
);

/// Ticket de abono tal como lo devuelve el `print.payload` del servidor.
Map<String, dynamic> abonoReceiptFixture() => <String, dynamic>{
  'type': 'abono',
  'payload': <String, dynamic>{
    'kind': 'abono',
    'scope': 'transaction',
    'businessName': 'Refaccionaria Aponte',
    'date': '18/09/2026 - 15:10',
    'customer': 'Ana Ramírez',
    'folio': 'V-014',
    'saleTotal': r'$270.00 MXN',
    'previousDue': r'$200.00 MXN',
    'abonado': r'$200.00 MXN',
    'remainingDue': r'$0.00 MXN',
    'liquidated': true,
    'paymentMethod': r'Efectivo: $200.00',
  },
  'transaction_id': 987,
  'customer_phone': '4771112233',
  'customer_id': 8,
};

/// Turno de caja abierto (`active_session` del contrato de caja).
ActiveCashSession openShift() => ActiveCashSession.fromJson(<String, dynamic>{
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
List<BankAccount> bankAccountsFixture() => <BankAccount>[
  BankAccount.fromJson(<String, dynamic>{
    'id': 2,
    'name': 'Cuenta principal - BBVA (...4471)',
    'bank_name': 'BBVA',
    'account_name': 'Cuenta principal',
    'balance': '5000.00',
  }),
];

/// Permisos del dueño sobre el historial de ventas.
const List<String> allSalesPermissions = <String>[
  'transactions.access',
  'transactions.see_details',
  'transactions.add_payment',
  'transactions.cancel',
  'transactions.refund',
  'transactions.edit_payment',
];

/// Repositorio falso del historial: sirve las fixtures y permite provocar los
/// `message` del servidor sin tocar la red.
class FakeSalesRepository extends SalesRepository {
  FakeSalesRepository({
    Map<String, dynamic>? detail,
    this.receipt,
    this.addPaymentFailure,
    this.mutationFailure,
    this.updateFailure,
    this.deleteFailure,
  }) : _detail = detail ?? transactionDetailFixture(),
       super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final Map<String, dynamic> _detail;

  /// Nodo `print` que devuelve `POST /transactions/{id}/payments` (ticket).
  Map<String, dynamic>? receipt;

  ApiException? addPaymentFailure;
  ApiException? mutationFailure;
  ApiException? updateFailure;
  ApiException? deleteFailure;

  int addPaymentCalls = 0;
  int cancelCalls = 0;
  int refundCalls = 0;
  int deleteCalls = 0;
  int updateCalls = 0;
  RefundMethod? lastRefundMethod;
  int? lastRefundBankAccountId;
  double lastPaidAmount = 0;
  bool? lastUseBalance;

  @override
  Future<TransactionDetail> fetchTransaction(int transactionId) async =>
      TransactionDetail.fromJson(_detail);

  @override
  Future<Paginated<TransactionSummary>> fetchTransactions({
    TransactionFilters filters = const TransactionFilters(),
    int page = 1,
    int perPage = 20,
  }) async => Paginated<TransactionSummary>.fromJson(<String, dynamic>{
    'data': <Map<String, dynamic>>[_detail],
    'current_page': 1,
    'last_page': 1,
    'per_page': perPage,
    'total': 1,
  }, TransactionSummary.fromJson);

  @override
  Future<AbonoResult> addPayment({
    required int transactionId,
    required int sessionId,
    bool useBalance = false,
    List<PaymentDraft> payments = const <PaymentDraft>[],
    String? clientUuid,
  }) async {
    addPaymentCalls++;
    lastUseBalance = useBalance;
    lastPaidAmount = payments.fold<double>(
      0,
      (sum, payment) => sum + payment.amount,
    );

    final failure = addPaymentFailure;
    if (failure != null) {
      throw failure;
    }

    final print = receipt;

    return AbonoResult(
      transaction: TransactionDetail.fromJson(_detail),
      receipt: print == null ? null : AbonoReceipt.fromJson(print),
    );
  }

  @override
  Future<TransactionMutationResult> cancelWithPenalty(
    int transactionId, {
    String? clientUuid,
  }) async {
    cancelCalls++;

    final failure = mutationFailure;
    if (failure != null) {
      throw failure;
    }

    return _mutation(
      'La venta fue cancelada y el monto quedó como penalización.',
    );
  }

  @override
  Future<TransactionMutationResult> refund({
    required int transactionId,
    required RefundMethod method,
    int? bankAccountId,
    String? clientUuid,
  }) async {
    refundCalls++;
    lastRefundMethod = method;
    lastRefundBankAccountId = bankAccountId;

    final failure = mutationFailure;
    if (failure != null) {
      throw failure;
    }

    return _mutation('La venta fue reembolsada al cliente.');
  }

  TransactionMutationResult _mutation(String message) =>
      TransactionMutationResult(
        transaction: TransactionDetail.fromJson(_detail),
        message: message,
      );

  @override
  Future<PaymentMutationResult> updatePayment({
    required int transactionId,
    required int paymentId,
    required double amount,
    required String paymentMethod,
    int? bankAccountId,
    String? notes,
    String? clientUuid,
  }) async {
    updateCalls++;

    final failure = updateFailure;
    if (failure != null) {
      throw failure;
    }

    return PaymentMutationResult(
      message: 'Pago actualizado correctamente.',
      payment: null,
      transaction: TransactionDetail.fromJson(_detail),
    );
  }

  @override
  Future<void> deletePayment({
    required int transactionId,
    required int paymentId,
  }) async {
    deleteCalls++;

    final failure = deleteFailure;
    if (failure != null) {
      throw failure;
    }
  }
}

/// Repositorio falso de caja: solo sirve las cuentas bancarias del selector.
class FakeCashRepository extends CashRegisterRepository {
  FakeCashRepository(this.accounts)
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final List<BankAccount> accounts;

  @override
  Future<List<BankAccount>> fetchBankAccounts() async => accounts;
}

/// Overrides comunes de las hojas de Ventas: repositorio, permisos, turno de
/// caja y cuentas bancarias.
///
/// App mínima con el botón que abre la hoja que se está probando. Los overrides
/// van literales dentro del `ProviderScope` porque Riverpod 3 no expone el tipo
/// de la lista.
Widget salesSheetApp({
  required String openLabel,
  required void Function(BuildContext context) open,
  required SalesRepository repository,
  List<String> permissions = allSalesPermissions,
  ActiveCashSession? session,
  List<BankAccount> banks = const <BankAccount>[],
}) => ProviderScope(
  overrides: [
    salesRepositoryProvider.overrideWithValue(repository),
    permissionsProvider.overrideWithValue(
      PermissionsService.fromLists(
        permissions: permissions,
        moduleKeys: const <String>['module_pos'],
      ),
    ),
    activeCashSessionProvider.overrideWithValue(session),
    cashRegisterRepositoryProvider.overrideWithValue(FakeCashRepository(banks)),
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

/// Pantalla alta: la hoja (hasta 0.96 del alto) pinta todo sin desplazarse.
Future<void> useTallScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(420, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Contenedor con los mismos overrides que [salesSheetApp], para preparar el
/// estado de los controladores antes de abrir una hoja (por ejemplo el detalle
/// ya cargado: el id de la venta vive en el controlador).
ProviderContainer salesContainer({
  required SalesRepository repository,
  List<String> permissions = allSalesPermissions,
  ActiveCashSession? session,
  List<BankAccount> banks = const <BankAccount>[],
}) => ProviderContainer(
  overrides: [
    salesRepositoryProvider.overrideWithValue(repository),
    permissionsProvider.overrideWithValue(
      PermissionsService.fromLists(
        permissions: permissions,
        moduleKeys: const <String>['module_pos'],
      ),
    ),
    activeCashSessionProvider.overrideWithValue(session),
    cashRegisterRepositoryProvider.overrideWithValue(FakeCashRepository(banks)),
  ],
);

/// Igual que [salesSheetApp] pero colgado de un contenedor propio.
Widget salesSheetAppIn({
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

/// Abre la hoja del botón [openLabel] y deja pasar la animación de entrada.
///
/// Se usa `pump` y **no** `pumpAndSettle`: el punto pulsante del estatus
/// (`_PulsingDot`) anima en bucle, así que `pumpAndSettle` nunca terminaría.
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
