// Prueba de dispositivo (etapa 8): recorre la app real en un telefono Android
// contra la API real. Se ejecuta con el telefono conectado:
//
//   flutter test integration_test/qa_device_test.dart -d <serial> ^
//     --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 ^
//     --dart-define=API_HOST_HEADER=ezyventas2.test ^
//     --dart-define=LIVE_API_EMAIL=propietario@negocio.com ^
//     --dart-define=LIVE_API_PASSWORD=... ^
//     --dart-define=LIVE_EMPLOYEE_EMAIL=empleado@negocio.com ^
//     --dart-define=LIVE_EMPLOYEE_PASSWORD=...
//
// Verifica los puntos 1 y 2 del checklist de QA (login/logout con token
// persistente y pestanas visibles segun los modulos y permisos que devuelve el
// servidor) y el recorrido de los flujos que MIUI no deja manejar a mano (la
// inyeccion de `adb input` falla con `INJECT_EVENTS`): POS -> carrito -> cobro,
// turno de caja, detalle de ventas y ordenes, e impresion (hoja de impresion y
// el estado real del Bluetooth del telefono). El ultimo escenario si usa la
// impresora fisica: conecta la termica del telefono (emparejada o escaneada) y
// le manda el ticket ESC/POS del servidor. No sustituye a las corridas de
// `test/live/api_smoke_test.dart`: complementa lo que solo se puede comprobar en
// el telefono.
import 'package:ezyventas_app/app.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/core/config/app_config.dart';
import 'package:ezyventas_app/core/printing/bluetooth_printer_service.dart';
import 'package:ezyventas_app/core/widgets/app_drawer_scope.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/features/account/presentation/account_screen.dart';
import 'package:ezyventas_app/features/cash/presentation/cash_register_screen.dart';
import 'package:ezyventas_app/features/catalog/presentation/widgets/product_card.dart';
import 'package:ezyventas_app/features/pos/presentation/widgets/cart_bar.dart';
import 'package:ezyventas_app/features/printing/application/printer_controller.dart';
import 'package:ezyventas_app/features/sales/presentation/widgets/transaction_tile.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_tile.dart';
import 'package:ezyventas_app/features/shell/presentation/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

const String ownerEmail = String.fromEnvironment('LIVE_API_EMAIL');
const String ownerPassword = String.fromEnvironment('LIVE_API_PASSWORD');
const String employeeEmail = String.fromEnvironment('LIVE_EMPLOYEE_EMAIL');
const String employeePassword = String.fromEnvironment(
  'LIVE_EMPLOYEE_PASSWORD',
);

/// Entradas que el menú lateral ofrece al usuario con todos los módulos
/// contratados (`AppTab.values` en orden, más las acciones).
///
/// Vender y Caja **sí** están: desde que la navegación vive en el menú lateral no
/// hay barra inferior que reparta huecos, así que todas las pestañas se listan
/// igual.
const List<String> shellMenu = <String>[
  'Inicio',
  'Vender',
  'Órdenes',
  'Caja',
  'Ventas',
  'Cuenta',
];

/// Acciones del menú lateral que el recorrido usa para empezar una venta o
/// entrar a Caja.
const String newSaleAction = 'Nueva venta';
const String cashAction = 'Caja';

/// Primer texto de la pestaña Inicio (destino por defecto tras el login).
const String welcomeTitle = '¡Bienvenido!';

/// Textos de `AccountLabels` que dependen del usuario (§14.2).
///
/// Ojo con [branchCardTitle]: `SectionCard` pinta los títulos en
/// micro-mayúsculas (`title!.toUpperCase()`), así que el texto que realmente
/// existe en el árbol es `SUCURSAL ACTIVA` y hay que comparar en mayúsculas
/// (ver `_openAccount`).
const String branchCardTitle = 'Sucursal activa';
const String subscriptionOption = 'Mi suscripción';
const String changeBranchAction = 'Cambiar de sucursal';
const String noBranchPermission = 'Tu usuario no puede cambiar de sucursal.';
const String logoutLabel = 'Cerrar sesión';
const String loginAction = 'Iniciar sesión';

/// Anclas del recorrido de flujos (POS, caja, ventas y órdenes).
///
/// Ojo con las micro-mayúsculas: `SectionCard`, `FieldLabel` y `StatusBadge`
/// pintan su texto en mayúsculas (`title!.toUpperCase()`, `label.toUpperCase()`),
/// así que esos textos se comparan en mayúsculas (igual que [branchCardTitle]) y
/// aquí solo se usan etiquetas de botón, de campo o textos sueltos.
const String shiftOpenPrefix = 'Turno abierto en ';
const String shiftClosedSubtitle = 'Sin turno abierto';
const String closeShiftLabel = 'Hacer corte';
const String closeShiftTitle = 'Corte de caja';
const String closeShiftContinueLabel = 'Continuar';
const String startShiftLabel = 'Iniciar turno';
const String joinShiftLabel = 'Unirme';
const String resumeShiftLabel = 'Retomar';
const String shiftUnavailableTitle =
    'Pide que abran caja desde la versión web.';

