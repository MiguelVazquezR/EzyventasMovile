import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/core/storage/local_cache.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_dialog.dart';
import 'package:ezyventas_app/core/widgets/ezy_list_tile.dart';
import 'package:ezyventas_app/features/account/application/account_providers.dart';
import 'package:ezyventas_app/features/account/data/account_repository.dart';
import 'package:ezyventas_app/features/account/data/models/branch_switch_result.dart';
import 'package:ezyventas_app/features/account/data/models/notification_counters.dart';
import 'package:ezyventas_app/features/account/data/models/support_content.dart';
import 'package:ezyventas_app/features/account/data/models/subscription_overview.dart';
import 'package:ezyventas_app/features/account/data/models/user_profile.dart';
import 'package:ezyventas_app/features/account/presentation/branch_switch_screen.dart';
import 'package:ezyventas_app/features/account/presentation/notifications_screen.dart';
import 'package:ezyventas_app/features/account/presentation/profile_screen.dart';
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

/// Repositorio de cuenta falso: no toca red y guarda lo que se le pidió.
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository({this.counters = const NotificationCounters.empty()})
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final NotificationCounters counters;

  int deletePhotoCalls = 0;
  int logoutOtherCalls = 0;
  int switchCalls = 0;
  String? lastPassword;
  int? lastBranchId;

  @override
  Future<NotificationCounters> fetchNotifications() async => counters;

  @override
  Future<SupportContent> fetchSupport() async =>
      SupportContent.fromJson(supportFixture());

  @override
  Future<SubscriptionOverview> fetchSubscription() async =>
      SubscriptionOverview.fromJson(subscriptionFixture());

  @override
  Future<UserProfile> fetchProfile() async =>
      UserProfile.fromJson(<String, dynamic>{
        ...profileFixture()['user']! as Map<String, dynamic>,
        // Con foto: así la pantalla ofrece "Eliminar foto".
        'has_photo': true,
      });

  @override
  Future<ProfilePhotoDeleteResult> deleteProfilePhoto() async {
    deletePhotoCalls++;

    return ProfilePhotoDeleteResult.fromJson(<String, dynamic>{
      'message': 'Foto de perfil eliminada correctamente.',
      'user': <String, dynamic>{
        ...profileFixture()['user']! as Map<String, dynamic>,
        'has_photo': false,
      },
    });
  }

  @override
  Future<AccountMessageResult> logoutOtherDevices(String password) async {
    logoutOtherCalls++;
    lastPassword = password;

    return const AccountMessageResult(
      message: 'Se cerraron las demás sesiones correctamente.',
    );
  }

  @override
  Future<BranchSwitchResult> switchBranch(int branchId) async {
    switchCalls++;
    lastBranchId = branchId;

    return BranchSwitchResult.fromJson(branchSwitchFixture());
  }
}

/// Sesión falsa con la sucursal activa y otra a la que se puede cambiar.
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

AuthSession _session({required List<String> permissions}) =>
    AuthSession.fromJson(<String, dynamic>{
      'token': '3|token-de-prueba',
      'user': <String, dynamic>{
        'id': 2,
        'name': 'Jean Aponte',
        'email': 'jean@apontephone.com',
        'branch_id': 2,
        'branch': <String, dynamic>{
          'id': 2,
          'name': 'Melchor Ocampo',
          'timezone': 'America/Mexico_City',
        },
        'is_subscription_owner': true,
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
        <String, dynamic>{
          'id': 2,
          'name': 'Melchor Ocampo',
          'is_current': true,
        },
      ],
      'active_session': null,
      'joinable_sessions': <Map<String, dynamic>>[],
      'available_cash_registers': <Map<String, dynamic>>[],
    });

/// Router mínimo: la pantalla de sucursal y los destinos a los que navega.
GoRouter _branchRouter() => GoRouter(
  initialLocation: '/account/branch',
  routes: <RouteBase>[
    GoRoute(
      path: '/account/branch',
      builder: (context, state) => const BranchSwitchScreen(),
    ),
    for (final path in <String>['/cash-register', '/account'])
      GoRoute(
        path: path,
        builder: (context, state) =>
            Scaffold(body: Center(child: Text('destino $path'))),
      ),
  ],
);

/// App con la pantalla que se prueba y los overrides de red.
Widget _accountApp({
  required Widget home,
  required _FakeAccountRepository repository,
  List<String> permissions = const <String>['pos.access'],
}) => ProviderScope(
  overrides: [
    accountRepositoryProvider.overrideWithValue(repository),
    localCacheProvider.overrideWithValue(_MemoryCache()),
    authRepositoryProvider.overrideWithValue(
      _FakeAuthRepository(session: _session(permissions: permissions)),
    ),
  ],
  child: MaterialApp(theme: EzyTheme.dark(), home: home),
);

