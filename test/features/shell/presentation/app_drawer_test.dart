import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/storage/local_cache.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/theme/theme_mode_controller.dart';
import 'package:ezyventas_app/core/widgets/ezy_list_tile.dart';
import 'package:ezyventas_app/features/account/application/account_providers.dart';
import 'package:ezyventas_app/features/account/data/account_repository.dart';
import 'package:ezyventas_app/features/account/data/models/notification_counters.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/shell/presentation/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_harness.dart';

/// Repositorio de cuenta falso: el panel no toca la red para los contadores.
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository()
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  @override
  Future<NotificationCounters> fetchNotifications() async =>
      const NotificationCounters.empty();
}

/// Caché en memoria: tampoco se toca el almacenamiento del dispositivo.
class _MemoryCache extends LocalCache {
  Map<String, dynamic>? value;

  @override
  Future<Map<String, dynamic>?> readNotifications() async => value;

  @override
  Future<void> saveNotifications(Map<String, dynamic> counters) async {
    value = counters;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}


/// Permisos del propietario con todo contratado: es el usuario que más filas ve.
const List<String> _ownerPermissions = <String>[
  'pos.access',
  'pos.create_sale',
  'transactions.access',
  'services.orders.access',
  'services.orders.create',
  'system.branches.switch',
];

/// Permisos del empleado de mostrador: sin órdenes, sin sucursal y sin
/// suscripción (no es propietario de la cuenta).
const List<String> _employeePermissions = <String>[
  'pos.access',
  'pos.create_sale',
  'transactions.access',
];

/// Rutas de las pestañas y de las subpantallas, para que el panel navegue de
/// verdad (`go` y `push` reales, no un `Navigator` de mentira).
GoRouter _router(GlobalKey<ScaffoldState> key) => GoRouter(
  initialLocation: '/sell',
  routes: <RouteBase>[
    for (final path in <String>[
      '/home',
      '/sell',
      '/service-orders',
      '/cash-register',
      '/sales',
      '/account',
    ])
      GoRoute(
        path: path,
        builder: (context, state) => path == '/sell'
            ? Scaffold(
                key: key,
                drawer: const EzyAppDrawer(),
                body: const SizedBox.expand(),
              )
            : Scaffold(body: Center(child: Text('destino $path'))),
      ),
    for (final path in <String>[
      '/account/profile',
      '/account/branch',
      '/account/notifications',
      '/account/support',
      '/account/subscription',
      '/service-orders/new',
    ])
      GoRoute(
        path: path,
        builder: (context, state) =>
            Scaffold(body: Center(child: Text('destino $path'))),
      ),
  ],
);

/// Monta el cascarón mínimo con el menú lateral **abierto** y devuelve el
/// contenedor de proveedores para poder leer el tema.
Future<ProviderContainer> _pumpDrawer(
  WidgetTester tester, {
  List<String> permissions = _ownerPermissions,
  String name = 'Miguel Osvaldo',
  bool isOwner = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(
        FakeAuthRepository(
          session: fakeSession(
            permissions: permissions,
            modules: const <String>['module_pos', 'module_services'],
            name: name,
            isOwner: isOwner,
          ),
        ),
      ),
      // Los contadores de la campana no se piden a la red en una prueba.
      accountRepositoryProvider.overrideWithValue(_FakeAccountRepository()),
      localCacheProvider.overrideWithValue(_MemoryCache()),
    ],
  );
  addTearDown(container.dispose);

  final key = GlobalKey<ScaffoldState>();
  final router = _router(key);
  addTearDown(router.dispose);

  // El panel es un `ListView` y en la pantalla de prueba (800 x 600) las últimas
  // secciones no se construyen: con una pantalla alta el recorrido ve el panel
  // entero sin desplazarlo.
  await tester.binding.setSurfaceSize(const Size(420, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: EzyTheme.dark(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();

  key.currentState!.openDrawer();
  await tester.pumpAndSettle();

  return container;
}

/// Fila del panel por su etiqueta.
Finder _row(String label) =>
    find.descendant(of: find.byType(Drawer), matching: find.text(label));

void main() {
  testWidgets('propietario: pestañas, acciones, cuenta y salir', (tester) async {
    await _pumpDrawer(tester);

    // Navegación: todas las pestañas visibles, sin el reparto de huecos que hacía
    // la barra inferior.
    for (final label in <String>[
      'Inicio',
      'Vender',
      'Órdenes',
      'Caja',
      'Ventas',
      'Cuenta',
    ]) {
      expect(_row(label), findsOneWidget, reason: 'falta $label');
    }

    // Vender está seleccionada: la fila táctil lleva el estado activo.
    final sellTile = tester.widget<EzyListTile>(
      find.ancestor(of: _row('Vender'), matching: find.byType(EzyListTile)),
    );
    expect(sellTile.isSelected, isTrue);

    expect(_row('Nueva venta'), findsOneWidget);
    expect(_row('Nueva orden de servicio'), findsOneWidget);
    expect(_row('Mi perfil'), findsOneWidget);
    expect(_row('Cambiar de sucursal'), findsOneWidget);
    expect(_row('Mi suscripción'), findsOneWidget);
    expect(_row('Notificaciones'), findsOneWidget);
    expect(_row('Centro de soporte'), findsOneWidget);
    expect(_row('Modo oscuro'), findsOneWidget);
    expect(_row('Cerrar sesión'), findsOneWidget);

    // El nombre del usuario y la sucursal activa van en la cabecera del panel.
    expect(_row('Miguel Osvaldo'), findsOneWidget);
    expect(find.textContaining('Melchor Ocampo'), findsWidgets);
  });

  testWidgets('empleado: sin órdenes, sin sucursal y sin suscripción', (
    tester,
  ) async {
    await _pumpDrawer(
      tester,
      permissions: _employeePermissions,
      isOwner: false,
    );

    expect(_row('Vender'), findsOneWidget);
    expect(_row('Caja'), findsOneWidget);
    expect(_row('Órdenes'), findsNothing);
    expect(_row('Nueva orden de servicio'), findsNothing);
    expect(_row('Cambiar de sucursal'), findsNothing);
    expect(_row('Mi suscripción'), findsNothing);
    // La acción de venta sigue disponible y se llama por su nombre.
    expect(_row('Nueva venta'), findsOneWidget);
  });

  testWidgets('el interruptor de tema cambia el modo de la app', (tester) async {
    final container = await _pumpDrawer(tester);

    expect(container.read(themeModeProvider), ThemeMode.dark);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  testWidgets('cerrar sesión pide confirmación con el texto aprobado', (
    tester,
  ) async {
    await _pumpDrawer(tester);

    await tester.tap(_row('Cerrar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quieres cerrar sesión?'), findsOneWidget);

    // Se cancela: la sesión sigue viva (el `POST` de cierre no se envía).
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quieres cerrar sesión?'), findsNothing);
  });
}