const String addToCartLabel = 'Agregar al carrito';
const String noStockNotice = 'El producto ya no tiene stock suficiente.';
const String noPermissionNotice =
    'Tu usuario no tiene permiso para esta acción.';
const String cartBarEmpty = 'Carrito vacío';

/// El acceso al carrito con algo dentro: desde que el chevron sustituyó a la
/// pastilla «Ver carrito» (le robaba al total el ancho de un renglón), el ancla
/// de la barra es la flecha, dentro de la barra y no en cualquier lista.
final Finder cartBarChevron = find.descendant(
  of: find.byType(CartBar),
  matching: find.byIcon(Icons.chevron_right),
);

const String cartTitle = 'Carrito';
const String cartTotalsCard = 'TOTALES';
const String clearCartLabel = 'Vaciar carrito';
const String checkoutLabel = 'Cobrar';
const String paymentTitle = 'Cobro';
const String paymentTotalsCard = 'TOTAL DE LA VENTA';
const String finishSaleLabel = 'Finalizar venta';
const String needsCustomerNotice =
    'Selecciona un cliente para dejar saldo pendiente.';

const String salesEmptyTitle = 'Aún no hay ventas registradas.';
const String salesEmptyMessage =
    'Las ventas que cobres en la app aparecerán aquí.';
const String ordersEmptyTitle = 'No hay órdenes de servicio';
const String ordersEmptyMessage =
    'Cuando registres una orden aparecerá aquí con su estatus y '
    'saldo pendiente.';

const String printSheetTitle = 'Imprimir y compartir';
const String printTicketLabel = 'Imprimir ticket';
const String printOrderLabel = 'Imprimir orden';
const String printerConnectedBadge = 'CONECTADA';
const String printerDisconnectedBadge = 'SIN CONECTAR';
const String closeDetailTooltip = 'Cerrar';

/// Impresora térmica real de la corrida en el teléfono.
///
/// El nombre es el que anuncia la impresora (p. ej. `BY-480BT_05AC`) y se pasa
/// con `--dart-define=LIVE_PRINTER_NAME=...`. Sin ese define la prueba solo
/// enumera lo que ve el teléfono (emparejadas + escaneo) y se omite.
const String livePrinterName = String.fromEnvironment('LIVE_PRINTER_NAME');

/// Anclas del flujo de impresión real.
const String printerConnectedPrefix = 'Impresora conectada: ';
const String printerIdleStatus = 'Sin impresora conectada';
const String choosePrinterTitle = 'Elegir impresora';
const String findPrintersLabel = 'Buscar impresoras';
const String connectSavedPrinterLabel = 'Conectar impresora';
const String ticketSentNotice = 'Ticket enviado a la impresora.';

const Timeout _deviceTimeout = Timeout(Duration(minutes: 4));
const Timeout _flowsTimeout = Timeout(Duration(minutes: 8));

