import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/core/storage/local_cache.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/features/account/application/account_providers.dart';
import 'package:ezyventas_app/features/account/data/account_repository.dart';
import 'package:ezyventas_app/features/account/data/models/branch_switch_result.dart';
import 'package:ezyventas_app/features/account/data/models/notification_counters.dart';
import 'package:ezyventas_app/features/account/data/models/subscription_overview.dart';
import 'package:ezyventas_app/features/account/data/models/support_content.dart';
import 'package:ezyventas_app/features/account/data/models/user_profile.dart';
import 'package:ezyventas_app/features/account/presentation/account_screen.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/auth/data/auth_repository.dart';
import 'package:ezyventas_app/features/auth/data/models/access_context.dart';
import 'package:ezyventas_app/features/auth/data/models/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../data/account_parsers_test.dart';

/// Repositorio de cuenta falso: no toca red.
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository({this.counters = const NotificationCounters.empty()})
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final NotificationCounters counters;

  @override
  Future<NotificationCounters> fetchNotifications() async => counters;

  @override
  Future<SupportContent> fetchSupport() async =>
      SupportContent.fromJson(supportFixture());

  @override
  Future<SubscriptionOverview> fetchSubscription() async =>
      SubscriptionOverview.fromJson(subscriptionFixture());

  @override
  Future<UserProfile> fetchProfile() async => UserProfile.fromJson(
    profileFixture()['user']! as Map<String, dynamic>,
  );

  @override
  Future<BranchSwitchResult> switchBranch(int branchId) async =>
      BranchSwitchResult.fromJson(branchSwitchFixture());
}

/// Caché en memoria: la pantalla no toca el almacenamiento seguro.
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

/// Sesión falsa: permisos, módulos y sucursales que el servidor entregaría.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({required this.session})
    : super(api: ApiClient(), sessionStore: SessionStore());

  AuthSession? session;

  @override
  Future<AuthSession?> readStoredSession() async => session;

  @override
  Future<AccessContext> fetchAccessContext() async => session!.context;

  @override
  Future<void> saveSession(AuthSession next) async => session = next;

  @override
  Future<void> clearSession() async => session = null;
}

AuthSession _session({
  required bool isOwner,
  required List<String> permissions,
}) => AuthSession.fromJson(<String, dynamic>{
  'token': '3|token-de-prueba',
  'user': <String, dynamic>{
    'id': isOwner ? 2 : 7,
    'name': isOwner ? 'Jean Aponte' : 'Daniel',
    'email': isOwner ? 'jean@apontephone.com' : 'daniel@apontephone.com',
    'branch_id': 2,
    'branch': <String, dynamic>{
      'id': 2,
      'name': 'Melchor Ocampo',
      'timezone': 'America/Mexico_City',
    },
    'is_subscription_owner': isOwner,
    'permissions': permissions,
  },
  'module_keys': <String>['module_pos'],
  'modules': <String>['Punto de Venta'],
  'available_branches': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 3,
      'name': 'Guacamayas.Comercial',
      'is_current': false,
    },
    <String, dynamic>{'id': 2, 'name': 'Melchor Ocampo', 'is_current': true},
  ],
  'active_session': null,
  'joinable_sessions': <Map<String, dynamic>>[],
  'available_cash_registers': <Map<String, dynamic>>[
    <String, dynamic>{'id': 2, 'name': 'Caja principal'},
  ],
});

/// Router mínimo: la pestaña Cuenta y destinos de las subpantallas.
GoRouter _router() => GoRouter(
  initialLocation: '/account',
  routes: <RouteBase>[
    GoRoute(
      path: '/account',
      builder: (context, state) => const AccountScreen(),
    ),
    for (final path in <String>[
      '/account/profile',
      '/account/branch',
      '/account/notifications',
      '/account/support',
      '/account/subscription',
    ])
      GoRoute(
        path: path,
        builder: (context, state) => Scaffold(
          body: Center(child: Text('destino $path')),
        ),
      ),
  ],
);

Widget _wrap({
  required bool isOwner,
  required List<String> permissions,
  NotificationCounters counters = const NotificationCounters.empty(),
}) {
  return ProviderScope(
    overrides: [
      accountRepositoryProvider.overrideWithValue(
        _FakeAccountRepository(counters: counters),
      ),
      localCacheProvider.overrideWithValue(_MemoryCache()),
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(
          session: _session(isOwner: isOwner, permissions: permissions),
        ),
      ),
    ],
    child: MaterialApp.router(
      theme: EzyTheme.dark(),
      routerConfig: _router(),
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('propietario ve todas las opciones y el cambio de sucursal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        isOwner: true,
        permissions: <String>['pos.access', 'system.branches.switch'],
        counters: NotificationCounters.fromJson(notificationsFixture()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi cuenta'), findsOneWidget);
    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Mi suscripción'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(find.text('Centro de soporte'), findsWidgets);
    expect(find.text('Cambiar de sucursal'), findsOneWidget);
    expect(find.text('Propietario de la suscripción'), findsOneWidget);

    // El badge de la campana usa el total del servidor (11).
    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('empleado sin permisos no ve suscripción ni cambio de sucursal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        isOwner: false,
        permissions: <String>['pos.access', 'transactions.access'],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Notificaciones'), findsOneWidget);
    expect(
      find.text('Mi suscripción'),
      findsNothing,
      reason: 'la suscripción es solo del propietario (§9b.3)',
    );
    expect(
      find.text('Cambiar de sucursal'),
      findsNothing,
      reason: 'sin system.branches.switch no se ofrece el cambio',
    );
    expect(find.text('Tu usuario no puede cambiar de sucursal.'), findsOneWidget);
  });

  testWidgets('cerrar sesión pide confirmación con el texto aprobado', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(isOwner: true, permissions: <String>['pos.access']),
    );
    await tester.pumpAndSettle();

    final logout = find.widgetWithText(EzyButton, 'Cerrar sesión');

    // El botón vive al final de la lista: hay que bajar para poder tocarlo.
    await tester.dragUntilVisible(
      logout,
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    await tester.tap(logout);
    await tester.pumpAndSettle();

    expect(find.text('¿Quieres cerrar sesión?'), findsOneWidget);
    expect(
      find.text(
        'Se cerrará la sesión de este dispositivo. Los demás dispositivos '
        'siguen conectados.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Quieres cerrar sesión?'), findsNothing);
    expect(find.text('Mi cuenta'), findsOneWidget);
  });

  testWidgets('el aviso de suscripción por vencer viene del servidor', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(isOwner: true, permissions: <String>['pos.access']),
    );
    await tester.pumpAndSettle();

    // El fixture está "Activa" y sin warning: no hay banner ámbar.
    expect(
      find.text('Tu suscripción vence en 4 día(s). Renuévala para no perder acceso.'),
      findsNothing,
    );
  });
}
