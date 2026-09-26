import 'dart:convert';
import 'dart:io';

import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_endpoints.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/core/utils/money.dart';
import 'package:ezyventas_app/core/utils/uuid_generator.dart';
import 'package:ezyventas_app/features/account/data/account_repository.dart';
import 'package:ezyventas_app/features/account/data/models/notification_counters.dart';
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
import 'package:ezyventas_app/core/utils/evidence_image.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_detail.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_filters.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_form.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_item_draft.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_status.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_summary.dart';
import 'package:ezyventas_app/features/service_orders/data/service_orders_repository.dart';
import 'package:ezyventas_app/features/printing/data/models/print_document.dart';
import 'package:ezyventas_app/features/printing/data/models/print_template.dart';
import 'package:ezyventas_app/features/printing/data/printing_repository.dart';
import 'package:ezyventas_app/features/printing/data/whatsapp_message_builder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

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
  Future<void> saveSession(AuthSession session, {bool? persist}) async =>
      _session = session;
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

/// Habilita la prueba real de la etapa 5 (órdenes de servicio). Escribe datos
/// reales (orden, estatus, diagnóstico con foto, anticipo, edición y borrado),
/// por eso está apagada por defecto: `LIVE_SERVICE_ORDERS=true`.
const bool liveServiceOrders = bool.fromEnvironment('LIVE_SERVICE_ORDERS');

/// Además del flujo sin stock, agrega una **refacción** (`App\Models\Product`)
/// como concepto: el servidor descuenta stock y el borrado de la orden **no**
/// lo devuelve (mismo comportamiento que la web).
const bool liveServiceOrdersStock = bool.fromEnvironment(
  'LIVE_SERVICE_ORDERS_STOCK',
);

/// Habilita la prueba real de la etapa 6 (impresión térmica y WhatsApp).
///
/// Solo **lee**: pide plantillas, un ticket ESC/POS, una etiqueta TSPL, el
/// respaldo HTML y el ticket de WhatsApp de ventas y órdenes reales.
/// `LIVE_PRINTING=true`.
const bool livePrinting = bool.fromEnvironment('LIVE_PRINTING');

/// Venta sobre la que se piden los documentos (0 = la más reciente).
const int livePrintingTransactionId = int.fromEnvironment(
  'LIVE_PRINTING_TRANSACTION_ID',
);

/// Orden de servicio para probar la impresión de la orden (0 = la más reciente).
const int livePrintingServiceOrderId = int.fromEnvironment(
  'LIVE_PRINTING_SERVICE_ORDER_ID',
);

/// Habilita la prueba real de la etapa 7 (cuenta): notificaciones, soporte,
/// perfil y suscripción. Solo **lee**: `LIVE_ACCOUNT=true`.
const bool liveAccount = bool.fromEnvironment('LIVE_ACCOUNT');

/// Además de leer, escribe de forma **reversible**: guarda el perfil con los
/// mismos datos, borra la foto solo si no hay ninguna, y comprueba los errores
/// de contraseña/documento/factura sin cambiar nada.
const bool liveAccountWrite = bool.fromEnvironment('LIVE_ACCOUNT_WRITE');

/// Cambia de sucursal y **vuelve** a la original, para dejar la cuenta como
/// estaba (`PUT /branch/switch/{id}` aplica a todos los dispositivos).
const bool liveAccountBranch = bool.fromEnvironment('LIVE_ACCOUNT_BRANCH');

/// Borra la foto de perfil de verdad (destructivo: el usuario la pierde).
const bool liveAccountDeletePhoto = bool.fromEnvironment(
  'LIVE_ACCOUNT_DELETE_PHOTO',
);

/// Id de un pago de la suscripción para `request-invoice` (0 = solo se prueba el
/// `404` de un id inexistente).
const int liveAccountInvoicePaymentId = int.fromEnvironment(
  'LIVE_ACCOUNT_INVOICE_PAYMENT_ID',
);


/// el `multipart/form-data` real (el servidor exige que el archivo sea imagen).
final Uint8List evidenceJpegBytes = base64Decode(
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHR'
  'ofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QA'
  'FAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp'
  '//2Q==',
);