Future<void> main() async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Mismo arranque que `main.dart`: formato es-MX en toda la app.
  Intl.defaultLocale = AppConfig.locale;
  await initializeDateFormatting(AppConfig.locale);

  testWidgets('propietario: login real, pestanas y cierre de sesion', (
    tester,
  ) async {
    await _startClean(tester);

    // 1) Login real contra la API.
    await _login(tester, ownerEmail, ownerPassword);

    // 2) Entradas reales del menú lateral (permisos + módulos del login).
    await _expectMenu(tester, shellMenu);

    // 3) La pestaña por defecto es Inicio: la bienvenida.
    await _waitFor(
      tester,
      find.text(welcomeTitle),
      reason: 'Tras el login no apareció la pestaña Inicio',
    );

    // 4) El POS se abre desde el menú del FAB («Nueva venta»): su catálogo real
    // tiene que cargar. Si una tarjeta desbordara su reja, el
    // `RenderFlex overflowed` fallaría aquí (fue el caso real del teléfono antes
    // del arreglo de `product_card.dart`).
    await _openMenuAction(tester, newSaleAction);
    await _waitFor(tester, find.text('Buscar por nombre o SKU…'));
    await _waitFor(
      tester,
      find.byType(ProductCard),
      timeout: const Duration(seconds: 30),
      reason: 'El catálogo no mostró productos de la sucursal',
    );

    // 5) Cuenta de propietario: suscripcion y cambio de sucursal.
    await _openAccount(tester);

    // El propietario si ve la suscripcion. Se exige "al menos una" porque el
    // aviso de suscripcion (`NoticeBanner`) usa la misma etiqueta como accion.
    expect(find.text(subscriptionOption), findsAtLeastNWidgets(1));
    expect(find.text(changeBranchAction), findsOneWidget);

    // 4) Cierre de sesion: vuelve al login.
    await _logout(tester);
    expect(find.text(loginAction), findsOneWidget);
    expect(find.text(changeBranchAction), findsNothing);
  }, timeout: _deviceTimeout);

  testWidgets('empleado: mismas pestanas, sin suscripcion ni sucursal', (
    tester,
  ) async {
    await _startClean(tester);
    await _login(tester, employeeEmail, employeePassword);

    // El empleado limitado conserva las entradas de su trabajo...
    await _expectMenu(tester, shellMenu);

    // ...pero no ve la suscripcion (no es propietario) ni puede cambiar de
    // sucursal (sin `system.branches.switch`).
    await _openAccount(tester);
    expect(find.text(subscriptionOption), findsNothing);
    expect(find.text(noBranchPermission), findsOneWidget);
    expect(find.text(changeBranchAction), findsNothing);

    await _logout(tester);
    expect(find.text(loginAction), findsOneWidget);
  }, timeout: _deviceTimeout);

  testWidgets('propietario: POS, caja, ventas, ordenes e impresion', (
    tester,
  ) async {
    await _startClean(tester);
    await _login(tester, ownerEmail, ownerPassword);

    // 1) Caja: estado real del turno. No se abre ni se cierra ninguno: si hay
    // turno se entra al corte, se comprueba que el resumen llego del servidor y
    // se descarta tocando el velo (el `POST` de cierre nunca se envia). Caja vive
    // en el menú del FAB porque la barra pinta Inicio · Órdenes · Ventas · Cuenta.
    await _openMenuAction(tester, cashAction);
    await _waitFor(tester, find.byType(CashRegisterScreen));

    final shiftState = await _waitForAny(tester, <Finder>[
      find.textContaining(shiftOpenPrefix),
      find.text(shiftClosedSubtitle),
    ], timeout: const Duration(seconds: 30));
    expect(
      shiftState,
      isNot(-1),
      reason: 'La pestaña Caja no mostró el estado del turno',
    );

    if (shiftState == 0) {
      // `Hacer corte` vive al final del `ListView` perezoso de la pestaña.
      await _scrollTo(
        tester,
        find.text(closeShiftLabel),
        screen: CashRegisterScreen,
      );
      await tester.tap(find.text(closeShiftLabel));
      await _waitFor(
        tester,
        find.text(closeShiftTitle),
        timeout: const Duration(seconds: 30),
        reason: 'No abrió el corte de caja',
      );
      // El resumen del turno (`GET .../summary`) habilita el arqueo.
      await _waitFor(tester, find.text(closeShiftContinueLabel));
      await _dismissSheet(tester);
    } else {
      // Sin turno: la pestaña ofrece abrirlo, unirse a uno abierto o avisa que
      // se abre desde la web. Ninguna de las tres se ejecuta.
      final setup = await _waitForAny(tester, <Finder>[
        find.text(startShiftLabel),
        find.text(joinShiftLabel),
        find.text(resumeShiftLabel),
        find.text(shiftUnavailableTitle),
      ], timeout: const Duration(seconds: 30));
      expect(
        setup,
        isNot(-1),
        reason: 'La pestaña Caja no ofreció ninguna salida sin turno',
      );
    }

    // 2) POS: catalogo real -> detalle -> carrito -> cobro.
    await _openMenuAction(tester, newSaleAction);
    await _waitFor(
      tester,
      find.byType(ProductCard),
      timeout: const Duration(seconds: 30),
      reason: 'El catálogo no mostró productos de la sucursal',
    );

    // El sheet abre con los datos de la tarjeta y se completa con
    // `GET /catalog/products/{id}`. La seccion de venta vive al final del
    // `ListView`, por eso se sondea bajando (es perezoso).
    await tester.ensureVisible(find.byType(ProductCard).first);
    await tester.pump();
    await tester.tap(find.byType(ProductCard).first);

    final detailAnchors = <Finder>[
      find.text(addToCartLabel),
      find.text(noStockNotice),
      find.text(noPermissionNotice),
    ];
    final detailState = await _waitScrollingAny(
      tester,
      detailAnchors,
      timeout: const Duration(seconds: 25),
    );
    expect(
      detailState,
      isNot(-1),
      reason: 'El detalle del producto no mostró su sección de venta',
    );

    final added = detailState == 0;

    if (added) {
      // Agregar al carrito es local (sin servidor) y cierra el sheet solo.
      await tester.tap(find.text(addToCartLabel));
      expect(
        await _waitForGone(tester, find.text(addToCartLabel)),
        isTrue,
        reason: 'El detalle del producto no se cerró al agregar al carrito',
      );
      await _waitFor(tester, cartBarChevron);
      // Hallazgo de la corrida en teléfono: el aviso «... agregado al carrito
      // (1).» es un `SnackBar` pegado al borde inferior que tapa la barra del
      // carrito mientras está visible (~4 s), así que un toque inmediato en el
      // acceso no llega a la barra. Se espera a que se retire.
      expect(
        await _waitForGone(tester, find.byType(SnackBar)),
        isTrue,
        reason: 'El aviso de "agregado al carrito" no se ocultó',
      );
    } else {
      await _dismissSheet(tester);
      await _waitFor(tester, find.text(cartBarEmpty));
    }

    // Carrito: lineas, totales y el candado de la sesión de caja.
    await tester.tap(added ? cartBarChevron : find.text(cartBarEmpty));
    await _waitFor(tester, find.text(cartTitle), reason: 'El carrito no abrió');
    expect(find.text(cartTotalsCard), findsOneWidget);

    final cobrar = find.widgetWithText(EzyButton, checkoutLabel);
    expect(
      await _waitScrolling(tester, cobrar),
      isTrue,
      reason: 'El carrito no mostró el botón de cobro',
    );

    if (added && shiftState == 0) {
      // Con turno abierto el carrito abre el cobro: se comprueba que exige
      // montos capturados y se descarta sin registrar la venta.
      await tester.tap(cobrar);
      await _waitFor(
        tester,
        find.text(paymentTitle),
        timeout: const Duration(seconds: 30),
        reason: 'No abrió el cobro',
      );
      expect(find.text(paymentTotalsCard), findsOneWidget);

      final finish = find.widgetWithText(EzyButton, finishSaleLabel);
      expect(
        await _waitScrolling(tester, finish),
        isTrue,
        reason: 'El cobro no mostró el botón para cerrar la venta',
      );
      expect(
        tester.widget<EzyButton>(finish).onPressed,
        isNull,
        reason: 'El cobro dejó cerrar la venta sin pagos capturados',
      );
      expect(find.text(needsCustomerNotice), findsOneWidget);

      await _dismissSheet(tester);
    } else {
      // Sin turno de caja (o sin lineas) el cobro esta bloqueado en la app.
      expect(
        tester.widget<EzyButton>(cobrar).onPressed,
        isNull,
        reason: 'El cobro se habilitó sin turno de caja o sin lineas',
      );
    }

    // Se deja el carrito limpio: `Vaciar carrito` no toca el servidor.
    final clearCart = find.widgetWithText(EzyButton, clearCartLabel);
    if (tester.widget<EzyButton>(clearCart).onPressed != null) {
      await tester.tap(clearCart);
      await tester.pump(const Duration(milliseconds: 400));
    }

    await _dismissSheet(tester);

    // 3) Ventas: detalle real (folio, cliente, articulos) e impresion.
    await _openMenuAction(tester, 'Ventas');
    final salesState = await _waitForAny(tester, <Finder>[
      find.byType(TransactionTile),
      find.text(salesEmptyTitle),
    ], timeout: const Duration(seconds: 30));
    expect(
      salesState,
      isNot(-1),
      reason: 'La pestaña Ventas no cargó la lista real',
    );

    if (salesState == 0) {
      await tester.tap(find.byType(TransactionTile).first);
      await _printFromDetail(
        tester,
        printButtons: <String>[printTicketLabel, printOrderLabel],
      );
    } else {
      expect(find.text(salesEmptyMessage), findsOneWidget);
    }

    // 4) Órdenes de servicio: mismo recorrido de detalle e impresion.
    await _openMenuAction(tester, 'Órdenes');
    final ordersState = await _waitForAny(tester, <Finder>[
      find.byType(ServiceOrderTile),
      find.text(ordersEmptyTitle),
    ], timeout: const Duration(seconds: 30));
    expect(
      ordersState,
      isNot(-1),
      reason: 'La pestaña Órdenes no cargó la lista real',
    );

    if (ordersState == 0) {
      await tester.tap(find.byType(ServiceOrderTile).first);
      await _printFromDetail(tester, printButtons: <String>[printOrderLabel]);
    } else {
      expect(find.text(ordersEmptyMessage), findsOneWidget);
    }
  }, timeout: _flowsTimeout);

  testWidgets('propietario: impresora térmica real (conexión y ticket)', (
    tester,
  ) async {
    await _startClean(tester);
    await _login(tester, ownerEmail, ownerPassword);

    // 1) Una venta real: su detalle trae el panel de impresión.
    await _openMenuAction(tester, 'Ventas');
    final salesState = await _waitForAny(tester, <Finder>[
      find.byType(TransactionTile),
      find.text(salesEmptyTitle),
    ], timeout: const Duration(seconds: 30));
    expect(
      salesState,
      isNot(-1),
      reason: 'La pestaña Ventas no cargó la lista real',
    );

    if (salesState != 0) {
      markTestSkipped('La cuenta no tiene ventas: no hay ticket que imprimir.');
      return;
    }

    await tester.tap(find.byType(TransactionTile).first);
    await _openPrintSheet(tester, printButtons: <String>[printTicketLabel]);

    // 2) Estado real del adaptador Bluetooth del teléfono dentro de la hoja.
    final printerState = await _waitForAny(tester, <Finder>[
      find.textContaining(printerConnectedPrefix),
      find.text(printerIdleStatus),
    ], timeout: const Duration(seconds: 20));
    expect(
      printerState,
      isNot(-1),
      reason: 'La hoja de impresión no mostró el estado de la impresora',
    );

    if (printerState == 1) {
      final connected = await _connectPrinter(tester);

      if (!connected) {
        // La prueba quedó marcada como omitida con la lista de dispositivos.
        return;
      }
    }

    expect(
      find.textContaining(printerConnectedPrefix),
      findsAtLeastNWidgets(1),
      reason: 'La impresora térmica no quedó conectada',
    );
    expect(
      _inLastSheet(find.text(printerConnectedBadge)),
      findsOneWidget,
      reason: 'La hoja no marcó la impresora como conectada',
    );

    // 3) El ticket ESC/POS que arma el servidor, enviado por Bluetooth.
    final printButton = _inLastSheet(
      find.widgetWithText(EzyButton, printTicketLabel),
    );
    expect(
      await _waitEnabled(
        tester,
        printButton,
        timeout: const Duration(seconds: 25),
      ),
      isTrue,
      reason: 'El servidor no habilitó la impresión del ticket',
    );

    await tester.tap(printButton);
    await _waitFor(
      tester,
      find.text(ticketSentNotice),
      timeout: const Duration(seconds: 45),
      reason:
          'El ticket no se envió a la impresora (revisa el aviso del sheet)',
    );

    // 4) La app queda utilizable: se cierran las hojas abiertas (imprimir y el
    // detalle) con el mismo `pop` que dispara el botón atrás.
    await _closeSheets(tester);
    expect(
      find.text(printSheetTitle),
      findsNothing,
      reason: 'La hoja de impresión no se cerró',
    );
  }, timeout: _deviceTimeout);
}

