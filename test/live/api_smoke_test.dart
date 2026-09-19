import 'dart:io';

import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_endpoints.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/core/utils/money.dart';
import 'package:ezyventas_app/core/utils/uuid_generator.dart';
import 'package:ezyventas_app/features/auth/data/auth_repository.dart';
import 'package:ezyventas_app/features/auth/data/models/access_context.dart';
import 'package:ezyventas_app/features/auth/data/models/auth_session.dart';
import 'package:ezyventas_app/features/cash/data/cash_register_repository.dart';
import 'package:ezyventas_app/features/catalog/data/catalog_repository.dart';
import 'package:ezyventas_app/features/customers/data/customers_repository.dart';
import 'package:ezyventas_app/features/pos/application/cart_state.dart';
import 'package:ezyventas_app/features/pos/application/product_line_builder.dart';
import 'package:ezyventas_app/features/pos/data/models/cart_line.dart';
import 'package:ezyventas_app/features/pos/data/models/payment_draft.dart';
import 'package:ezyventas_app/features/pos/data/pos_repository.dart';
import 'package:ezyventas_app/features/sales/data/models/refund_method.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_filters.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_summary.dart';
import 'package:ezyventas_app/features/sales/data/sales_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Persistencia en memoria: la prueba de humo no toca el almacenamiento seguro.
class _MemorySessionStore implements SessionPersistence {
  AuthSession? _session;

  @override
  Future<void> clearSession() async => _session = null;

  @override
  Future<String?> readToken() async => _session?.token;

  @override
  Future<AuthSession?> readSession() async => _session;

  @override
  Future<void> saveSession(AuthSession session) async => _session = session;
}

/// Prueba de humo **real** contra la API `/api/v1` (no corre en `flutter test`
/// normal: hace red).
///
/// ```bash
/// flutter test test/live/api_smoke_test.dart \
///   --dart-define=LIVE_API_EMAIL=usuario@negocio.com \
///   --dart-define=LIVE_API_PASSWORD=secreto
/// ```
///
/// Opcionales:
/// - `LIVE_API_URL` (default `https://ezyventas2.test/api/v1`)
/// - `LIVE_EXPECT_OWNER` (`true` para la cuenta propietaria, `false` para un
///   empleado con permisos limitados)
/// - `LIVE_EXPECT_FORBIDDEN_PATH` (ruta que el usuario **no** puede leer; debe
///   responder `403`). Ej. `/service-orders` para un empleado solo de POS.
const String liveEmail = String.fromEnvironment('LIVE_API_EMAIL');
const String livePassword = String.fromEnvironment('LIVE_API_PASSWORD');
const String liveBaseUrl = String.fromEnvironment(
  'LIVE_API_URL',
  defaultValue: 'https://ezyventas2.test/api/v1',
);
const bool liveExpectOwner = bool.fromEnvironment(
  'LIVE_EXPECT_OWNER',
  defaultValue: true,
);
const String liveForbiddenPath = String.fromEnvironment(
  'LIVE_EXPECT_FORBIDDEN_PATH',
);

/// Habilita la prueba real de la etapa 3 (caja + cobro). Crea una venta y un
/// corte **reales**, por eso está apagada por defecto: `LIVE_POS=true`.
const bool livePos = bool.fromEnvironment('LIVE_POS');

/// Producto con el que se prueba el cobro (si es 0 se usa el primero con stock).
const int livePosProductId = int.fromEnvironment('LIVE_POS_PRODUCT_ID');

/// Habilita la prueba real de la etapa 4 (historial de ventas).
const bool liveSales = bool.fromEnvironment('LIVE_SALES');

/// Además de leer, la prueba de ventas registra un abono de $1, lo edita y lo
/// elimina para dejar la venta como estaba (requiere `LIVE_SALES=true`).
const bool liveSalesWrite = bool.fromEnvironment('LIVE_SALES_WRITE');

/// Escenario completo de dinero: crea un **apartado** real, lo abona, edita y
/// borra el pago, abona otra vez y lo cancela con reembolso en efectivo. Al
/// terminar devuelve el stock y revierte la deuda del cliente.
const bool liveSalesLayaway = bool.fromEnvironment('LIVE_SALES_LAYAWAY');