void main() {
  final hasCredentials = liveEmail.isNotEmpty && livePassword.isNotEmpty;

  setUpAll(() async {
    // Permite llamadas HTTP reales dentro del runner de pruebas.
    HttpOverrides.global = null;

    // Igual que `main()` de la app: sin esto `DateFormat` de es-MX lanza
    // `LocaleDataException` al formatear fechas y montos.
    Intl.defaultLocale = 'es_MX';
    await initializeDateFormatting('es_MX');
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
      // Inicio es la primera pestaña y el destino por defecto.
      expect(visibleTabs, contains(AppTab.home));
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
        // Sin ningún permiso efectivo la app solo deja entrar a "Inicio" y
        // "Cuenta".
        expect(visibleTabs, <AppTab>[AppTab.home, AppTab.account]);
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
  liveServiceOrdersTest();
  livePrintingTest();
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
      var joinedHere = false;
      var activeSession = current.activeSession;

      if (activeSession == null && current.canJoinShift) {
        // Sin terminal libre pero con un turno abierto en la sucursal: es lo que
        // ofrece la pestaña Caja («Unirme», contrato §6). Se entra a ese turno
        // para poder cobrar; **no** se cierra al terminar porque no lo abrimos
        // nosotros (el turno es de su dueño original).
        activeSession = await cash.joinSession(
          current.joinableSessions.first.id,
        );
        joinedHere = true;

        debugPrint(
          '[live] unido al turno id=${activeSession.id} '
          'terminal=${activeSession.cashRegisterName} '
          'abierto=${activeSession.openedAt}',
        );
      }

      if (activeSession == null) {
        expect(
          current.canStartShift,
          isTrue,
          reason:
              'No hay terminal libre ni turno al que unirse: no se puede probar el cobro',
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
          joinedHere
              ? '[live] el turno era de otro usuario: la prueba se unió a él y '
                    'no lo corta'
              : '[live] el turno ya estaba abierto: no se corta desde la prueba',
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
        filters: const TransactionFilters(statuses: <String>['completado']),
        perPage: 3,
      );
      expect(completed.items.every((item) => item.status == 'completado'), isTrue);

      // Varios estatus a la vez (D4, 2026-09-20): «Deudas por vencer» pide
      // apartados + créditos en una sola llamada.
      final debts = await sales.fetchTransactions(
        filters: const TransactionFilters(
          statuses: <String>['apartado', 'pendiente'],
        ),
        perPage: 10,
      );

      debugPrint(
        '[live] deudas por vencer (apartado+pendiente) total=${debts.total} '
        'estatus=${debts.items.map((item) => item.status).toSet().join(', ')}',
      );

      expect(
        debts.items
            .every(
              (item) => item.status == 'apartado' || item.status == 'pendiente',
            ),
        isTrue,
        reason: 'la API debe aplicar los dos estatus, no solo el último',
      );

      // Un estatus desconocido sigue respondiendo `422` con `errors.status.N`:
      // el servidor lo manda en **notación con punto** (`errors["status.0"]`,
      // comprobado con `curl` el 21 sep 2026), así que no hay una clave pelada
      // `status` que leer.
      final badStatus = await _capture(
        () => sales.fetchTransactions(
          filters: const TransactionFilters(statuses: <String>['inventado']),
          perPage: 1,
        ),
      );

      final statusErrors = badStatus.errors.entries
          .where(
            (entry) => entry.key == 'status' || entry.key.startsWith('status.'),
          )
          .expand((entry) => entry.value)
          .toList(growable: false);

      debugPrint(
        '[live] estatus inválido: ${badStatus.statusCode} '
        'claves=${badStatus.errors.keys.join(', ')} '
        '${statusErrors.isEmpty ? badStatus.message : statusErrors.first}',
      );

      expect(badStatus.statusCode, 422);
      expect(
        statusErrors,
        isNotEmpty,
        reason: 'el 422 debe decir qué campo falló (`status.N`)',
      );

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
        filters: const TransactionFilters(statuses: <String>['cancelado']),
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

/// Prueba de humo de la etapa 5 contra la API real: órdenes de servicio.
///
/// Con `LIVE_SERVICE_ORDERS=true` crea una orden **real** (sin cliente, para no
/// dejar deuda en la base de datos), le cambia el estatus, guarda diagnóstico
/// con una foto, registra un anticipo, la edita, prueba `ensure-transaction` y
/// la elimina al final (el servidor borra su venta vinculada, por eso el corte
/// de la sesión de prueba no la incluye).
void liveServiceOrdersTest() {
  test(
    'órdenes de servicio reales (listado, alta con foto, estatus, diagnóstico, anticipo, edición y borrado)',
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

      if (!permissions.can('services.orders.access')) {
        debugPrint('[live] sin services.orders.access: se omite la prueba');
        await auth.logout();
        return;
      }

      final orders = ServiceOrdersRepository(api: api);

      // 1) Listado con filtros y orden del contrato.
      final page = await orders.fetchServiceOrders(perPage: 5);
      debugPrint(
        '[live] órdenes total=${page.total} '
        'pagina=${page.currentPage}/${page.lastPage}',
      );
      for (final item in page.items) {
        debugPrint(
          '[live]   ${item.folio} ${item.statusLabel} '
          '${item.customerLabel} · ${Money.format(item.finalTotal)} '
          'saldo=${Money.format(item.amountDue)} '
          'venta=${item.hasTransaction}',
        );
      }

      final byStatus = await orders.fetchServiceOrders(
        filters: const ServiceOrderFilters(status: 'terminado'),
        perPage: 3,
      );
      expect(
        byStatus.items.every((item) => item.status == 'terminado'),
        isTrue,
      );

      final search = await orders.fetchServiceOrders(
        filters: const ServiceOrderFilters(search: 'OS-'),
        perPage: 3,
      );
      debugPrint('[live] búsqueda "OS-" total=${search.total}');

      final promised = await orders.fetchServiceOrders(
        filters: const ServiceOrderFilters(sort: ServiceOrderSort.promised),
        perPage: 3,
      );
      debugPrint('[live] orden por promesa total=${promised.total}');

      // 2) Orden de otra sucursal o inexistente: 404 con el message del servidor.
      final missing = await _capture(() => orders.fetchServiceOrder(999999999));
      debugPrint('[live] orden inexistente: ${missing.statusCode} ${missing.message}');
      expect(missing.statusCode, 404);

      // 2b) Campos personalizados del módulo (D5, 2026-09-20): con esto la app
      // puede dibujarlos al **crear** una orden, no solo al editarla.
      final definitions = await orders.fetchCustomFieldDefinitions();

      debugPrint(
        '[live] campos personalizados del módulo=${definitions.length} '
        '${definitions.map((field) => '${field.key}:${field.type}${field.isRequired ? ' (obligatorio)' : ''}').join(', ')}',
      );

      for (final field in definitions) {
        expect(field.key, isNotEmpty);
        expect(field.name, isNotEmpty);
        expect(field.type, isNotEmpty);
      }

      if (!liveServiceOrders) {
        debugPrint('[live] sin LIVE_SERVICE_ORDERS: solo lectura');
        await auth.logout();
        return;
      }

      await _liveServiceOrderRoundTrip(
        orders: orders,
        api: api,
        auth: auth,
        permissions: permissions,
      );
    },
    skip: (liveEmail.isNotEmpty && livePassword.isNotEmpty)
        ? false
        : 'Requiere LIVE_API_EMAIL/LIVE_API_PASSWORD',
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

/// Flujo completo de escritura de una orden de servicio (etapa 5).
///
/// No usa cliente (`customer_id: null`) para no dejar deuda en la base de datos
/// y usa un servicio del catálogo como concepto: solo las refacciones
/// (`App\Models\Product`/`ProductAttribute`) descuentan stock y el borrado de la
/// orden no lo devuelve. Con `LIVE_SERVICE_ORDERS_STOCK=true` se agrega además
/// una refacción (consume una pieza real).
Future<void> _liveServiceOrderRoundTrip({
  required ServiceOrdersRepository orders,
  required ApiClient api,
  required AuthRepository auth,
  required PermissionsService permissions,
}) async {
  const needed = <String>[
    'services.orders.create',
    'services.orders.edit',
    'services.orders.change_status',
    'services.orders.delete',
    'transactions.add_payment',
    'pos.access',
  ];
  final missing = needed
      .where((permission) => !permissions.can(permission))
      .toList(growable: false);

  if (missing.isNotEmpty) {
    debugPrint('[live] sin permisos para la orden: ${missing.join(', ')}');
    await auth.logout();
    return;
  }

  // La orden exige una sesión de caja abierta de la sucursal.
  final cash = CashRegisterRepository(api: api);
  final current = await cash.fetchCurrent();
  var openedHere = false;
  var activeSession = current.activeSession;

  if (activeSession == null) {
    if (!current.canStartShift) {
      debugPrint('[live] no hay terminal libre: no se crea la orden');
      await auth.logout();
      return;
    }

    activeSession = await cash.openSession(
      cashRegisterId: current.availableCashRegisters.first.id,
      openingCashBalance: 0,
    );
    openedHere = true;

    debugPrint(
      '[live] turno abierto para la orden id=${activeSession.id} '
      'terminal=${activeSession.cashRegisterName}',
    );

    // La sesión de prueba se corta **siempre** (aunque el escenario falle), con
    // el efectivo esperado del resumen para no dejar descuadre en la caja.
    final sessionId = activeSession.id;

    addTearDown(() async {
      final summary = await cash.fetchSummary(sessionId);
      final closed = await cash.closeSession(
        sessionId: sessionId,
        closingCashBalance: summary.expectedTotal,
        notes: 'Corte de la prueba de humo de órdenes de servicio',
      );

      debugPrint(
        '[live] corte de la sesión de prueba: estado=${closed.session.status} '
        'esperado=${Money.format(closed.session.calculatedCashTotal)} '
        'diferencia=${Money.format(closed.session.cashDifference)}',
      );

      expect(closed.session.status, 'cerrada');
      await auth.logout();
    });
  }

  // Concepto del catálogo: un servicio (no mueve stock).
  final catalog = CatalogRepository(api: api);
  final services = await catalog.fetchServices(perPage: 5);
  final service = services.items.firstOrNull;

  final items = <ServiceOrderItemDraft>[
    if (service != null)
      ServiceOrderItemDraft(
        description: service.name,
        quantity: 1,
        unitPrice: service.lowestPrice > 0 ? service.lowestPrice : 300,
        itemableType: service.hasVariants
            ? ServiceOrderItemType.serviceVariant
            : ServiceOrderItemType.service,
        itemableId: service.hasVariants
            ? service.variants.first.id
            : service.id,
      )
    else
      const ServiceOrderItemDraft(
        description: 'Mano de obra (prueba de humo)',
        quantity: 1,
        unitPrice: 300,
      ),
  ];

  /// Refacción con la que se prueba que borrar la orden **devuelve el stock**
  /// (corrección A6 del backend, 2026-09-20). Queda como `id`/stock previos para
  /// volver a leer el producto después del borrado.
  var stockedProductId = 0;
  var stockedProductStock = 0.0;

  if (liveServiceOrdersStock) {
    final products = await catalog.fetchProducts(perPage: 20);
    final product = products.items.where((item) => item.stock > 0).firstOrNull;

    if (product != null) {
      stockedProductId = product.id;
      stockedProductStock = product.stock;

      items.add(
        ServiceOrderItemDraft(
          description: 'Refacción de prueba: ${product.name}',
          quantity: 1,
          unitPrice: product.price,
          itemableType: ServiceOrderItemType.product,
          itemableId: product.id,
        ),
      );

      debugPrint(
        '[live] refacción agregada: ${product.name} '
        'stock previo=${Money.formatQuantity(product.stock)}',
      );
    }
  }

  final evidence = <EvidenceImage>[
    EvidenceImage.fromBytes(
      fileName: 'recepcion-prueba.jpg',
      bytes: evidenceJpegBytes,
    ),
  ];

  final created = await orders.createServiceOrder(
    sessionId: activeSession.id,
    form: ServiceOrderFormData(
      customerName: 'Público general (prueba app)',
      itemDescription: 'Equipo de prueba de la app móvil',
      reportedProblems: 'Fallas reportadas en la prueba de humo de la etapa 5',
      promisedAt: DateTime.now().add(const Duration(days: 3)),
      assignTechnician: true,
      technicianName: 'Técnico de prueba',
      commissionType: TechnicianCommissionType.percentage,
      commissionValue: 20,
      items: items,
      evidence: evidence,
    ),
  );

  final orderId = created.detail.id;

  debugPrint(
    '[live] orden creada ${created.message} folio=${created.detail.folio} '
    'estatus=${created.detail.status} '
    'total=${Money.format(created.detail.finalTotal)} '
    'venta=${created.detail.transaction?.folio} '
    'evidencias=${created.detail.initialEvidence.length} '
    'comisión=${Money.format(created.detail.technicianCommission)}',
  );

  expect(created.detail.folio, startsWith('OS-'));
  expect(created.detail.status, 'pendiente');
  expect(created.detail.hasTransaction, isTrue);
  expect(created.detail.transaction!.folio, startsWith('OS-V-'));
  expect(created.detail.initialEvidence, isNotEmpty);
  expect(created.detail.promisedAt, isNotNull);

  // Detalle releído: mismos totales y misma venta vinculada.
  final detail = await orders.fetchServiceOrder(orderId);

  debugPrint(
    '[live] detalle ${detail.folio} items=${detail.items.length} '
    'saldo=${Money.format(detail.pendingAmount)} '
    'actividades=${detail.activities.length} '
    'campos=${detail.customFieldDefinitions.length}',
  );

  expect(detail.items.length, items.length);
  expect(detail.pendingAmount, greaterThan(0));
  expect(detail.activities, isNotEmpty);

  // Cambio de estatus hacia adelante.
  final advanced = await orders.updateStatus(
    serviceOrderId: orderId,
    status: ServiceOrderStatus.inProgress.value,
  );

  debugPrint('[live] estatus: ${advanced.message}');
  expect(advanced.summary.status, 'en_progreso');

  // Repetir el mismo estatus: `422` con el motivo en `errors.status[0]`.
  final repeated = await _capture(
    () => orders.updateStatus(
      serviceOrderId: orderId,
      status: ServiceOrderStatus.inProgress.value,
    ),
  );

  debugPrint(
    '[live] estatus repetido: ${repeated.statusCode} '
    '${repeated.errorFor('status')}',
  );
  expect(repeated.statusCode, 422);
  expect(repeated.errorFor('status'), isNotEmpty);

  // Estatus inexistente: el mensaje viene en `errors.status[0]`.
  final invalid = await _capture(
    () => orders.updateStatus(serviceOrderId: orderId, status: 'en_el_taller'),
  );

  debugPrint(
    '[live] estatus inválido: ${invalid.statusCode} '
    '${invalid.errorFor('status')}',
  );
  expect(invalid.statusCode, 422);
  expect(invalid.errorFor('status'), 'El estatus seleccionado no es válido.');

  // Diagnóstico con evidencia de cierre (multipart).
  final diagnosed = await orders.saveDiagnosis(
    serviceOrderId: orderId,
    diagnosis: 'Diagnóstico capturado desde la app (prueba de humo).',
    images: <EvidenceImage>[
      EvidenceImage.fromBytes(
        fileName: 'cierre-prueba.jpg',
        bytes: evidenceJpegBytes,
      ),
    ],
  );

  debugPrint(
    '[live] diagnóstico: ${diagnosed.message} '
    'texto="${diagnosed.detail.technicianDiagnosis}" '
    'cierre=${diagnosed.detail.closingEvidence.length}',
  );

  expect(
    diagnosed.detail.technicianDiagnosis,
    'Diagnóstico capturado desde la app (prueba de humo).',
  );
  expect(diagnosed.detail.closingEvidence, isNotEmpty);

  // Sin enviar el diagnóstico, el servidor conserva el texto anterior.
  final preserved = await orders.saveDiagnosis(serviceOrderId: orderId);

  debugPrint(
    '[live] diagnóstico conservado: "${preserved.detail.technicianDiagnosis}" '
    'cierre=${preserved.detail.closingEvidence.length}',
  );

  expect(
    preserved.detail.technicianDiagnosis,
    'Diagnóstico capturado desde la app (prueba de humo).',
  );

  // Anticipo de $10 en efectivo.
  final payment = await orders.addPayment(
    serviceOrderId: orderId,
    sessionId: activeSession.id,
    payments: <PaymentDraft>[
      const PaymentDraft(method: PosPaymentMethod.cash, amount: 10),
    ],
  );

  debugPrint(
    '[live] anticipo: total=${Money.format(payment.detail.finalTotal)} '
    'pagado=${Money.format(payment.detail.totalPaid)} '
    'saldo=${Money.format(payment.detail.pendingAmount)} '
    'venta=${payment.detail.transaction?.folio} '
    'ticket=${payment.receipt?.ticket.abonado} '
    'telefono=${payment.receipt?.customerPhone ?? "sin teléfono"}',
  );

  expect(payment.detail.totalPaid, 10);
  expect(payment.receipt, isNotNull);
  expect(payment.receipt!.ticket.liquidated, isFalse);

  // Edición: cambia la descripción del equipo, el técnico y borra la evidencia
  // inicial (`deleted_media_ids`).
  final editForm = formDataFromDetail(payment.detail);

  final updated = await orders.updateServiceOrder(
    serviceOrderId: orderId,
    form: ServiceOrderFormData(
      customerId: editForm.customerId,
      customerName: editForm.customerName,
      customerEmail: editForm.customerEmail,
      customerPhone: editForm.customerPhone,
      addressStreet: editForm.addressStreet,
      addressCity: editForm.addressCity,
      itemDescription: 'Equipo de prueba (editado desde la app)',
      reportedProblems: editForm.reportedProblems,
      promisedAt: editForm.promisedAt,
      assignTechnician: true,
      technicianName: 'Técnico de prueba (editado)',
      commissionType: TechnicianCommissionType.fixed,
      commissionValue: 50,
      items: editForm.items,
      discountType: ServiceOrderDiscountType.fixed,
      discountValue: editForm.discountValue,
      customFields: editForm.customFields,
      deletedMediaIds: <int>[
        if (payment.detail.initialEvidence.isNotEmpty)
          payment.detail.initialEvidence.first.id,
      ],
    ),
  );

  debugPrint(
    '[live] orden editada: ${updated.message} '
    'equipo="${updated.detail.itemDescription}" '
    'técnico=${updated.detail.technicianName} '
    'comisión=${Money.format(updated.detail.technicianCommission)} '
    'evidencias iniciales=${updated.detail.initialEvidence.length}',
  );

  expect(
    updated.detail.itemDescription,
    'Equipo de prueba (editado desde la app)',
  );
  expect(updated.detail.technicianName, 'Técnico de prueba (editado)');
  expect(updated.detail.technicianCommission, 50);
  expect(updated.detail.initialEvidence, isEmpty);

  // `ensure-transaction` con venta existente: devuelve la misma (sin duplicar).
  final transactionId = await orders.ensureTransaction(orderId);

  debugPrint('[live] ensure-transaction: $transactionId');
  expect(transactionId, updated.detail.transaction!.id);

  // Impresión de la orden (etapa 6): el ticket de la orden se codifica con la
  // plantilla del negocio y su venta vinculada alimenta el ticket de WhatsApp.
  if (livePrinting) {
    await _liveOrderPrintingRoundTrip(api: api, orderId: orderId);
  }

  // Borrado con `204` sin cuerpo y `404` después.
  await orders.deleteServiceOrder(orderId);

  final gone = await _capture(() => orders.fetchServiceOrder(orderId));

  debugPrint('[live] orden eliminada: ${gone.statusCode} ${gone.message}');
  expect(gone.statusCode, 404);

  // Corrección A6 del backend (2026-09-20): borrar la orden **devuelve** el
  // stock de la refacción (antes se quedaba consumido). Solo se puede
  // comprobar con `LIVE_SERVICE_ORDERS_STOCK=true` y una venta vinculada.
  if (stockedProductId > 0) {
    final after = await catalog.fetchProduct(stockedProductId);

    debugPrint(
      '[live] stock de la refacción tras borrar la orden: '
      '${Money.formatQuantity(after.stock)} '
      '(antes ${Money.formatQuantity(stockedProductStock)})',
    );

    expect(
      after.stock,
      closeTo(stockedProductStock, 0.001),
      reason:
          'borrar la orden debe devolver el stock consumido (corrección A6 '
          'del backend)',
    );
  }

  // El corte de la sesión de prueba lo hace el `addTearDown` registrado arriba
  // (se ejecuta aunque el escenario falle); aquí solo se cierra la sesión.
  if (!openedHere) {
    await auth.logout();
  }
}

/// Impresión y WhatsApp de una **orden de servicio real** (etapa 6).
///
/// Comprueba dos cosas del contrato §10:
/// 1. El ticket de la orden se codifica bien con `service_order` (ESC/POS y HTML).
/// 2. `POST /print/whatsapp-ticket` **no** arma el ticket de una orden
///    (`service_order` responde `200` con `ticket: null`): la app envía el de su
///    **venta vinculada**, que aquí también se verifica.
Future<void> _liveOrderPrintingRoundTrip({
  required ApiClient api,
  required int orderId,
}) async {
  final printing = PrintingRepository(api: api);
  final templates = await printing.fetchAllTemplates();

  final ticketTemplate = templates
      .where((template) => template.type == PrintTemplateType.saleTicket.wire)
      .toList(growable: false);

  if (ticketTemplate.isEmpty) {
    debugPrint('[live] la suscripción no tiene plantillas: sin impresión');

    return;
  }

  final orderPayload = await printing.bluetoothPayload(
    templateId: ticketTemplate.first.id,
    source: PrintDataSourceType.serviceOrder,
    sourceId: orderId,
  );

  debugPrint(
    '[live] ESC/POS orden=$orderId plantilla=${ticketTemplate.first.id} '
    'bytes=${orderPayload.byteCount} inicio=${orderPayload.commands.take(4).toList()}',
  );

  expect(orderPayload.isEmpty, isFalse);
  expect(orderPayload.commands.first, 0x1B);

  final html = await printing.ticketHtml(
    templateId: ticketTemplate.first.id,
    source: PrintDataSourceType.serviceOrder,
    sourceId: orderId,
  );

  debugPrint('[live] respaldo HTML de la orden: ${html.html.length} caracteres');
  expect(html.isEmpty, isFalse);

  // Hallazgo de la etapa 6: el ticket de WhatsApp solo existe para ventas.
  final directTicket = await printing.whatsappTicket(
    source: PrintDataSourceType.serviceOrder,
    sourceId: orderId,
  );

  debugPrint(
    '[live] WhatsApp service_order=$orderId '
    'ticket=${directTicket.ticket == null ? 'null' : directTicket.ticket!['kind']} '
    'telefono=${directTicket.customerPhone ?? 'sin telefono'}',
  );

  expect(directTicket.isEmpty, isTrue);

  // La app resuelve el WhatsApp con la venta vinculada de la orden.
  final detail = await ServiceOrdersRepository(api: api).fetchServiceOrder(orderId);
  final linkedTransactionId = detail.transaction?.id;

  if (linkedTransactionId == null) {
    debugPrint('[live] la orden no tiene venta vinculada: sin WhatsApp');

    return;
  }

  final linkedTicket = await printing.whatsappTicket(
    source: PrintDataSourceType.transaction,
    sourceId: linkedTransactionId,
  );

  expect(linkedTicket.isEmpty, isFalse);

  final message = WhatsAppMessageBuilder.build(linkedTicket.ticket!);

  debugPrint(
    '[live] WhatsApp venta vinculada=$linkedTransactionId '
    'kind=${linkedTicket.ticket!['kind']} lineas=${message.split('\n').length}',
  );
  debugPrint('[live] primer renglon: ${message.split('\n').first}');

  expect(message, contains('*'));
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

  if (activeSession == null && current.canJoinShift) {
    // Igual que la pestaña Caja: sin terminal libre se entra al turno abierto
    // («Unirme») en vez de abandonar el escenario.
    activeSession = await cash.joinSession(current.joinableSessions.first.id);

    debugPrint(
      '[live] apartado: unido al turno id=${activeSession.id} '
      'terminal=${activeSession.cashRegisterName}',
    );
  }

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

  // El apartado recién creado sale en la consulta que usa «Deudas por vencer»
  // (D4, 2026-09-20): dos estatus en una sola llamada, sin abrir el historial
  // sin filtro. Es la prueba real de que el servidor aplica **los dos**.
  final debts = await sales.fetchTransactions(
    filters: const TransactionFilters(
      statuses: <String>['apartado', 'pendiente'],
    ),
    perPage: 100,
  );

  final debtsIncludeLayaway = debts.items.any(
    (item) => item.id == layaway.transaction.id,
  );

  debugPrint(
    '[live] deudas por vencer tras crear el apartado: total=${debts.total} '
    'estatus=${debts.items.map((item) => item.status).toSet().join(', ')} '
    'incluyeElApartado=$debtsIncludeLayaway',
  );

  expect(
    debts.items.every(
      (item) => item.status == 'apartado' || item.status == 'pendiente',
    ),
    isTrue,
    reason: 'la API debe aplicar los dos estatus, no solo el último',
  );
  expect(
    debtsIncludeLayaway,
    isTrue,
    reason: 'el apartado recién creado debe salir en «deudas por vencer»',
  );

  // Corrección A3 del backend (2026-09-20, contrato §14): el saldo a favor del
  // cliente solo se aplica cuando el request lo pide (`use_balance: true`) y la
  // app lo manda en `false`, así que crear el apartado no debe tocarlo (antes el
  // servidor lo aplicaba solo, hallazgo 10).
  final usedBalanceOnLayaway = layaway.transaction.totalPaid > 0.01;

  debugPrint(
    '[live] apartado con pagos iniciales=${layaway.transaction.totalPaid} '
    '(el payload no manda ninguno, así que debe ser 0.00)',
  );

  expect(
    usedBalanceOnLayaway,
    isFalse,
    reason:
        'el saldo a favor no debe aplicarse sin `use_balance: true` '
        '(corrección A3 del backend)',
  );

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

  // Correcciones A1/A3 del backend (2026-09-20, contrato §14): editar o borrar
  // un pago vuelve a conciliar `customers.balance` (el `DELETE` revierte el
  // `payDebt` con su `addDebt` simétrico) y el saldo a favor solo se aplica con
  // `use_balance: true` (la app lo manda en `false`). La cadena completa queda,
  // por tanto, **simétrica**: el cliente termina con el saldo que tenía antes.
  //
  // Antes de la corrección esto dejaba el importe del pago borrado a favor del
  // cliente (`+$1.00` por corrida) y la prueba lo caracterizaba; ahora se exige
  // el comportamiento corregido.
  if (usedBalanceOnLayaway) {
    debugPrint(
      '[live] el apartado consumió saldo a favor del cliente: '
      'saldo final ${Money.format(customerAfter.customer.balance)}',
    );
  } else {
    debugPrint(
      '[live] saldo del cliente tras la cadena completa: '
      '${Money.format(customerAfter.customer.balance)} '
      '(antes de la cadena ${Money.format(customerBefore.customer.balance)})',
    );

    expect(
      customerAfter.customer.balance,
      closeTo(customerBefore.customer.balance, 0.01),
      reason:
          'la cadena abono → edición → borrado → cancelación debe dejar el '
          'saldo del cliente como estaba (correcciones A1/A3 del backend)',
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

    final closed = await cash.closeSession(
      sessionId: activeSession.id,
      closingCashBalance: summary.expectedTotal,
      notes: 'Corte de la prueba de humo de la etapa 4',
    );

    // El corte ya lo imprime el servidor (§6.3, B5): el comprobante sirve para
    // imprimir o **reimprimir** el turno y la app solo manda sus operaciones.
    final receipt = await cash.fetchCutReceipt(closed.session.id);

    debugPrint(
      '[live] corte del turno #${receipt.session.id} '
      'cerrado=${receipt.session.isClosed} '
      'plantilla=${receipt.template.label} incorporada=${receipt.template.builtin} '
      'operaciones=${receipt.operations.length} papel=${receipt.paperWidth} '
      'bytes=${receipt.bytes.length} noResueltas=${receipt.unsupportedOperations} '
      'avisos=${receipt.warnings}',
    );
    debugPrint('[live] corte (texto del servidor):\n${receipt.text}');

    expect(receipt.session.id, closed.session.id);
    expect(receipt.session.isClosed, isTrue);
    expect(receipt.operations, isNotEmpty);
    expect(receipt.bytes, isNotEmpty);
    expect(receipt.paperWidth, isNotEmpty);
    expect(receipt.text, isNotEmpty);
    // La plantilla incorporada no tiene id: no hay `template_id` que mandar.
    if (receipt.template.builtin) {
      expect(receipt.template.id, isNull);
      expect(receipt.text, contains('CORTE DE CAJA'));
    }
  }

  await auth.logout();
}

/// Ventas de la sucursal o `null` si el usuario no tiene `transactions.access`.
Future<Paginated<TransactionSummary>?> _liveTransactionsOrNull(
  SalesRepository sales,
) async {
  try {
    return await sales.fetchTransactions(perPage: 1);
  } on ApiException catch (error) {
    debugPrint(
      '[live] /transactions no disponible para este usuario: '
      '${error.statusCode} ${error.message}',
    );

    return null;
  }
}

/// Órdenes de la sucursal o `null` sin `services.orders.access`.
Future<Paginated<ServiceOrderSummary>?> _liveServiceOrdersOrNull(
  ServiceOrdersRepository orders,
) async {
  try {
    return await orders.fetchServiceOrders(perPage: 1);
  } on ApiException catch (error) {
    debugPrint(
      '[live] /service-orders no disponible para este usuario: '
      '${error.statusCode} ${error.message}',
    );

    return null;
  }
}

/// Verifica la **impresión real** de la etapa 6: plantillas del negocio,
/// ESC/POS de una venta, etiqueta TSPL, respaldo HTML y el ticket de WhatsApp.
///
/// No imprime en ninguna impresora (eso depende del teléfono): comprueba que el
/// servidor entrega exactamente los documentos que la app envía por Bluetooth y
/// que el texto de WhatsApp se arma con el mismo formato que la web.
void livePrintingTest() {
  test(
    'impresión real: plantillas, ESC/POS, TSPL, HTML y WhatsApp',
    () async {
      final store = _MemorySessionStore();
      final api = ApiClient(baseUrl: liveBaseUrl, readToken: store.readToken);
      final auth = AuthRepository(api: api, sessionStore: store);
      final printing = PrintingRepository(api: api);

      await auth.login(email: liveEmail, password: livePassword);

      // 1) Plantillas de la suscripción (la app las cachea por tipo/contexto).
      final templates = await printing.fetchAllTemplates(forceRefresh: true);

      debugPrint('[live] plantillas=${templates.length}');
      for (final template in templates) {
        debugPrint(
          '[live]   #${template.id} ${template.name} tipo=${template.type} '
          'contexto=${template.contextType} papel=${template.paperWidth} '
          'default=${template.isDefault}',
        );
        expect(template.id, greaterThan(0));
        expect(template.name, isNotEmpty);
      }

      final ticketTemplates = templates
          .where((template) => template.type == PrintTemplateType.saleTicket.wire)
          .toList(growable: false);
      final labelTemplates = templates
          .where((template) => template.isLabel)
          .toList(growable: false);

      debugPrint(
        '[live] tickets=${ticketTemplates.length} '
        'etiquetas=${labelTemplates.length}',
      );

      // La selección de la app (contextos + ids) debe dejar plantillas útiles.
      final previewDocument = PrintDocument.sale(transactionId: 1);
      final previewSelection = previewDocument.selectTemplates(templates);

      debugPrint(
        '[live] la app selecciona para una venta: '
        '${previewSelection.map((t) => '#${t.id}').join(', ')}',
      );
      expect(previewSelection, isNotEmpty);

      // 2) Venta real de la sucursal.
      final sales = SalesRepository(api: api);
      final page = await _liveTransactionsOrNull(sales);

      final transactionId = livePrintingTransactionId > 0
          ? livePrintingTransactionId
          : (page == null || page.isEmpty ? 0 : page.items.first.id);

      if (transactionId > 0 && ticketTemplates.isNotEmpty) {
        final template = ticketTemplates.first;

        final payload = await printing.bluetoothPayload(
          templateId: template.id,
          source: PrintDataSourceType.transaction,
          sourceId: transactionId,
        );

        debugPrint(
          '[live] ESC/POS venta=$transactionId plantilla=${template.id} '
          'bytes=${payload.byteCount} papel=${payload.paperWidth} '
          'inicio=${payload.commands.take(4).toList()}',
        );

        expect(payload.isEmpty, isFalse);
        expect(payload.commands.first, 0x1B); // ESC @
        expect(payload.byteCount, greaterThan(50));

        final html = await printing.ticketHtml(
          templateId: template.id,
          source: PrintDataSourceType.transaction,
          sourceId: transactionId,
        );

        debugPrint(
          '[live] respaldo HTML "${html.templateName}" '
          '${html.html.length} caracteres',
        );

        expect(html.isEmpty, isFalse);
        expect(html.html, contains('<'));
        expect(html.paperWidth, template.paperWidth);

        final ticket = await printing.whatsappTicket(
          source: PrintDataSourceType.transaction,
          sourceId: transactionId,
        );

        expect(ticket.isEmpty, isFalse);

        final message = WhatsAppMessageBuilder.build(ticket.ticket!);

        debugPrint(
          '[live] WhatsApp kind=${ticket.ticket!['kind']} '
          'telefono=${ticket.customerPhone ?? "sin telefono"} '
          'lineas=${message.split('\n').length}',
        );
        debugPrint('[live] primer renglon: ${message.split('\n').first}');

        expect(message, contains('*'));
        expect(
          WhatsAppMessageBuilder.link(
            phone: ticket.customerPhone,
            message: message,
          ),
          contains('wa.me'),
        );
      } else {
        debugPrint(
          '[live] sin venta o sin plantilla ticket_venta: '
          'no se pudo pedir el ESC/POS de una venta',
        );
      }

      // 3) Orden de servicio: su ticket sí se codifica…
      final orders = ServiceOrdersRepository(api: api);
      final ordersPage = await _liveServiceOrdersOrNull(orders);
      final serviceOrderId = livePrintingServiceOrderId > 0
          ? livePrintingServiceOrderId
          : (ordersPage == null || ordersPage.isEmpty
                ? 0
                : ordersPage.items.first.id);

      if (serviceOrderId > 0 && ticketTemplates.isNotEmpty) {
        final orderPayload = await printing.bluetoothPayload(
          templateId: ticketTemplates.first.id,
          source: PrintDataSourceType.serviceOrder,
          sourceId: serviceOrderId,
        );

        debugPrint(
          '[live] ESC/POS orden=$serviceOrderId bytes=${orderPayload.byteCount} '
          'inicio=${orderPayload.commands.take(4).toList()}',
        );

        expect(orderPayload.isEmpty, isFalse);

        // El ticket de WhatsApp de una orden de servicio ya se arma en el
        // servidor (antes respondía `200` con `ticket: null`).
        final orderTicket = await printing.whatsappTicket(
          source: PrintDataSourceType.serviceOrder,
          sourceId: serviceOrderId,
        );

        debugPrint(
          '[live] WhatsApp orden=$serviceOrderId '
          'ticket=${orderTicket.isEmpty ? 'null' : orderTicket.ticket!['kind']} '
          'telefono=${orderTicket.customerPhone ?? "sin telefono"}',
        );

        expect(orderTicket.isEmpty, isFalse);
        expect(orderTicket.ticket!['kind'], 'service_order');
        expect(WhatsAppMessageBuilder.build(orderTicket.ticket!), isNotEmpty);
      } else {
        debugPrint('[live] sin órdenes de servicio para probar la impresión');
      }

      // 3b) Un origen sin ticket de WhatsApp responde `422 no_whatsapp_ticket`
      // (antes respondía `200` con `ticket: null` y la app creía que había
      // enviado algo).
      final customerPage = await CustomersRepository(
        api: api,
      ).fetchCustomers(perPage: 1);

      if (customerPage.isEmpty) {
        debugPrint('[live] sin clientes: no se probó el 422 de WhatsApp');
      } else {
        final noTicket = await _capture(
          () => printing.whatsappTicket(
            source: PrintDataSourceType.customer,
            sourceId: customerPage.items.first.id,
          ),
        );

        debugPrint(
          '[live] WhatsApp de un cliente: ${noTicket.statusCode} '
          '${noTicket.code} ${noTicket.message}',
        );

        expect(noTicket.statusCode, 422);
        expect(noTicket.code, 'no_whatsapp_ticket');
      }

      // 3c) El corte de caja: si hay un turno abierto, el comprobante se puede
      // pedir e imprimir con las mismas operaciones que devuelve el servidor.
      final cash = CashRegisterRepository(api: api);
      final snapshot = await cash.fetchCurrent();
      final sessionId = snapshot.activeSession?.id;

      if (sessionId == null) {
        debugPrint(
          '[live] sin turno abierto: el corte se valida en la prueba de caja '
          '(LIVE_POS=true) y en la de dispositivo',
        );
      } else {
        final receipt = await cash.fetchCutReceipt(sessionId);

        debugPrint(
          '[live] corte del turno abierto #$sessionId '
          'plantilla=${receipt.template.label} '
          'operaciones=${receipt.operations.length} bytes=${receipt.bytes.length} '
          'papel=${receipt.paperWidth} avisos=${receipt.warnings}',
        );

        expect(receipt.session.id, sessionId);
        expect(receipt.session.isClosed, isFalse);
        expect(receipt.bytes, isNotEmpty);
        expect(receipt.text, isNotEmpty);
      }

      // 4) Etiqueta (TSPL) de un producto real.
      final labelTemplate = labelTemplates.isEmpty
          ? null
          : labelTemplates.first;

      if (labelTemplate != null) {
        final products = await CatalogRepository(
          api: api,
        ).fetchProducts(perPage: 1);
        final productId = products.isEmpty ? 0 : products.items.first.id;

        if (productId > 0) {
          final label = await printing.labelPayload(
            templateId: labelTemplate.id,
            source: PrintDataSourceType.product,
            sourceId: productId,
          );

          debugPrint(
            '[live] TSPL plantilla=${labelTemplate.id} producto=$productId '
            'operaciones=${label.operations.length} '
            'noResueltas=${label.unsupportedOperations} '
            'avisos=${label.warnings}',
          );
          debugPrint('[live] TSPL:\n${label.tsplText}');

          expect(label.tsplText, isNotNull);
          expect(label.tsplText, contains('PRINT'));
          // El servidor rasteriza las imágenes (BITMAP) y rellena el código de
          // barras: nunca sale un `BARCODE …,2,2,""` vacío (B6).
          expect(
            label.tsplText!.contains('BARCODE'),
            isTrue,
            reason: 'la plantilla de prueba imprime un código de barras',
          );
          expect(label.tsplText, isNot(contains(',""')));
        }
      } else {
        debugPrint(
          '[live] el negocio no tiene plantillas de etiqueta: '
          'no se probó `POST /print/payload` (TSPL)',
        );
      }

      await auth.logout();
    },
    skip: (liveEmail.isNotEmpty && livePassword.isNotEmpty && livePrinting)
        ? false
        : 'Requiere LIVE_API_EMAIL/LIVE_API_PASSWORD y LIVE_PRINTING=true',
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'cuenta real: notificaciones, soporte, perfil y suscripción',
    () async {
      final store = _MemorySessionStore();
      final api = ApiClient(baseUrl: liveBaseUrl, readToken: store.readToken);
      final auth = AuthRepository(api: api, sessionStore: store);
      final account = AccountRepository(api: api);

      final session = await auth.login(
        email: liveEmail,
        password: livePassword,
      );

      // La cuenta de prueba debe ser propietaria (o empleado, según el flag).
      expect(session.context.user.isSubscriptionOwner, liveExpectOwner);

      // 1) Contadores de la campana (`GET /notifications`).
      final counters = await account.fetchNotifications();

      debugPrint(
        '[live] notificaciones: total=${counters.total} '
        'deudas=${counters.expiringDebts} '
        'entregas=${counters.upcomingDeliveries} '
        'novedades=${counters.unreadUpdates} '
        'pedidos=${counters.pendingOrders} '
        'tiendaEnLinea=${counters.modules.onlineStore}',
      );

      expect(counters.total, greaterThanOrEqualTo(0));
      expect(
        counters.total,
        counters.expiringDebts +
            counters.upcomingDeliveries +
            counters.unreadUpdates +
            counters.pendingOrders,
        reason: 'el total lo suma el servidor con los cuatro contadores',
      );

      // La app oculta el contador de pedidos de la tienda en línea cuando el
      // módulo no está contratado (D3): el servidor dice qué módulos tiene.
      expect(
        counters.isCategoryVisible(NotificationCategory.pendingOrders),
        counters.modules.onlineStore,
      );

      if (!counters.modules.onlineStore) {
        expect(
          counters.pendingOrders,
          0,
          reason: 'sin tienda en línea contratada el contador siempre es 0',
        );
      }

      // 2) Centro de soporte (`GET /support`).
      final support = await account.fetchSupport();

      debugPrint(
        '[live] soporte: "${support.title}" horarios=${support.schedule.length} '
        'canales=${support.channels.map((channel) => channel.display).join(' | ')} '
        'temas=${support.helpTopics.length} ayuda=${support.helpCenterUrl}',
      );

      expect(support.title, isNotEmpty);
      expect(support.channels, isNotEmpty);
      expect(support.helpCenterUrl, isNotNull);

      // 3) Perfil (`GET /profile`).
      final profile = await account.fetchProfile();

      debugPrint(
        '[live] perfil: id=${profile.id} correo=${profile.email} '
        'verificado=${profile.isEmailVerified} fotoPropia=${profile.hasPhoto} '
        'urlFoto=${profile.profilePhotoUrl}',
      );

      expect(profile.id, session.context.user.id);
      expect(profile.email.toLowerCase(), liveEmail.toLowerCase());
      expect(
        profile.realPhotoUrl,
        isNull,
        reason: 'sin `has_photo` la app no debe pintar el avatar generado',
      );
    },
    skip: (liveEmail.isNotEmpty && livePassword.isNotEmpty && liveAccount)
        ? false
        : 'Requiere LIVE_API_EMAIL/LIVE_API_PASSWORD y LIVE_ACCOUNT=true',
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'suscripción real: plan, historial y escrituras reversibles',
    () async {
      final store = _MemorySessionStore();
      final api = ApiClient(baseUrl: liveBaseUrl, readToken: store.readToken);
      final auth = AuthRepository(api: api, sessionStore: store);
      final account = AccountRepository(api: api);

      final session = await auth.login(
        email: liveEmail,
        password: livePassword,
      );
      final owner = session.context.user.isSubscriptionOwner;

      if (!owner) {
        // El empleado recibe 403: se muestra el mensaje del servidor tal cual.
        final denied = await _capture(() => account.fetchSubscription());

        debugPrint(
          '[live] empleado sin suscripción: ${denied.statusCode} '
          '${denied.message}',
        );

        expect(denied.statusCode, 403);
        expect(denied.message, isNotEmpty);

        await auth.logout();

        return;
      }

      final overview = await account.fetchSubscription();
      final first = overview.history.isEmpty ? null : overview.history.first;

      debugPrint(
        '[live] suscripción: ${overview.subscription.commercialName} '
        'estado=${overview.statusData.label} '
        'vence=${overview.statusData.expiresLabel} '
        'módulos=${overview.plan.modules.length} '
        'límites=${overview.plan.limits.length} '
        'historial=${overview.history.length}',
      );

      if (first != null) {
        debugPrint(
          '[live] última versión: v${first.version} ${first.createdAt} '
          'total=${first.amountLabel} estatus=${first.payment?.status.label} '
          'puedeFactura=${first.canRequestInvoice} idPago=${first.payment?.id}',
        );

        expect(first.total, isNotNull);
        // D1 (2026-09-20): el historial trae el id del pago, que es el que exige
        // `POST /subscription/payments/{paymentId}/request-invoice`.
        if (first.canRequestInvoice) {
          expect(
            first.payment?.id,
            isNotNull,
            reason: 'un pago facturable debe traer su id',
          );
          expect(first.payment!.isInvoiceRequestable, isTrue);
          expect(first.payment!.id, greaterThan(0));
        }
      }

      expect(overview.subscription.commercialName, isNotEmpty);
      expect(overview.plan.modules, isNotEmpty);

      if (!liveAccountWrite) {
        await auth.logout();

        return;
      }

      // --- Escrituras reversibles -------------------------------------------

      // Guardar el perfil con los mismos datos: no cambia nada.
      final profile = await account.fetchProfile();
      final saved = await account.updateProfile(
        name: profile.name,
        email: profile.email,
      );

      debugPrint(
        '[live] perfil guardado: "${saved.message}" '
        'verificaciónEnviada=${saved.emailVerificationSent}',
      );

      expect(saved.message, isNotEmpty);
      expect(saved.emailVerificationSent, isFalse);

      // Contraseña actual incorrecta: `422 invalid_current_password`.
      final wrongPassword = await _capture(
        () => account.updatePassword(
          currentPassword: 'incorrecta-de-prueba',
          password: 'nueva123456',
          passwordConfirmation: 'nueva123456',
        ),
      );

      debugPrint(
        '[live] contraseña incorrecta: ${wrongPassword.statusCode} '
        '${wrongPassword.code} ${wrongPassword.message}',
      );

      expect(wrongPassword.statusCode, 422);
      expect(wrongPassword.code, 'invalid_current_password');

      // Cerrar otras sesiones con contraseña incorrecta: mismo error.
      final wrongLogout = await _capture(
        () => account.logoutOtherDevices('incorrecta-de-prueba'),
      );

      debugPrint(
        '[live] cerrar sesiones sin contraseña válida: '
        '${wrongLogout.statusCode} ${wrongLogout.message}',
      );

      expect(wrongLogout.statusCode, 422);
      expect(wrongLogout.code, 'invalid_current_password');

      // Documento fiscal que no es PDF ni imagen → `422` con el message.
      final wrongDocument = await _capture(
        () => account.uploadFiscalDocument(
          EvidenceImage.fromBytes(
            fileName: 'constancia.txt',
            bytes: Uint8List.fromList(utf8.encode('no soy un pdf')),
          ),
        ),
      );

      debugPrint(
        '[live] documento inválido: ${wrongDocument.statusCode} '
        '${wrongDocument.message}',
      );

      expect(wrongDocument.statusCode, 422);
      expect(wrongDocument.errorFor('fiscal_document'), isNotNull);

      // Factura de un pago inexistente → `404 Recurso no encontrado.`
      final missingInvoice = await _capture(
        () => account.requestInvoice(999999),
      );

      debugPrint(
        '[live] factura inexistente: ${missingInvoice.statusCode} '
        '${missingInvoice.message}',
      );

      expect(missingInvoice.statusCode, 404);

      if (liveAccountInvoicePaymentId > 0) {
        final invoice = await account.requestInvoice(
          liveAccountInvoicePaymentId,
        );

        debugPrint('[live] factura solicitada: ${invoice.message}');

        expect(invoice.message, isNotEmpty);
      }

      // Foto de perfil: sin foto propia el borrado es inocuo; con foto solo se
      // borra si se pide con `LIVE_ACCOUNT_DELETE_PHOTO=true`.
      if (!profile.hasPhoto && !liveAccountDeletePhoto) {
        final deleted = await account.deleteProfilePhoto();

        debugPrint('[live] foto eliminada (no había foto): ${deleted.message}');

        expect(deleted.profile.hasPhoto, isFalse);
      } else if (liveAccountDeletePhoto) {
        final deleted = await account.deleteProfilePhoto();

        debugPrint('[live] foto eliminada: ${deleted.message}');

        expect(deleted.message, isNotEmpty);
      } else {
        debugPrint(
          '[live] la cuenta tiene foto: se omite el borrado '
          '(usa LIVE_ACCOUNT_DELETE_PHOTO=true para probarlo)',
        );
      }

      // Guardar la suscripción con los mismos datos generales.
      final updated = await account.updateSubscription(
        overview.subscription.toUpdatePayload(),
      );

      debugPrint('[live] suscripción guardada: ${updated.message}');

      expect(updated.message, isNotEmpty);

      await auth.logout();
    },
    skip: (liveEmail.isNotEmpty && livePassword.isNotEmpty && liveAccount)
        ? false
        : 'Requiere LIVE_API_EMAIL/LIVE_API_PASSWORD y LIVE_ACCOUNT=true',
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'cambio de sucursal real: ida y vuelta al contexto original',
    () async {
      final store = _MemorySessionStore();
      final api = ApiClient(baseUrl: liveBaseUrl, readToken: store.readToken);
      final auth = AuthRepository(api: api, sessionStore: store);
      final account = AccountRepository(api: api);

      final session = await auth.login(
        email: liveEmail,
        password: livePassword,
      );
      final branches = session.context.availableBranches;
      final original = session.context.currentBranch;

      debugPrint(
        '[live] sucursales: ${branches.map((branch) => '${branch.id}:${branch.name}${branch.isCurrent ? ' (activa)' : ''}').join(', ')}',
      );

      expect(original, isNotNull);

      final other = branches.where((branch) => !branch.isCurrent).toList();

      if (other.isEmpty) {
        debugPrint(
          '[live] el usuario tiene una sola sucursal: no se prueba el cambio',
        );

        await auth.logout();

        return;
      }

      final target = other.first;
      final switched = await account.switchBranch(target.id);

      debugPrint(
        '[live] cambio a ${target.label}: "${switched.message}" '
        'activa=${switched.context.currentBranch?.label} '
        'cajas=${switched.context.availableCashRegisters.map((register) => register.name).join(', ')} '
        'turno=${switched.context.hasActiveSession}',
      );

      expect(switched.context.currentBranch?.id, target.id);
      expect(switched.context.user.branchId, target.id);

      // Se regresa a la sucursal original para dejar la cuenta como estaba.
      final restored = await account.switchBranch(original!.id);

      debugPrint(
        '[live] de vuelta a ${original.label}: "${restored.message}" '
        'activa=${restored.context.currentBranch?.label}',
      );

      expect(restored.context.currentBranch?.id, original.id);

      await auth.logout();
    },
    skip: (liveEmail.isNotEmpty && livePassword.isNotEmpty && liveAccountBranch)
        ? false
        : 'Requiere LIVE_API_EMAIL/LIVE_API_PASSWORD y LIVE_ACCOUNT_BRANCH=true',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