/// Conecta la impresora térmica desde la hoja de impresión abierta.
///
/// Primero intenta la impresora guardada (reconexión directa, sin escanear) y,
/// si no hay o el teléfono la rechaza, abre el selector para elegirla por nombre
/// entre las emparejadas y las que se anuncian cerca.
///
/// Devuelve `false` cuando la prueba se marcó como omitida (sin
/// `LIVE_PRINTER_NAME`): el llamador debe dejar de comprobar la impresión.
Future<bool> _connectPrinter(WidgetTester tester) async {
  final saved = _inLastSheet(
    find.widgetWithText(EzyButton, connectSavedPrinterLabel),
  );

  if (saved.evaluate().isNotEmpty) {
    await tester.tap(saved);
    await _waitForAny(tester, <Finder>[
      find.textContaining(printerConnectedPrefix),
      find.textContaining('No se pudo conectar'),
    ], timeout: const Duration(seconds: 30));
  }

  if (find.textContaining(printerConnectedPrefix).evaluate().isNotEmpty) {
    return true;
  }

  // Selector: emparejadas del teléfono + escaneo BLE (el escaneo es lo que pide
  // los permisos de Android 12+).
  final search = _inLastSheet(
    find.widgetWithText(EzyButton, findPrintersLabel),
  );
  expect(
    search.evaluate().isNotEmpty,
    isTrue,
    reason: 'La hoja no ofreció buscar impresoras',
  );

  await tester.tap(search);
  await _waitFor(
    tester,
    find.text(choosePrinterTitle),
    timeout: const Duration(seconds: 20),
    reason: 'No abrió el selector de impresoras',
  );

  final devices = await _dumpDiscoveredPrinters(tester);
  final labels = devices.map((device) => device.label).join(', ');

  if (livePrinterName.isEmpty) {
    markTestSkipped(
      'Sin --dart-define=LIVE_PRINTER_NAME no se elige impresora. '
      'Dispositivos vistos por el teléfono ($labels).',
    );

    return false;
  }

  final tile = _inLastSheet(find.textContaining(livePrinterName));
  expect(
    await _waitPrinterTile(tester, tile),
    isTrue,
    reason:
        'La impresora "$livePrinterName" no apareció en el selector. '
        'Dispositivos vistos por el teléfono: $labels',
  );

  await tester.tap(tile.first);

  // El selector se cierra solo cuando la característica de escritura quedó
  // lista; si el teléfono rechaza la conexión, el aviso queda en la hoja.
  await _waitForGone(tester, find.text(choosePrinterTitle));

  final outcome = await _waitForAny(tester, <Finder>[
    find.textContaining(printerConnectedPrefix),
    find.textContaining('No se pudo conectar'),
    find.textContaining('característica de escritura'),
    find.textContaining('No se pudo usar el Bluetooth'),
    find.textContaining('permiso de Bluetooth'),
  ], timeout: const Duration(seconds: 40));
  expect(
    outcome,
    0,
    reason:
        'El teléfono no conectó con "$livePrinterName" (revisa el aviso de la '
        'hoja de impresión)',
  );

  return true;
}

