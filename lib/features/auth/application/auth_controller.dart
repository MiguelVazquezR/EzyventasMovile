import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/auth/permissions_service.dart';
import '../../cash/data/models/active_cash_session.dart';
import '../data/auth_repository.dart';
import '../data/models/access_context.dart';
import '../data/models/auth_session.dart';
import 'auth_state.dart';

/// Repositorio de autenticación.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  );
});

/// Sesión de la app: token, usuario, permisos, módulos y turno de caja.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Permisos efectivos calculados por el servidor.
final permissionsProvider = Provider<PermissionsService>((ref) {
  final context = ref.watch(authControllerProvider).context;
  if (context == null) {
    return const PermissionsService.empty();
  }

  return PermissionsService.fromLists(
    permissions: context.user.permissions,
    moduleKeys: context.moduleKeys,
  );
});

/// Pestañas visibles del cascarón, en orden (las que pinta el menú lateral).
final visibleTabsProvider = Provider<List<AppTab>>(
  (ref) => ref.watch(permissionsProvider).visibleTabs,
);

/// Turno de caja activo (lo comparten POS y la pestaña Caja).
final activeCashSessionProvider = Provider<ActiveCashSession?>(
  (ref) => ref.watch(authControllerProvider).context?.activeSession,
);

/// Controlador de la sesión: arranque, login, refresco de contexto y logout.
class AuthController extends Notifier<AuthState> {
  static const String sessionExpiredNotice =
      'Tu sesión expiró. Inicia sesión de nuevo.';

  bool _isDisposed = false;

  @override
  AuthState build() {
    final api = ref.watch(apiClientProvider);
    api.onUnauthorized = _handleUnauthorized;

    ref.onDispose(() {
      _isDisposed = true;
      if (api.onUnauthorized == _handleUnauthorized) {
        api.onUnauthorized = null;
      }
    });

    // Restauración diferida: `build` debe ser síncrono.
    Future<void>.microtask(restoreSession);

    return const AuthState();
  }

  /// Al arrancar: si hay token guardado se entra directo y luego se refresca
  /// `GET /auth/me`; si es `401`, se limpia todo y se vuelve al login.
  Future<void> restoreSession() async {
    final repository = ref.read(authRepositoryProvider);

    final stored = await repository.readStoredSession();
    if (stored == null) {
      _setState(const AuthState(status: AuthStatus.unauthenticated));
      return;
    }

    _setState(
      AuthState(status: AuthStatus.authenticated, session: stored),
    );

    await refreshContext();
  }

  /// Refresca permisos, módulos, sucursal y turno con `GET /auth/me`.
  Future<void> refreshContext() async {
    final current = state.session;
    if (current == null) {
      return;
    }

    try {
      final context = await ref
          .read(authRepositoryProvider)
          .fetchAccessContext();
      final updated = AuthSession(token: current.token, context: context);
      await ref.read(authRepositoryProvider).saveSession(updated);
      _setState(
        state.copyWith(
          session: updated,
          status: AuthStatus.authenticated,
          clearError: true,
        ),
      );
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        await _clearSession(notice: sessionExpiredNotice);
        return;
      }

      // Sin conexión o error del servidor: se conserva el contexto en caché
      // (regla de oro: la app no se bloquea por un fallo de red al arrancar).
    }
  }

  /// Aplica un contexto de acceso ya calculado por el servidor.
  ///
  /// Lo usa `PUT /branch/switch/{id}`, que devuelve el contexto completo de la
  /// sucursal nueva (permisos, módulos, caja). No vuelve a pedir `/auth/me`: el
  /// refresco se hace después, para confirmar contra el servidor.
  Future<void> applyContext(AccessContext context) async {
    final current = state.session;
    if (current == null) {
      return;
    }

    final updated = AuthSession(token: current.token, context: context);

    await ref.read(authRepositoryProvider).saveSession(updated);
    _setState(
      state.copyWith(session: updated, status: AuthStatus.authenticated),
    );
  }

  /// `POST /auth/login`. Devuelve `true` si la sesión quedó iniciada.
  ///
  /// [keepSession] viene del check «Mantener la sesión abierta» del login: en
  /// `false` el token no se guarda en el teléfono.
  Future<bool> login({
    required String email,
    required String password,
    bool keepSession = true,
  }) async {
    _setState(
      state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearNotice: true,
      ),
    );

    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(
            email: email,
            password: password,
            keepSession: keepSession,
          );

      _setState(AuthState(status: AuthStatus.authenticated, session: session));

      return true;
    } on ApiException catch (error) {
      _setState(state.withApiError(error));

      return false;
    }
  }

  /// `POST /auth/logout` + limpieza local del token.
  Future<void> logout() async {
    _setState(state.copyWith(isSubmitting: true));

    try {
      await ref.read(authRepositoryProvider).logout();
    } on ApiException {
      // El repositorio ya limpió la sesión local: el 401/403 no debe impedir
      // que el usuario salga.
    }

    _setState(const AuthState(status: AuthStatus.unauthenticated));
  }

  /// Descarta el aviso pendiente (por ejemplo al mostrarlo una vez).
  void consumeNotice() {
    if (state.notice != null) {
      _setState(state.copyWith(clearNotice: true));
    }
  }

  /// Sincroniza el turno de caja con la sesión **sin** volver a pedir
  /// `/auth/me`: la apertura, la unión y el corte ya devuelven la sesión
  /// definitiva, así que el POS queda habilitado de inmediato.
  ///
  /// Con `null` se limpia el turno (corte o salida del turno).
  Future<void> setActiveSession(ActiveCashSession? session) async {
    final current = state.session;
    if (current == null) {
      return;
    }

    // Sin cambios reales no se reescribe el almacenamiento seguro (el POS
    // refresca el turno cada vez que vuelve a primer plano).
    if (_sameSession(current.context.activeSession, session)) {
      return;
    }

    final updated = AuthSession(
      token: current.token,
      context: current.context.copyWith(
        activeSession: session,
        clearActiveSession: session == null,
      ),
    );

    await ref.read(authRepositoryProvider).saveSession(updated);
    _setState(
      state.copyWith(session: updated, status: AuthStatus.authenticated),
    );
  }

  static bool _sameSession(ActiveCashSession? a, ActiveCashSession? b) {
    if (a == null || b == null) {
      return a == null && b == null;
    }

    return a.id == b.id &&
        a.status == b.status &&
        a.users.length == b.users.length &&
        a.totals.total == b.totals.total;
  }

  void _handleUnauthorized() {
    if (_isDisposed || state.status == AuthStatus.unauthenticated) {
      return;
    }

    Future<void>.microtask(
      () => _clearSession(notice: sessionExpiredNotice),
    );
  }

  Future<void> _clearSession({String? notice}) async {
    await ref.read(authRepositoryProvider).clearSession();
    _setState(AuthState(status: AuthStatus.unauthenticated, notice: notice));
  }

  void _setState(AuthState next) {
    if (!_isDisposed) {
      state = next;
    }
  }
}
