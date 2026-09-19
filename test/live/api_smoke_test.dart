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

Future<ApiException> _capture(Future<Object?> Function() action) async {
  try {
    await action();
    fail('Se esperaba un ApiException');
  } on ApiException catch (error) {
    return error;
  }
}