/// Espera al final del escaneo y deja en el log lo que ve el teléfono.
///
/// Devuelve la lista que el controlador tiene en memoria (emparejadas +
/// escaneadas): es la misma que el usuario ve en el selector.
Future<List<PrinterDevice>> _dumpDiscoveredPrinters(WidgetTester tester) async {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(EzyVentasApp)),
    listen: false,
  );

  final deadline = DateTime.now().add(const Duration(seconds: 45));

  while (DateTime.now().isBefore(deadline) &&
      container.read(printerControllerProvider).isBusy) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  final state = container.read(printerControllerProvider);

  if (state.errorMessage != null) {
    debugPrint('AVISO DE LA BÚSQUEDA | ${state.errorMessage}');
  }

  for (final device in state.devices) {
    debugPrint(
      'IMPRESORA VISTA | ${device.label} | ${device.id} '
      '| emparejada=${device.isPaired} | guardada=${device.isSaved} '
      '| rssi=${device.rssi}',
    );
  }

  return state.devices;
}

/// Busca la impresora bajando por la lista perezosa del selector.
Future<bool> _waitPrinterTile(
  WidgetTester tester,
  Finder tile, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final deadline = DateTime.now().add(timeout);
  var cycles = 0;

  while (DateTime.now().isBefore(deadline)) {
    if (tile.evaluate().isNotEmpty) {
      await tester.ensureVisible(tile.first);
      await tester.pump(const Duration(milliseconds: 100));

      return true;
    }

    if (cycles % 4 == 3) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    }

    cycles++;
    await tester.pump(const Duration(milliseconds: 100));
  }

  return false;
}