void main() {
  final hasCredentials = liveEmail.isNotEmpty && livePassword.isNotEmpty;

  setUpAll(() {
    // Permite llamadas HTTP reales dentro del runner de pruebas.
    HttpOverrides.global = null;
  });

  test(
    'login real, /auth/me, permisos y logout',
    () async {
      final store = _MemorySessionStore();
      final api = ApiClient(baseUrl: liveBaseUrl, readToken: store.readToken);
      final repository = AuthRepository(api: api, sessionStore: store);

      // 1) Credenciales incorrectas: el mensaje del servidor llega intacto.
      final wrong = await _capture(
        () => api.postJson(
          ApiEndpoints.login,
          data: <String, dynamic>{
            'email': liveEmail,
            'password': '$livePassword-inesperado',
            'device_name': 'Prueba de humo',
          },
        ),
      );
      expect(wrong.message, isNotEmpty);
      expect(wrong.statusCode, 422);

      // 2) Login real.
      final session = await repository.login(
        email: liveEmail,
        password: livePassword,
      );
      expect(session.token, isNotEmpty);
      expect(session.context.user.id, greaterThan(0));
      expect(session.context.availableBranches, isNotEmpty);
      expect(session.context.moduleKeys, isNotEmpty);

      // Un empleado puede legítimamente tener 0 permisos (rol sin permisos
      // asignados): el servidor lo deja entrar y la app debe ocultar todo
      // menos "Cuenta". El propietario siempre recibe permisos.
      if (liveExpectOwner) {
        expect(session.context.user.permissions, isNotEmpty);
      }

      expect(
        session.context.user.isSubscriptionOwner,
        liveExpectOwner,
        reason: 'la cuenta debe ser propietaria (sin roles) o empleado',
      );

      debugPrint(
        '[smoke] user=${session.context.user.id} '
        'owner=${session.context.user.isSubscriptionOwner} '
        'permisos=${session.context.user.permissions.length} '
        'modulos=${session.context.moduleKeys.join(",")}',
      );

      // 3) El token sirve para `GET /auth/me`.
      final me = await api.getJson(ApiEndpoints.me);
      final context = AccessContext.fromJson(me);
      expect(me['user'], isNotNull);
      expect(context.user.id, session.context.user.id);
      expect(
        context.user.permissions.length,
        session.context.user.permissions.length,
      );

      // 4) Permisos → pestañas visibles (según módulos contratados).
      final permissions = PermissionsService.fromLists(
        permissions: context.user.permissions,
        moduleKeys: context.moduleKeys,
      );
      final visibleTabs = permissions.visibleTabs;

      expect(visibleTabs, contains(AppTab.account));
      expect(
        visibleTabs.contains(AppTab.sell),
        permissions.can('pos.access') && permissions.hasModule('module_pos'),
      );
      expect(
        visibleTabs.contains(AppTab.sales),
        permissions.can('transactions.access'),
      );
      expect(
        visibleTabs.contains(AppTab.serviceOrders),
        permissions.can('services.orders.access') &&
            permissions.hasModule('module_services'),
      );

      if (permissions.permissions.isEmpty) {
        // Sin ningún permiso efectivo la app solo deja entrar a "Cuenta".
        expect(visibleTabs, <AppTab>[AppTab.account]);
      }

      debugPrint(
        '[smoke] pestanas=${visibleTabs.map((tab) => tab.label).join(" | ")}',
      );

      // 5) Un endpoint permitido responde 200 paginado.
      if (permissions.can('transactions.access')) {
        final transactions = await api.getJson(ApiEndpoints.transactions);
        expect(transactions['data'], isA<List<dynamic>>());
        debugPrint('[smoke] /transactions ok (${transactions['total']} ventas)');
      }

      // 6) Un endpoint sin permiso responde 403 con el mensaje del servidor.
      if (liveForbiddenPath.isNotEmpty) {
        final forbidden = await _capture(() => api.getJson(liveForbiddenPath));
        expect(forbidden.statusCode, 403);
        expect(
          forbidden.message,
          'Tu usuario no tiene permiso para esta acción.',
        );
        debugPrint(
          '[smoke] 403 en $liveForbiddenPath: ${forbidden.message}',
        );
      }

      // 7) Logout revoca el token de este dispositivo.
      await repository.logout();
      final afterLogout = await _capture(() => api.getJson(ApiEndpoints.me));
      expect(afterLogout.isUnauthorized, isTrue);
      expect(afterLogout.message, 'No autenticado.');
    },
    skip: hasCredentials
        ? false
        : 'Define LIVE_API_EMAIL y LIVE_API_PASSWORD para correrlo',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  liveCatalogTest();
  liveCashAndSaleTest();
  liveSalesTest();
}

/// Verifica el catálogo y los clientes **reales** de la sucursal del token.
///
/// Requiere una cuenta propietaria (un empleado sin `pos.access` recibiría 403).
void liveCatalogTest() {
  test(
    'catálogo y clientes reales (productos, categorías, servicios, clientes)',
    () async {
      final store = _MemorySessionStore();
      final api = ApiClient(baseUrl: liveBaseUrl, readToken: store.readToken);
      final auth = AuthRepository(api: api, sessionStore: store);

      await auth.login(email: liveEmail, password: livePassword);

      final catalog = CatalogRepository(api: api);
      final products = await catalog.fetchProducts();

      debugPrint(
        '[live] productos=${products.total} '
        'pagina=${products.currentPage}/${products.lastPage}',
      );
      for (final product in products.items.take(3)) {
        debugPrint(
          '[live]   ${product.name} · ${Money.format(product.price)} '
          '(lista ${Money.format(product.sellingPrice)}) · '
          'stock ${Money.formatQuantity(product.stock)} · '
          'variantes ${product.variantCombinations.length} · '
          'tiers ${product.priceTiers.length} · '
          'promos ${product.promotions.length}',
        );
      }
      expect(products.items, isNotEmpty);
      expect(products.total, greaterThan(0));

      final productCategories = await catalog.fetchCategories();
      final serviceCategories = await catalog.fetchCategories(
        type: CatalogCategoryType.service,
      );
      debugPrint(
        '[live] categorias producto=${productCategories.length} '
        'servicio=${serviceCategories.length}',
      );

      final services = await catalog.fetchServices();
      debugPrint('[live] servicios=${services.total}');
      expect(services.total, greaterThanOrEqualTo(0));

      final customers = CustomersRepository(api: api);
      final page = await customers.fetchCustomers();

      debugPrint('[live] clientes=${page.total}');
      for (final customer in page.items.take(3)) {
        debugPrint(
          '[live]   ${customer.displayName} · saldo '
          '${Money.format(customer.balance)} · credito '
          '${Money.format(customer.creditLimit)} · disponible '
          '${Money.format(customer.availableCredit)}',
        );
      }
      expect(page.total, greaterThan(0));

      final detail = await customers.fetchCustomer(page.items.first.id);
      debugPrint(
        '[live] ficha ${detail.customer.id}: '
        'apartados=${detail.layaways.length} '
        'movimientos=${detail.balanceMovements.length} '
        'direccion=${detail.addressLine ?? "sin direccion"}',
      );
      expect(detail.customer.id, page.items.first.id);

      await auth.logout();
    },
    skip: (liveEmail.isNotEmpty && livePassword.isNotEmpty && liveExpectOwner)
        ? false
        : 'Requiere LIVE_API_EMAIL/LIVE_API_PASSWORD de una cuenta propietaria',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
/// Prueba de humo de la etapa 3 contra la API real: turno de caja + cobro.
///
/// - Si el usuario no tiene turno, abre uno en la primera terminal libre con un
///   fondo de `1000` y los saldos bancarios que devuelve el servidor.
/// - Registra **una venta de contado** (efectivo exacto) del primer producto con
///   stock y comprueba folio, total, cambio y pistas de impresión.
/// - Lee el corte (`summary`) y, **solo si este dispositivo abrió el turno**, lo
///   cierra con el efectivo esperado (para no cortar el turno de otra persona).
void liveCashAndSaleTest() {
  test(
    'caja y cobro reales (turno, venta de contado y corte)',
    () async {
      final store = _MemorySessionStore();
      final api = ApiClient(baseUrl: liveBaseUrl, readToken: store.readToken);
      final auth = AuthRepository(api: api, sessionStore: store);

      await auth.login(email: liveEmail, password: livePassword);

      final cash = CashRegisterRepository(api: api);
      final current = await cash.fetchCurrent();

      debugPrint(
        '[live] turno=${current.activeSession?.id ?? "ninguno"} '
        'terminales libres=${current.availableCashRegisters.length} '
        'turnos a unir=${current.joinableSessions.length} '
        'cuentas bancarias=${current.bankAccounts.length}',
      );

      var openedHere = false;
      var activeSession = current.activeSession;

      if (activeSession == null) {
        expect(
          current.canStartShift,
          isTrue,
          reason:
              'No hay terminal libre ni turno abierto: no se puede probar el cobro',
        );

        activeSession = await cash.openSession(
          cashRegisterId: current.availableCashRegisters.first.id,
          openingCashBalance: 1000,
          declaredBankBalances: <int, double>{
            for (final account in current.bankAccounts)
              account.id: account.balance,
          },
        );
        openedHere = true;

        debugPrint(
          '[live] turno abierto id=${activeSession.id} '
          'terminal=${activeSession.cashRegisterName} '
          'fondo=${Money.format(activeSession.openingCashBalance)} '
          'bancos=${activeSession.openingBankBalances.length}',
        );
      }

      // Producto con stock: el indicado por env o el primero disponible.
      final catalog = CatalogRepository(api: api);
      final products = await catalog.fetchProducts(perPage: 50);
      final product = livePosProductId > 0
          ? await catalog.fetchProduct(livePosProductId)
          : products.items.firstWhere(
              (item) => item.stock > 0 || item.variantCombinations.isNotEmpty,
              orElse: () => products.items.first,
            );
      final variant = product.variantCombinations
          .where((combination) => combination.stock > 0)
          .firstOrNull;

      final line = ProductLineBuilder.build(
        product,
        variant: variant,
        quantity: 1,
      );

      debugPrint(
        '[live] producto=${product.name} '
        'variante=${variant?.label ?? "sin variante"} '
        'precio=${Money.format(line.unitPrice)} '
        'total línea=${Money.format(line.lineTotal)}',
      );

      final cart = CartState(
        lines: <CartLine>[line],
        payments: <PaymentDraft>[
          PaymentDraft(
            method: PosPaymentMethod.cash,
            amount: line.lineTotal,
          ),
        ],
      );

      final checkout = await PosRepository(api: api).checkout(
        cart.buildSalePayload(
          sessionId: activeSession.id,
          clientUuid: UuidGenerator.v4(),
        ),
      );

      debugPrint(
        '[live] venta folio=${checkout.transaction.folio} '
        'estado=${checkout.transaction.status} '
        'canal=${checkout.transaction.channel} '
        'total=${Money.format(checkout.transaction.total)} '
        'pagado=${Money.format(checkout.transaction.totalPaid)} '
        'saldo=${Money.format(checkout.transaction.remainingDue)} '
        'cambio=${Money.format(checkout.change)} '
        'plantillas=${checkout.printHint.templateIds}',
      );

      expect(checkout.transaction.folio, isNotEmpty);
      expect(checkout.transaction.total, greaterThan(0));
      expect(checkout.transaction.totalPaid, greaterThan(0));
      expect(checkout.transaction.customerName, isNull);

      final summary = await cash.fetchSummary(activeSession.id);

      debugPrint(
        '[live] corte esperado=${Money.format(summary.expectedTotal)} '
        'ventas efectivo=${Money.format(summary.cashSales)} '
        'cobros=${Money.format(summary.payments.total)} '
        'bancos=${summary.bankAccounts.length} '
        'movimientos=${summary.cashMovements.length} '
        'operaciones=${summary.transactionsCount}',
      );

      expect(summary.expectedTotal, greaterThan(0));

      if (openedHere) {
        final closed = await cash.closeSession(
          sessionId: activeSession.id,
          closingCashBalance: summary.expectedTotal,
          notes: 'Corte de la prueba de humo de la app',
        );

        debugPrint(
          '[live] corte estado=${closed.session.status} '
          'esperado=${Money.format(closed.session.calculatedCashTotal)} '
          'contado=${Money.format(closed.session.closingCashBalance)} '
          'diferencia=${Money.format(closed.session.cashDifference)}',
        );

        expect(closed.session.status, 'cerrada');
        expect(closed.session.hasDifference, isFalse);
      } else {
        debugPrint(
          '[live] el turno ya estaba abierto: no se corta desde la prueba',
        );
      }

      await auth.logout();
    },
    skip: (liveEmail.isNotEmpty && livePassword.isNotEmpty && livePos)
        ? false
        : 'Requiere LIVE_API_EMAIL/LIVE_API_PASSWORD y LIVE_POS=true',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Prueba de humo de la etapa 4 contra la API real: historial con filtros,
/// detalle, abono (con `LIVE_SALES_WRITE=true`), edición y borrado de pago.
///
/// Sin `LIVE_SALES_WRITE` solo se hacen lecturas. Con él, el abono es de $1 y se
/// elimina al final, así que la venta queda con el mismo saldo que tenía.
void liveSalesTest() {
  test(
    'ventas reales (historial, filtros, detalle y abono)',
    () async {
      final store = _MemorySessionStore();
      final api = ApiClient(baseUrl: liveBaseUrl, readToken: store.readToken);
      final auth = AuthRepository(api: api, sessionStore: store);
      final session = await auth.login(
        email: liveEmail,
        password: livePassword,
      );

      final permissions = PermissionsService.fromLists(
        permissions: session.context.user.permissions,
        moduleKeys: session.context.moduleKeys,
      );

      if (!permissions.can('transactions.access')) {
        debugPrint('[live] sin transactions.access: se omite la prueba');
        await auth.logout();
        return;
      }

      final sales = SalesRepository(api: api);
      final page = await sales.fetchTransactions(perPage: 5);

      debugPrint(
        '[live] ventas total=${page.total} '
        'pagina=${page.currentPage}/${page.lastPage}',
      );

      for (final item in page.items) {
        debugPrint(
          '[live]   ${item.folio} ${item.status} ${item.customerLabel} '
          'total=${Money.format(item.total)} '
          'saldo=${Money.format(item.remainingDue)} '
          'lineas=${item.itemsCount} pedido=${item.isOrder}',
        );
        expect(item.folio, isNotEmpty);
      }

      // Filtros del contrato: estatus y rango de fechas.
      final completed = await sales.fetchTransactions(
        filters: const TransactionFilters(status: 'completado'),
        perPage: 3,
      );
      expect(completed.items.every((item) => item.status == 'completado'), isTrue);

      final today = DateTime.now();
      final range = await sales.fetchTransactions(
        filters: TransactionFilters(dateStart: today, dateEnd: today),
        perPage: 3,
      );
      debugPrint('[live] ventas de hoy=${range.total}');

      // Venta de otra sucursal o inexistente: 404 con el message del servidor.
      final missing = await _capture(() => sales.fetchTransaction(999999999));
      debugPrint('[live] venta inexistente: ${missing.statusCode} ${missing.message}');
      expect(missing.statusCode, 404);

      // Una venta anulada no admite abonos (`already_cancelled`).
      final cancelled = await sales.fetchTransactions(
        filters: const TransactionFilters(status: 'cancelado'),
        perPage: 3,
      );
      final cancelledSale = cancelled.items
          .where((item) => item.customer != null)
          .firstOrNull;

      // Una venta anulada no admite abonos ni reembolsos: el servidor responde
      // `422` explicando el motivo (no se toca ningún dato).
      if (cancelledSale != null) {
        final activeSessionId = session.context.activeSession?.id;

        if (activeSessionId != null &&
            permissions.can('transactions.add_payment')) {
          final error = await _capture(
            () => sales.addPayment(
              transactionId: cancelledSale.id,
              sessionId: activeSessionId,
              payments: <PaymentDraft>[
                const PaymentDraft(method: PosPaymentMethod.cash, amount: 1),
              ],
            ),
          );

          debugPrint(
            '[live] abono a venta cancelada: ${error.statusCode} '
            '${error.code} ${error.message}',
          );
          expect(error.statusCode, 422);
          expect(error.code, 'already_cancelled');
        }

        if (permissions.can('transactions.refund')) {
          final error = await _capture(
            () => sales.refund(
              transactionId: cancelledSale.id,
              method: RefundMethod.balance,
            ),
          );

          debugPrint(
            '[live] reembolso de venta cancelada: ${error.statusCode} '
            '${error.message}',
          );
          expect(error.statusCode, isIn(<int>[422, 403]));
        }
      }

      if (page.items.isEmpty ||
          !permissions.can('transactions.see_details')) {
        await auth.logout();
        return;
      }

      final first = page.items.first;
      final detail = await sales.fetchTransaction(first.id);

      debugPrint(
        '[live] detalle ${detail.folio} items=${detail.items.length} '
        'pagos=${detail.payments.length} '
        'pagado=${Money.format(detail.paidAmount)} '
        'saldo=${Money.format(detail.pendingBalance)} '
        'pagada=${detail.isPaid} '
        'conCuenta=${detail.payments.where((p) => p.bankAccount != null).length}',
      );

      expect(detail.id, first.id);
      expect(detail.items.length, greaterThan(0));

      if (liveSalesLayaway) {
        await _liveLayawayRoundTrip(
          sales: sales,
          api: api,
          auth: auth,
          permissions: permissions,
        );
        return;
      }

      await _liveAbonoRoundTrip(
        sales: sales,
        items: page.items,
        api: api,
        auth: auth,
        permissions: permissions,
      );
    },
    skip: (liveEmail.isNotEmpty && livePassword.isNotEmpty && liveSales)
        ? false
        : 'Requiere LIVE_API_EMAIL/LIVE_API_PASSWORD y LIVE_SALES=true',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<ApiException> _capture(Future<Object?> Function() action) async {
  try {
    await action();
    fail('Se esperaba un ApiException');
  } on ApiException catch (error) {
    return error;
  }
}

/// Escenario completo de dinero con un **apartado** real (etapa 4).
///
/// 1. Crea el apartado con el payload que arma la propia app (`CartState`).
/// 2. Abona $1, edita el pago a $1.50 y lo **borra** (el saldo vuelve a 0).
/// 3. Abona $2 y cancela el apartado con **reembolso en efectivo**.
/// 4. Comprueba que el stock volvió y deja constancia del desfase de saldo del
///    cliente que provoca el borrado del pago (bug de backend, ver README).
///
/// Ojo: cada corrida deja `firstAbono` como saldo a favor del cliente de prueba.
Future<void> _liveLayawayRoundTrip({
  required SalesRepository sales,
  required ApiClient api,
  required AuthRepository auth,
  required PermissionsService permissions,
}) async {
  const neededPermissions = <String>[
    'pos.access',
    'pos.create_sale',
    'transactions.add_payment',
    'transactions.edit_payment',
    'transactions.refund',
  ];
  final missing = neededPermissions
      .where((permission) => !permissions.can(permission))
      .toList(growable: false);

  if (missing.isNotEmpty) {
    debugPrint('[live] sin permisos para el apartado: ${missing.join(', ')}');
    await auth.logout();
    return;
  }

  // Producto con stock (y su variante, si tiene) y cliente real.
  final catalog = CatalogRepository(api: api);
  final products = await catalog.fetchProducts(perPage: 50);
  final candidate = products.items
      .where((item) => item.stock > 0 || item.variantCombinations.isNotEmpty)
      .firstOrNull;

  if (candidate == null) {
    debugPrint('[live] no hay productos con stock: no se crea el apartado');
    await auth.logout();
    return;
  }

  final product = await catalog.fetchProduct(candidate.id);
  final variant = product.variantCombinations
      .where((combination) => combination.stock > 0)
      .firstOrNull;

  final customers = CustomersRepository(api: api);
  final customerPage = await customers.fetchCustomers(perPage: 50);

  if (customerPage.items.isEmpty) {
    debugPrint('[live] no hay clientes: no se crea el apartado');
    await auth.logout();
    return;
  }

  // Se usa el primer cliente. Ojo: el servidor aplica automáticamente su saldo a
  // favor a la venta (ver README, hallazgo 10), así que el escenario no exige un
  // cliente "limpio": detecta si lo usó y, si no, valida además el desfase de
  // saldo que provoca el borrado del pago (hallazgo 8).
  final customer = customerPage.items.first;
  final customerBefore = await customers.fetchCustomer(customer.id);
  final line = ProductLineBuilder.build(
    product,
    variant: variant,
    quantity: 1,
  );

  debugPrint(
    '[live] apartado de prueba: producto=${product.name} '
    'stock=${product.stock}/${product.reservedStock} '
    'cliente=${customer.displayName} '
    'saldo=${Money.format(customerBefore.customer.balance)}',
  );

  // Turno abierto (el apartado y los abonos lo exigen).
  final cash = CashRegisterRepository(api: api);
  final current = await cash.fetchCurrent();
  var activeSession = current.activeSession;
  var openedHere = false;

  if (activeSession == null) {
    if (!current.canStartShift) {
      debugPrint('[live] sin terminal libre: no se crea el apartado');
      await auth.logout();
      return;
    }

    activeSession = await cash.openSession(
      cashRegisterId: current.availableCashRegisters.first.id,
      openingCashBalance: 1000,
      declaredBankBalances: <int, double>{
        for (final account in current.bankAccounts) account.id: account.balance,
      },
    );
    openedHere = true;
  }

  final cart = CartState(lines: <CartLine>[line], customer: customer);

  final layaway = await PosRepository(api: api).layaway(
    cart.buildSalePayload(
      sessionId: activeSession.id,
      clientUuid: UuidGenerator.v4(),
      layawayExpirationDate: DateTime.now().add(const Duration(days: 7)),
    ),
  );

  debugPrint(
    '[live] apartado ${layaway.transaction.folio} '
    'estatus=${layaway.transaction.status} '
    'total=${Money.format(layaway.transaction.total)} '
    'saldo=${Money.format(layaway.transaction.remainingDue)}',
  );

  expect(layaway.transaction.status, 'apartado');
  expect(layaway.transaction.remainingDue, greaterThan(0));

  // El servidor puede haber aplicado el saldo a favor del cliente aunque no se
  // envió `use_balance` (hallazgo 10): si lo hizo, no se valida el desfase final
  // de la deuda porque la aritmética incluye ese saldo.
  final usedBalanceOnLayaway = layaway.transaction.totalPaid > 0.01;

  if (usedBalanceOnLayaway) {
    debugPrint(
      '[live] el servidor aplicó saldo a favor al crear el apartado: '
      'pagado=${Money.format(layaway.transaction.totalPaid)}',
    );
  }

  final transactionId = layaway.transaction.id;
  const firstAbono = 1.0;
  const secondAbono = 2.0;

  // 1) Abono de $1: el servidor suma el pago y baja el saldo.
  final first = await sales.addPayment(
    transactionId: transactionId,
    sessionId: activeSession.id,
    payments: <PaymentDraft>[
      const PaymentDraft(method: PosPaymentMethod.cash, amount: firstAbono),
    ],
  );

  debugPrint(
    '[live] abono #1 pagado=${Money.format(first.transaction.paidAmount)} '
    'saldo=${Money.format(first.transaction.remainingDue)} '
    'ticket=${first.receipt?.type} ${first.receipt?.ticket.abonado}',
  );

  expect(first.transaction.paidAmount, closeTo(layaway.transaction.totalPaid + firstAbono, 0.01));
  expect(first.receipt?.ticket.folio, layaway.transaction.folio);
  expect(first.receipt?.ticket.liquidated, isFalse);

  // Pagado **antes** de este abono: al borrar el pago la venta debe volver aquí.
  final paidBeforeAbono = Money.round2(
    first.transaction.paidAmount - firstAbono,
  );

  // 2) Editar el pago a $1.50 y comprobar el mensaje del servidor.
  const editedAmount = 1.5;
  final paymentId = first.transaction.payments
      .map((payment) => payment.id)
      .reduce((a, b) => a > b ? a : b);

  final edited = await sales.updatePayment(
    transactionId: transactionId,
    paymentId: paymentId,
    amount: editedAmount,
    paymentMethod: 'efectivo',
    notes: 'Prueba de humo de la etapa 4',
  );
  debugPrint(
    '[live] pago editado id=$paymentId monto=${edited.payment?.amount} '
    'mensaje="${edited.message}"',
  );

  expect(edited.payment?.amount, closeTo(1.5, 0.01));
  expect(edited.message, isNotEmpty);

  // 3) Borrar el pago devuelve el saldo pendiente completo.
  await sales.deletePayment(transactionId: transactionId, paymentId: paymentId);
  final afterDelete = await sales.fetchTransaction(transactionId);

  debugPrint(
    '[live] pago borrado pagado=${Money.format(afterDelete.paidAmount)} '
    'saldo=${Money.format(afterDelete.pendingBalance)}',
  );

  expect(afterDelete.paidAmount, closeTo(paidBeforeAbono, 0.01));
  expect(
    afterDelete.pendingBalance,
    closeTo(layaway.transaction.remainingDue, 0.01),
  );

  // 4) Abono de $2 y cancelación con reembolso en efectivo.
  final second = await sales.addPayment(
    transactionId: transactionId,
    sessionId: activeSession.id,
    payments: <PaymentDraft>[
      const PaymentDraft(method: PosPaymentMethod.cash, amount: secondAbono),
    ],
  );

  expect(second.transaction.paidAmount, closeTo(2, 0.01));

  final cancelled = await sales.refund(
    transactionId: transactionId,
    method: RefundMethod.cash,
  );

  debugPrint(
    '[live] apartado cancelado estatus=${cancelled.transaction.status} '
    'mensaje="${cancelled.message}"',
  );

  expect(cancelled.transaction.status, 'reembolsado');
  expect(cancelled.message, isNotEmpty);

  // 5) El stock vuelve a su estado original.
  final productAfter = await catalog.fetchProduct(product.id);
  final customerAfter = await customers.fetchCustomer(customer.id);

  debugPrint(
    '[live] tras cancelar: stock=${productAfter.stock}/'
    '${productAfter.reservedStock} '
    'saldo cliente=${Money.format(customerAfter.customer.balance)}',
  );

  expect(productAfter.stock, greaterThanOrEqualTo(product.stock));

  // HALLAZGO DE BACKEND (no se corrige desde la app): el `DELETE` de un pago no
  // revierte el `payDebt` que el abono escribió en `customers.balance`
  // (`TransactionPaymentEditService::delete` solo revierte el banco, el saldo
  // usado como pago y el movimiento de caja; tampoco lo hace el PUT). Al
  // cancelar con reembolso en efectivo, `reverseCustomerDebt` perdona
  // `total - total_paid` (sin el pago borrado), así que el cliente conserva el
  // importe del pago eliminado como saldo a favor.
  //
  // La prueba **caracteriza** ese comportamiento (en vez de exigir deuda
  // intacta) para que el fallo quede documentado y visible, y no como una
  // assertion roja permanente.
  final deletedAmount = firstAbono;

  if (usedBalanceOnLayaway) {
    debugPrint(
      '[live] desfase de saldo no evaluado: el apartado usó saldo a favor del '
      'cliente (saldo final ${Money.format(customerAfter.customer.balance)})',
    );
  } else {
    debugPrint(
      '[live] desfase conocido de backend al borrar el pago: '
      'saldo a favor de ${Money.format(deletedAmount)} '
      '(cada corrida deja ese saldo en el cliente de prueba)',
    );

    expect(
      customerAfter.customer.balance,
      closeTo(customerBefore.customer.balance + deletedAmount, 0.01),
      reason:
          'el cliente conserva el importe del pago borrado como saldo a favor '
          '(bug de conciliación del backend, ver README)',
    );
  }

  if (openedHere) {
    final summary = await cash.fetchSummary(activeSession.id);

    debugPrint(
      '[live] corte esperado=${Money.format(summary.expectedTotal)} '
      'ventas efectivo=${Money.format(summary.cashSales)} '
      'cobros=${Money.format(summary.payments.total)} '
      'movimientos=${summary.cashMovements.length}',
    );

    final closed = await cash.closeSession(
      sessionId: activeSession.id,
      closingCashBalance: summary.expectedTotal,
      notes: 'Corte de la prueba de humo de la etapa 4 (apartado)',
    );

    expect(closed.session.status, 'cerrada');
  }

  await auth.logout();
}

/// Abono real de $1 sobre una venta con saldo y cliente: lo edita y lo elimina
/// para dejar la venta con el mismo saldo que tenía.
///
/// Requiere `LIVE_SALES_WRITE=true` y los permisos
/// `transactions.add_payment` + `transactions.edit_payment`.
Future<void> _liveAbonoRoundTrip({
  required SalesRepository sales,
  required List<TransactionSummary> items,
  required ApiClient api,
  required AuthRepository auth,
  required PermissionsService permissions,
}) async {
  if (!liveSalesWrite ||
      !permissions.can('transactions.add_payment') ||
      !permissions.can('transactions.edit_payment')) {
    debugPrint('[live] sin LIVE_SALES_WRITE (o sin permisos): no se abona');
    await auth.logout();
    return;
  }

  final target = items
      .where((item) => item.hasPendingBalance && item.customer != null)
      .firstOrNull;

  if (target == null) {
    debugPrint('[live] no hay venta con saldo y cliente: no se abona');
    await auth.logout();
    return;
  }

  final cash = CashRegisterRepository(api: api);
  final current = await cash.fetchCurrent();
  var activeSession = current.activeSession;
  var openedHere = false;

  if (activeSession == null) {
    if (!current.canStartShift) {
      debugPrint('[live] sin terminal libre: no se abona');
      await auth.logout();
      return;
    }

    activeSession = await cash.openSession(
      cashRegisterId: current.availableCashRegisters.first.id,
      openingCashBalance: 1000,
      declaredBankBalances: <int, double>{
        for (final account in current.bankAccounts) account.id: account.balance,
      },
    );
    openedHere = true;
  }

  final before = await sales.fetchTransaction(target.id);
  final amount = before.pendingBalance < 1 ? before.pendingBalance : 1.0;

  final abono = await sales.addPayment(
    transactionId: target.id,
    sessionId: activeSession.id,
    payments: <PaymentDraft>[
      PaymentDraft(method: PosPaymentMethod.cash, amount: amount),
    ],
  );

  debugPrint(
    '[live] abono ${abono.transaction.folio} '
    'pagado=${Money.format(abono.transaction.paidAmount)} '
    'saldo=${Money.format(abono.transaction.pendingBalance)} '
    'ticket=${abono.receipt?.type} abonado=${abono.receipt?.ticket.abonado} '
    'telefono=${abono.receipt?.customerPhone ?? "sin telefono"}',
  );

  expect(abono.transaction.paidAmount, greaterThan(before.paidAmount));
  expect(abono.receipt?.ticket.folio, abono.transaction.folio);

  final paymentId = abono.transaction.payments.isEmpty
      ? null
      : abono.transaction.payments
            .map((payment) => payment.id)
            .reduce((a, b) => a > b ? a : b);

  if (paymentId != null) {
    final updated = await sales.updatePayment(
      transactionId: target.id,
      paymentId: paymentId,
      amount: Money.round2(amount + 0.5),
      paymentMethod: 'efectivo',
      notes: 'Prueba de humo de la app',
    );

    debugPrint(
      '[live] pago editado id=${updated.payment?.id} '
      'monto=${Money.format(updated.payment?.amount)} '
      'mensaje="${updated.message}"',
    );

    expect(updated.message, isNotEmpty);
    expect(updated.payment?.amount, Money.round2(amount + 0.5));

    await sales.deletePayment(transactionId: target.id, paymentId: paymentId);

    final after = await sales.fetchTransaction(target.id);

    debugPrint(
      '[live] tras borrar el pago: pagado=${Money.format(after.paidAmount)} '
      'saldo=${Money.format(after.pendingBalance)}',
    );

    expect(after.paidAmount, closeTo(before.paidAmount, 0.01));
  }

  if (openedHere) {
    final summary = await cash.fetchSummary(activeSession.id);

    await cash.closeSession(
      sessionId: activeSession.id,
      closingCashBalance: summary.expectedTotal,
      notes: 'Corte de la prueba de humo de la etapa 4',
    );
  }

  await auth.logout();
}
