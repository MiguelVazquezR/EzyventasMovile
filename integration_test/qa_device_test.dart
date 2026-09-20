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
// servidor). No sustituye a las corridas de `test/live/api_smoke_test.dart`:
// complementa lo que solo se puede comprobar en el telefono.
import 'package:ezyventas_app/app.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/core/config/app_config.dart';
import 'package:ezyventas_app/features/account/presentation/account_screen.dart';
import 'package:ezyventas_app/features/catalog/presentation/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

const String ownerEmail = String.fromEnvironment('LIVE_API_EMAIL');
const String ownerPassword = String.fromEnvironment('LIVE_API_PASSWORD');
const String employeeEmail = String.fromEnvironment('LIVE_EMPLOYEE_EMAIL');
const String employeePassword = String.fromEnvironment('LIVE_EMPLOYEE_PASSWORD');

/// Las cinco pestanas del cascaron (§4.1 del documento maestro).
const List<String> shellTabs = <String>[
  'Vender',
  'Órdenes',
  'Caja',
  'Ventas',
  'Cuenta',
];

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

const Timeout _deviceTimeout = Timeout(Duration(minutes: 4));

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

    // 2) Pestanas reales del propietario (permisos + modulos del login).
    _expectTabs(tester, shellTabs);

    // 3) La pestana Vender (destino por defecto) carga el catalogo real: si una
    // tarjeta desbordara su reja, el `RenderFlex overflowed` fallaria aqui (fue
    // el caso real del telefono antes del arreglo de `product_card.dart`).
    await _waitFor(tester, find.text('Buscar por nombre o SKU…'));
    await _waitFor(
      tester,
      find.byType(ProductCard),
      timeout: const Duration(seconds: 30),
      reason: 'El catálogo no mostró productos de la sucursal',
    );

    // 4) Cuenta de propietario: suscripcion y cambio de sucursal.
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

    // El empleado limitado conserva las pestanas de su trabajo...
    _expectTabs(tester, shellTabs);

    // ...pero no ve la suscripcion (no es propietario) ni puede cambiar de
    // sucursal (sin `system.branches.switch`).
    await _openAccount(tester);
    expect(find.text(subscriptionOption), findsNothing);
    expect(find.text(noBranchPermission), findsOneWidget);
    expect(find.text(changeBranchAction), findsNothing);

    await _logout(tester);
    expect(find.text(loginAction), findsOneWidget);
  }, timeout: _deviceTimeout);
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

  // El login real tarda: se espera a la barra de pestanas del cascaron.
  await _waitFor(
    tester,
    _tabFinder('Cuenta'),
    timeout: const Duration(seconds: 45),
    reason: 'No apareció el cascarón tras iniciar sesión con $email',
  );
}

Future<void> _openAccount(WidgetTester tester) async {
  await tester.tap(_tabFinder('Cuenta'));
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

/// Baja por el `ListView` de Cuenta hasta que el widget exista.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    return;
  }

  await tester.dragUntilVisible(
    finder,
    find.descendant(
      of: find.byType(AccountScreen),
      matching: find.byType(Scrollable),
    ),
    const Offset(0, -240),
    maxIteration: 30,
  );
  await tester.pump();
}

void _expectTabs(WidgetTester tester, List<String> expected) {
  for (final label in expected) {
    expect(
      _tabFinder(label),
      findsOneWidget,
      reason: 'La pestaña $label no está visible para este usuario',
    );
  }
}

Finder _tabFinder(String label) =>
    find.widgetWithText(NavigationDestination, label);

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