/// Widget dentro del último sheet modal abierto (el de arriba en la pila).
///
/// El detalle de la venta sigue montado detrás de la hoja de impresión y comparte
/// etiquetas con ella (`Imprimir ticket`), así que las acciones del documento se
/// buscan siempre dentro del sheet de arriba. El marcador es el `BottomSheet` de
/// Material, que sirve tanto para las hojas con `DraggableScrollableSheet` como
/// para las que monta `EzyBottomSheet.show`.
Finder _inLastSheet(Finder finder) =>
    find.descendant(of: find.byType(BottomSheet).last, matching: finder);

/// Recorre el detalle abierto (venta u orden) hasta la hoja de impresion.
///
/// Comprueba que el detalle llego del servidor (cabecera con folio y cierre),
/// que el subtitulo de la hoja une el documento con el folio que devolvio el
/// servidor, que el panel de impresion conoce el estado del Bluetooth del
/// telefono y que el documento se puede imprimir (el boton queda habilitado
/// cuando el servidor devuelve la plantilla). No se envia nada a ninguna
/// impresora: la impresora termica queda fuera del alcance.
///
/// Nota: la hoja **no** ofrece respaldo HTML. El boton se retiro porque
/// `POST /print/ticket-html` respondia `Ocurrió un error en el servidor.` en la
/// corrida real (capa de datos y pruebas conservadas), asi que el recorrido
/// termina en el boton de impresion.
Future<void> _printFromDetail(
  WidgetTester tester, {
  required List<String> printButtons,
}) async {
  final printLabel = await _openPrintSheet(tester, printButtons: printButtons);

  // El subtítulo del sheet une el título del documento con el folio que
  // devolvió el servidor ("Ticket de venta · A-000024").
  expect(
    find.textContaining(' · '),
    findsWidgets,
    reason: 'El sheet de impresión no mostró el folio del documento',
  );

  // Estado real del adaptador Bluetooth del telefono dentro del sheet.
  final printerState = await _waitForAny(tester, <Finder>[
    find.text(printerConnectedBadge),
    find.text(printerDisconnectedBadge),
  ], timeout: const Duration(seconds: 20));
  expect(
    printerState,
    isNot(-1),
    reason: 'El sheet de impresión no mostró el estado del Bluetooth',
  );

  // El boton de imprimir se habilita cuando el servidor devolvio la plantilla
  // que aplica al documento (mismo pendiente de pago que la impresora real).
  final printButton = _inLastSheet(find.widgetWithText(EzyButton, printLabel));
  expect(
    await _waitEnabled(
      tester,
      printButton,
      timeout: const Duration(seconds: 25),
    ),
    isTrue,
    reason: 'El servidor no habilitó la plantilla de impresión del documento',
  );

  // Se cierran la hoja de impresión y el detalle con el mismo `pop` del botón
  // atrás: el recorrido bajó por el `ListView` perezoso, así que el encabezado
  // con `Cerrar` puede haber salido del árbol y su toque no es fiable.
  await _closeSheets(tester);
  expect(
    find.byType(BottomSheet),
    findsNothing,
    reason: 'Quedó una hoja abierta tras revisar la impresión',
  );
}

/// Abre el detalle ya cargado y su hoja de impresión.
///
/// Se comparte entre el recorrido de flujos (que termina en el boton de
/// impresion) y la corrida de impresión real (que conecta la térmica y manda el
/// ticket). Devuelve la etiqueta del botón que abrió la hoja: el detalle de una
/// venta puede ofrecer ticket o etiqueta según el documento.
Future<String> _openPrintSheet(
  WidgetTester tester, {
  required List<String> printButtons,
}) async {
  await _waitFor(
    tester,
    find.byTooltip(closeDetailTooltip),
    timeout: const Duration(seconds: 30),
    reason: 'El detalle no cargó del servidor',
  );

  final buttons = <Finder>[
    for (final String label in printButtons)
      find.widgetWithText(EzyButton, label),
  ];
  final index = await _waitScrollingAny(
    tester,
    buttons,
    timeout: const Duration(seconds: 20),
  );
  expect(
    index,
    isNot(-1),
    reason: 'El detalle no mostró el botón de impresión',
  );

  await tester.tap(buttons[index]);
  await _waitFor(
    tester,
    find.text(printSheetTitle),
    timeout: const Duration(seconds: 30),
    reason: 'No abrió el sheet de impresión',
  );

  return printButtons[index];
}

