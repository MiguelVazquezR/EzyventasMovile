import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/core/storage/local_cache.dart';
import 'package:ezyventas_app/core/utils/evidence_image.dart';
import 'package:ezyventas_app/features/account/application/account_providers.dart';
import 'package:ezyventas_app/features/account/application/branch_switch_controller.dart';
import 'package:ezyventas_app/features/account/application/profile_controller.dart';
import 'package:ezyventas_app/features/account/application/subscription_controller.dart';
import 'package:ezyventas_app/features/account/data/account_repository.dart';
import 'package:ezyventas_app/features/account/data/models/branch_switch_result.dart';
import 'package:ezyventas_app/features/account/data/models/notification_counters.dart';
import 'package:ezyventas_app/features/account/data/models/subscription_overview.dart';
import 'package:ezyventas_app/features/account/data/models/support_content.dart';
import 'package:ezyventas_app/features/account/data/models/user_profile.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/auth/data/auth_repository.dart';
import 'package:ezyventas_app/features/auth/data/models/access_context.dart';
import 'package:ezyventas_app/features/auth/data/models/auth_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/account_parsers_test.dart';

/// Repositorio falso: no toca red ni almacenamiento seguro.
class _FakeAccountRepository extends AccountRepository {
  _FakeAccountRepository({this.counters, this.failure})
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final NotificationCounters? counters;
  final ApiException? failure;

  int notificationsCalls = 0;
  Map<String, dynamic>? lastSubscriptionPayload;
  String? lastPassword;
  bool lastUpdateHadPhoto = false;

  @override
  Future<NotificationCounters> fetchNotifications() async {
    notificationsCalls++;

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return counters ?? const NotificationCounters.empty();
  }

  @override
  Future<SupportContent> fetchSupport() async =>
      SupportContent.fromJson(supportFixture());

  @override
  Future<BranchSwitchResult> switchBranch(int branchId) async {
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return BranchSwitchResult.fromJson(branchSwitchFixture());
  }

  @override
  Future<UserProfile> fetchProfile() async => UserProfile.fromJson(
    profileFixture()['user']! as Map<String, dynamic>,
  );

  @override
  Future<ProfileUpdateResult> updateProfile({
    required String name,
    required String email,
    EvidenceImage? photo,
  }) async {
    lastUpdateHadPhoto = photo != null;

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return ProfileUpdateResult.fromJson(<String, dynamic>{
      'user': <String, dynamic>{
        'id': 2,
        'name': name,
        'email': email,
        'has_photo': photo != null,
        'profile_photo_url': null,
      },
      'email_verification_sent': false,
      'message': 'Tus datos se guardaron.',
    });
  }

  @override
  Future<ProfilePhotoDeleteResult> deleteProfilePhoto() async {
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return ProfilePhotoDeleteResult.fromJson(<String, dynamic>{
      'user': <String, dynamic>{
        'id': 2,
        'name': 'Jean Aponte',
        'email': 'jean@apontephone.com',
        'has_photo': false,
      },
      'message': 'Foto eliminada.',
    });
  }

  @override
  Future<AccountMessageResult> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    lastPassword = password;

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return const AccountMessageResult(message: 'Tu contraseña se actualizó.');
  }

  @override
  Future<AccountMessageResult> logoutOtherDevices(String password) async {
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return const AccountMessageResult(
      message: 'Se cerraron las demás sesiones.',
    );
  }

  @override
  Future<SubscriptionOverview> fetchSubscription() async =>
      SubscriptionOverview.fromJson(subscriptionFixture());

  @override
  Future<AccountMessageResult> updateSubscription(
    Map<String, dynamic> payload,
  ) async {
    lastSubscriptionPayload = payload;

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return const AccountMessageResult(
      message: 'Los datos de la suscripción se guardaron.',
    );
  }
}

/// Caché en memoria (el doble de `LocalCache` sin tocar el almacenamiento).
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