/// Igual que [accountApp] pero con el router de la pantalla de sucursal.
Widget _branchSwitchApp({required _FakeAccountRepository repository}) =>
    ProviderScope(
      overrides: [
        accountRepositoryProvider.overrideWithValue(repository),
        localCacheProvider.overrideWithValue(_MemoryCache()),
        authRepositoryProvider.overrideWithValue(
          _FakeAuthRepository(
            session: _session(
              permissions: const <String>[
                'pos.access',
                'system.branches.switch',
              ],
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: EzyTheme.dark(),
        routerConfig: _branchRouter(),
      ),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets(
    'cambiar de sucursal pide confirmación con el diálogo del sistema',
    (tester) async {
      final repository = _FakeAccountRepository();

      await tester.pumpWidget(_branchSwitchApp(repository: repository));
      await tester.pumpAndSettle();

      // La sucursal activa se marca y no se puede elegir.
      expect(find.text('Melchor Ocampo'), findsOneWidget);
      expect(find.text('Activa'), findsOneWidget);

      await tester.tap(find.text('Guacamayas.Comercial'));
      await tester.pumpAndSettle();

      expect(find.byType(EzyDialog), findsOneWidget);
      expect(find.text('¿Cambiar a «Guacamayas.Comercial»?'), findsOneWidget);
      expect(
        find.text(
          'Verás la información de esa sucursal en este dispositivo, igual '
          'que en la web.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(EzyDialog), findsNothing);
      expect(repository.switchCalls, 0);

      // Confirmar manda el cambio y la app se va a Caja (el turno era de la
      // sucursal anterior).
      await tester.tap(find.text('Guacamayas.Comercial'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(EzyDialog),
          matching: find.widgetWithText(EzyButton, 'Cambiar de sucursal'),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.switchCalls, 1);
      expect(repository.lastBranchId, 3);
    },
  );

  testWidgets('eliminar la foto pide confirmación destructiva', (tester) async {
    final repository = _FakeAccountRepository();

    await tester.pumpWidget(
      _accountApp(home: const ProfileScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eliminar foto'));
    await tester.pumpAndSettle();

    expect(find.byType(EzyDialog), findsOneWidget);
    expect(
      find.text(
        'Se quitará tu foto de perfil. Puedes subir otra cuando quieras.',
      ),
      findsOneWidget,
    );

    // La acción destructiva va rellena en rojo (variante `danger`).
    final confirm = find.descendant(
      of: find.byType(EzyDialog),
      matching: find.widgetWithText(EzyButton, 'Eliminar foto'),
    );

    expect(tester.widget<EzyButton>(confirm).variant, EzyButtonVariant.danger);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(repository.deletePhotoCalls, 1);
    expect(
      find.text('Foto de perfil eliminada correctamente.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'cerrar otras sesiones pide la contraseña y se habilita al escribir',
    (tester) async {
      final repository = _FakeAccountRepository();

      await tester.pumpWidget(
        _accountApp(home: const ProfileScreen(), repository: repository),
      );
      await tester.pumpAndSettle();

      // "Cerrar otras sesiones" vive al final de la pantalla.
      await tester.scrollUntilVisible(
        find.text('Cerrar otras sesiones'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cerrar otras sesiones'));
      await tester.pumpAndSettle();

      expect(find.byType(EzyDialog), findsOneWidget);
      expect(find.text('Confirmar cierre'), findsOneWidget);

      final confirm = find.descendant(
        of: find.byType(EzyDialog),
        matching: find.widgetWithText(EzyButton, 'Cerrar otras sesiones'),
      );

      // Con el campo vacío no se puede enviar: antes el diálogo se cerraba sin
      // mandar nada y la acción se perdía en silencio.
      expect(tester.widget<EzyButton>(confirm).onPressed, isNull);
      expect(repository.logoutOtherCalls, 0);

      await tester.enterText(find.byType(TextField).last, 'secreta');
      await tester.pump();

      expect(tester.widget<EzyButton>(confirm).onPressed, isNotNull);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(repository.logoutOtherCalls, 1);
      expect(repository.lastPassword, 'secreta');
    },
  );

  testWidgets('las notificaciones se listan con las filas del sistema', (
    tester,
  ) async {
    final repository = _FakeAccountRepository(
      counters: NotificationCounters.fromJson(notificationsFixture()),
    );

    await tester.pumpWidget(
      _accountApp(home: const NotificationsScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    // Una sola lista sobre el panel, con los divisores del sistema.
    expect(find.byType(EzyListTile), findsNWidgets(4));
    expect(find.text('Deudas por vencer'), findsOneWidget);
    expect(find.text('Entregas próximas'), findsOneWidget);
    expect(find.text('Novedades'), findsOneWidget);
    expect(find.text('Pedidos pendientes'), findsOneWidget);

    // El conteo del servidor se pinta como badge del sistema.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