/// Borra la sesion guardada (la app conserva el token entre corridas) y monta
/// la app como lo hace `main.dart`.
Future<void> _startClean(WidgetTester tester) async {
  await SessionStore().clearSession();
  await tester.pumpWidget(const ProviderScope(child: EzyVentasApp()));
  await _waitFor(tester, find.text(loginAction));
}

/// Inicia sesion con la UI real y espera al cascaron.
Future<void> _login(WidgetTester tester, String email, String password) async {
  await _waitFor(tester, find.byType(TextField));
  await tester.enterText(find.byType(TextField).at(0), email);
  await tester.pump();
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.pump();
  await _waitFor(tester, find.text(loginAction));
  await tester.tap(find.text(loginAction));

  // El login real tarda: se espera a la cabecera del cascarón (Inicio es el
  // destino por defecto), que es la que lleva la hamburguesa del menú.
  await _waitFor(
    tester,
    find.byTooltip(appDrawerOpenTooltip),
    timeout: const Duration(seconds: 45),
    reason: 'No apareció el cascarón tras iniciar sesión con $email',
  );
}

Future<void> _openAccount(WidgetTester tester) async {
  await _openMenuAction(tester, 'Cuenta');
  await _waitFor(tester, find.byType(AccountScreen));

  // Tarjeta de sucursal: sirve de ancla de "ya cargó". Se busca el texto en
  // mayúsculas porque `SectionCard` aplica `title!.toUpperCase()`, y se baja con
  // el dedo porque el `ListView` es perezoso y en una pantalla bajita la tarjeta
  // podría quedar fuera de la vista (no existiría en el árbol).
  await _scrollTo(tester, find.text(branchCardTitle.toUpperCase()));
}

Future<void> _logout(WidgetTester tester) async {
  // La pantalla de Cuenta es un `ListView` perezoso: el botón de cierre vive al
  // final y no existe en el árbol hasta que se desplaza hasta él.
  await _scrollTo(tester, find.text(logoutLabel));

  final button = find.text(logoutLabel).first;
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await _waitFor(tester, find.text('¿Quieres cerrar sesión?'));

  // El diálogo confirma el cierre (misma etiqueta que el botón de la pantalla).
  await tester.tap(find.text(logoutLabel).last);
  await _waitFor(
    tester,
    find.text(loginAction),
    timeout: const Duration(seconds: 30),
    reason: 'No se volvió al login tras cerrar sesión',
  );
}

/// Baja por el `ListView` de [screen] hasta que el widget exista.
///
/// Las listas son perezosas: lo que no se ve tampoco esta en el arbol, asi que
/// `find.text` no lo encuentra hasta que se desplaza hasta el.
Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  Type screen = AccountScreen,
}) async {
  if (finder.evaluate().isEmpty) {
    await tester.dragUntilVisible(
      finder,
      find
          .descendant(
            of: find.byType(screen),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -240),
      maxIteration: 30,
    );
  }

  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Comprueba que el menú lateral ofrece todas estas entradas.
///
/// El panel se cierra al terminar: las pestañas no viven en la pantalla, así que
/// dejarlo abierto taparía el resto del recorrido.
Future<void> _expectMenu(WidgetTester tester, List<String> expected) async {
  await _openDrawer(tester);

  for (final label in expected) {
    expect(
      _drawerRow(label),
      findsOneWidget,
      reason: 'El menú no ofreció «$label» para este usuario',
    );
  }

  await _closeDrawer(tester);
}

/// Fila del menú lateral por su etiqueta.
///
/// Se busca **dentro** del `Drawer`: la misma etiqueta puede existir en la
/// pantalla que queda detrás (la tarjeta «Vender» de Inicio, por ejemplo).
Finder _drawerRow(String label) => find.descendant(
  of: find.byType(Drawer),
  matching: find.text(label),
);

/// Abre el menú lateral con la hamburguesa de la cabecera.
Future<void> _openDrawer(WidgetTester tester) async {
  final trigger = find.byTooltip(appDrawerOpenTooltip);

  await _waitFor(tester, trigger, reason: 'La cabecera no ofreció el menú');
  await tester.tap(trigger);
  await _waitFor(tester, find.byType(Drawer));
}

/// Cierra el menú lateral con su botón de cerrar.
Future<void> _closeDrawer(WidgetTester tester) async {
  final close = find.byTooltip(EzyAppDrawer.closeTooltip);

  await _waitFor(tester, close);
  await tester.tap(close);
  await _waitForGone(tester, find.byType(Drawer));
}

/// Entra a una pantalla desde el menú lateral.
///
/// Es como se navega desde que no hay barra inferior: se abre el panel, se toca
/// la fila y se espera a que el panel se retire antes de seguir.
Future<void> _openMenuAction(WidgetTester tester, String label) async {
  await _openDrawer(tester);

  final row = _drawerRow(label);

  await _waitFor(tester, row, reason: 'El menú no ofreció «$label»');
  await tester.tap(row);

  // El panel se cierra antes de lanzar la acción: se espera a que desaparezca.
  await _waitForGone(tester, find.byType(Drawer));
}

/// `pumpAndSettle` no sirve con peticiones reales: se sondea hasta que el widget
/// esperado aparece o se agota el tiempo.
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 50));
      return;
    }

    await tester.pump(const Duration(milliseconds: 100));
  }

  fail(reason ?? 'No apareció $finder en $timeout');
}