/// Repositorio de sesión falso: entrega el contexto sin red.
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
  List<String> permissions = const <String>['pos.access'],
  bool isOwner = true,
  int branchId = 2,
  String branchName = 'Melchor Ocampo',
}) => AuthSession.fromJson(<String, dynamic>{
  'token': '9|token-de-prueba',
  'user': <String, dynamic>{
    'id': 2,
    'name': 'Jean Aponte',
    'email': 'jean@apontephone.com',
    'branch_id': branchId,
    'branch': <String, dynamic>{
      'id': branchId,
      'name': branchName,
      'timezone': 'America/Mexico_city',
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
    <String, dynamic>{'id': branchId, 'name': branchName, 'is_current': true},
  ],
  'active_session': null,
  'joinable_sessions': <Map<String, dynamic>>[],
  'available_cash_registers': <Map<String, dynamic>>[
    <String, dynamic>{'id': branchId, 'name': 'Caja principal'},
  ],
});

/// Contenedor con los dobles ya conectados.
///
/// Espera a que `AuthController.restoreSession` termine (arranca en un
/// `microtask`) para que el contexto esté disponible en las pruebas.
Future<ProviderContainer> _container({
  required _FakeAccountRepository repository,
  AuthSession? session,
  _MemoryCache? cache,
}) async {
  final container = ProviderContainer(
    overrides: [
      accountRepositoryProvider.overrideWithValue(repository),
      localCacheProvider.overrideWithValue(cache ?? _MemoryCache()),
      authRepositoryProvider.overrideWithValue(
        _FakeAuthRepository(session: session ?? _session()),
      ),
    ],
  );

  addTearDown(container.dispose);

  // Espera a que `restoreSession` termine: hasta entonces el contexto es null.
  for (var attempt = 0; attempt < 50; attempt++) {
    if (container.read(authControllerProvider).isAuthenticated) {
      break;
    }

    await Future<void>.delayed(Duration.zero);
  }

  return container;
}

void main() {
  test('notificaciones: guarda los contadores y los cachea', () async {
    final cache = _MemoryCache();
    final container = await _container(
      repository: _FakeAccountRepository(
        counters: NotificationCounters.fromJson(notificationsFixture()),
      ),
      cache: cache,
    );

    await container.read(notificationsControllerProvider.notifier).refresh();

    final state = container.read(notificationsControllerProvider);

    expect(state.counters.total, 11);
    expect(state.isLoading, isFalse);
    expect(state.hasCachedValue, isFalse);
    expect(state.errorMessage, isNull);
    expect(cache.value?['total'], 11);
    expect(container.read(notificationsTotalProvider), 11);
  });

  test('notificaciones: sin conexión muestra el último valor cacheado', () async {
    final cache = _MemoryCache()
      ..value = <String, dynamic>{
        'expiring_debts': 2,
        'upcoming_deliveries': 0,
        'unread_updates': 0,
        'pending_orders': 0,
        'total': 2,
      };

    final container = await _container(
      repository: _FakeAccountRepository(
        failure: ApiException.network(),
      ),
      cache: cache,
    );

    await container.read(notificationsControllerProvider.notifier).refresh();

    final state = container.read(notificationsControllerProvider);

    expect(state.counters.total, 2);
    expect(state.hasCachedValue, isTrue);
    expect(state.errorMessage, isNotNull);
  });

  test('notificaciones: sin caché previa no se inventa un badge', () async {
    final container = await _container(
      repository: _FakeAccountRepository(failure: ApiException.network()),
    );

    await container.read(notificationsControllerProvider.notifier).refresh();

    final state = container.read(notificationsControllerProvider);

    expect(state.counters.total, 0);
    expect(state.hasCachedValue, isFalse);
  });

  test('notificaciones: clear() borra la caché local', () async {
    final cache = _MemoryCache();
    final container = await _container(
      repository: _FakeAccountRepository(
        counters: NotificationCounters.fromJson(notificationsFixture()),
      ),
      cache: cache,
    );

    final controller = container.read(
      notificationsControllerProvider.notifier,
    );

    await controller.refresh();
    await controller.clear();

    expect(cache.value, isNull);
    expect(container.read(notificationsControllerProvider).counters.total, 0);
  });

  test('perfil: guarda cambios y muestra el message del servidor', () async {
    final repository = _FakeAccountRepository();
    final container = await _container(repository: repository);

    final saved = await container
        .read(profileControllerProvider.notifier)
        .save(name: 'Jean Aponte', email: 'jean@apontephone.com');

    final state = container.read(profileControllerProvider);

    expect(saved, isTrue);
    expect(state.notice, 'Tus datos se guardaron.');
    expect(state.errorMessage, isNull);
    expect(repository.lastUpdateHadPhoto, isFalse);
  });

  test('perfil: contraseña actual incorrecta se muestra tal cual', () async {
    final container = await _container(
      repository: _FakeAccountRepository(
        failure: ApiException.fromResponse(422, <String, dynamic>{
          'code': 'invalid_current_password',
          'message': 'La contraseña actual no es correcta.',
        }),
      ),
    );

    final updated = await container
        .read(profileControllerProvider.notifier)
        .changePassword(
          currentPassword: 'incorrecta',
          password: 'nueva123456',
          confirmation: 'nueva123456',
        );

    final state = container.read(profileControllerProvider);

    expect(updated, isFalse);
    expect(state.errorMessage, 'La contraseña actual no es correcta.');
  });

  test('perfil: eliminar foto usa el message del servidor', () async {
    final container = await _container(repository: _FakeAccountRepository());

    final deleted = await container
        .read(profileControllerProvider.notifier)
        .deletePhoto();

    final state = container.read(profileControllerProvider);

    expect(deleted, isTrue);
    expect(state.notice, 'Foto eliminada.');
    expect(state.photoJustDeleted, isTrue);
  });

  test('suscripción: guarda los datos generales y refresca la vista', () async {
    final repository = _FakeAccountRepository();
    final container = await _container(repository: repository);

    final saved = await container
        .read(subscriptionControllerProvider.notifier)
        .saveGeneralData(
          commercialName: 'ApontePhone',
          businessName: '',
          contactPhone: '7531107389',
          address: '',
        );

    final state = container.read(subscriptionControllerProvider);

    expect(saved, isTrue);
    expect(state.notice, 'Los datos de la suscripción se guardaron.');
    expect(repository.lastSubscriptionPayload?['commercial_name'], 'ApontePhone');
    expect(
      repository.lastSubscriptionPayload?['business_name'],
      isNull,
      reason: 'los campos vací­os viajan como null (contrato §11b.5)',
    );
  });

  test('suscripción: 403 del empleado se muestra con el message', () async {
    final container = await _container(
      repository: _FakeAccountRepository(
        failure: ApiException.fromResponse(403, <String, dynamic>{
          'message': 'Tu usuario no tiene permiso para esta acción.',
        }),
      ),
    );

    final saved = await container
        .read(subscriptionControllerProvider.notifier)
        .saveGeneralData(commercialName: 'ApontePhone');

    final state = container.read(subscriptionControllerProvider);

    expect(saved, isFalse);
    expect(state.errorMessage, 'Tu usuario no tiene permiso para esta acción.');
  });

  test('cambio de sucursal: aplica el contexto y publica el message', () async {
    final repository = _FakeAccountRepository();
    final session = _session(
      permissions: <String>['pos.access', 'system.branches.switch'],
    );
    final container = await _container(repository: repository, session: session);

    // El contexto arranca en la sucursal 2 (Melchor Ocampo).
    expect(container.read(authControllerProvider).context?.currentBranch?.id, 2);

    final switched = await container
        .read(branchSwitchControllerProvider.notifier)
        .switchTo(
          container
              .read(authControllerProvider)
              .context!
              .availableBranches
              .first,
        );

    final state = container.read(branchSwitchControllerProvider);
    final context = container.read(authControllerProvider).context;

    expect(switched, isTrue);
    expect(
      state.notice,
      'Cambiado a la sucursal: Guacamayas.Comercial',
    );
    expect(context?.currentBranch?.id, 3);
    expect(context?.user.branchId, 3);
    expect(context?.availableCashRegisters.single.name, 'Caja principal');
  });

  test('cambio de sucursal: 403 branch_out_of_scope no cambia el contexto', () async {
    final container = await _container(
      repository: _FakeAccountRepository(
        failure: ApiException.fromResponse(403, <String, dynamic>{
          'code': 'branch_out_of_scope',
          'message': 'No tienes permiso para cambiar a esta sucursal.',
        }),
      ),
      session: _session(
        permissions: <String>['pos.access', 'system.branches.switch'],
      ),
    );

    final switched = await container
        .read(branchSwitchControllerProvider.notifier)
        .switchTo(
          container
              .read(authControllerProvider)
              .context!
              .availableBranches
              .first,
        );

    final state = container.read(branchSwitchControllerProvider);

    expect(switched, isFalse);
    expect(state.errorMessage, 'No tienes permiso para cambiar a esta sucursal.');
    expect(
      container.read(authControllerProvider).context?.currentBranch?.id,
      2,
      reason: 'la sucursal activa no cambia si el servidor rechaza el cambio',
    );
  });

  test('cambio de sucursal: la sucursal activa no se vuelve a pedir', () async {
    final container = await _container(repository: _FakeAccountRepository());
    final current = container
        .read(authControllerProvider)
        .context!
        .currentBranch!;

    final switched = await container
        .read(branchSwitchControllerProvider.notifier)
        .switchTo(current);

    expect(switched, isFalse);
  });
}