/// Indice del primer `Finder` con resultados, o `-1` si no hay ninguno.
int _indexOfAny(List<Finder> finders) {
  for (var index = 0; index < finders.length; index++) {
    if (finders[index].evaluate().isNotEmpty) {
      return index;
    }
  }

  return -1;
}

/// Sondea varios widgets y devuelve el indice del primero que aparece, o `-1`.
Future<int> _waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    final index = _indexOfAny(finders);

    if (index != -1) {
      await tester.pump(const Duration(milliseconds: 50));
      return index;
    }

    await tester.pump(const Duration(milliseconds: 100));
  }

  return -1;
}

/// Como [_waitForAny], pero bajando por el `ListView` perezoso del sheet abierto
/// cada ~1.5 s: la seccion buscada puede no existir todavia en el arbol.
Future<int> _waitScrollingAny(
  WidgetTester tester,
  List<Finder> finders, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  var cycles = 0;

  while (DateTime.now().isBefore(deadline)) {
    final index = _indexOfAny(finders);

    if (index != -1) {
      await tester.ensureVisible(finders[index].first);
      await tester.pump(const Duration(milliseconds: 100));
      return index;
    }

    if (cycles != 0 && cycles % 15 == 0) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 200));
    }

    cycles++;
    await tester.pump(const Duration(milliseconds: 100));
  }

  return -1;
}

/// Como [_waitScrollingAny] con un solo widget.
Future<bool> _waitScrolling(WidgetTester tester, Finder finder) async {
  final index = await _waitScrollingAny(tester, <Finder>[finder]);

  return index != -1;
}

/// Sondea hasta que el boton exista y este habilitado (payload del servidor).
Future<bool> _waitEnabled(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  var cycles = 0;

  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) {
      if (tester.widget<EzyButton>(finder).onPressed != null) {
        await tester.ensureVisible(finder.first);
        await tester.pump(const Duration(milliseconds: 100));
        return true;
      }
    } else if (cycles != 0 && cycles % 15 == 0) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
      await tester.pump(const Duration(milliseconds: 200));
    }

    cycles++;
    await tester.pump(const Duration(milliseconds: 100));
  }

  return false;
}

/// Sondea hasta que el widget desaparezca (sheets, dialogos y avisos).
Future<bool> _waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 200));
      return true;
    }

    await tester.pump(const Duration(milliseconds: 100));
  }

  return false;
}

/// Cierra todas las hojas modales que queden abiertas (la de imprimir y, si
/// sigue montado, el detalle) sin disparar ninguna acción de negocio.
Future<void> _closeSheets(WidgetTester tester) async {
  for (var guard = 0; guard < 4; guard++) {
    if (find.byType(BottomSheet).evaluate().isEmpty) {
      return;
    }

    await _dismissSheet(tester);
  }
}

/// Cierra el sheet modal abierto como lo haria el boton atras del sistema.
///
/// Se comprueba que el numero de sheets abiertos baja: el detalle de una venta
/// sigue montado detras del sheet de impresion, asi que no basta con que no
/// quede ninguno. No dispara ninguna accion del sheet (ni el corte ni el cobro).
///
/// El marcador es el `BottomSheet` del propio Material (el que monta
/// `showModalBottomSheet`), no `DraggableScrollableSheet`: las hojas del POS ya
/// no arrastran ese envoltorio, lo pinta `EzyBottomSheet.show`.
///
/// Nota de la corrida en telefono: tocar el velo (scrim) con `tapAt` arriba a la
/// izquierda no cerro el sheet en el dispositivo, asi que el cierre se hace con
/// el mismo `pop` que dispara el boton atras (MIUI bloquea `adb input`, no se
/// pudo comprobar a mano si el velo responde al dedo).
Future<void> _dismissSheet(WidgetTester tester) async {
  final sheets = find.byType(BottomSheet);
  final before = sheets.evaluate().length;

  expect(before, greaterThan(0), reason: 'No había ningún sheet modal abierto');

  Navigator.of(tester.element(sheets.first)).pop();
  await tester.pump();

  final deadline = DateTime.now().add(const Duration(seconds: 15));

  while (DateTime.now().isBefore(deadline) &&
      sheets.evaluate().length >= before) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  expect(
    sheets.evaluate().length,
    lessThan(before),
    reason: 'El sheet no se cerró al pedir atrás',
  );
  await tester.pump(const Duration(milliseconds: 300));
}
