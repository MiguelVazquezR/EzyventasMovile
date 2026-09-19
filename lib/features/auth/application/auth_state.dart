import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../data/models/access_context.dart';
import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';

/// Estado de la sesión de la app.
enum AuthStatus {
  /// Todavía no se sabe si hay sesión guardada (pantalla de arranque).
  unknown,

  /// No hay sesión: se muestra el login.
  unauthenticated,

  /// Hay token utilizable: se muestra el cascarón de navegación.
  authenticated,
}

@immutable
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.isSubmitting = false,
    this.errorMessage,
    this.errorFields = const <String, List<String>>{},
    this.notice,
  });

  final AuthStatus status;
  final AuthSession? session;

  /// Petición de login en curso (el botón muestra su spinner).
  final bool isSubmitting;

  /// Mensaje del servidor que se muestra en el formulario.
  final String? errorMessage;

  /// Errores por campo (`errors` del `422`) para pintarlos bajo el input.
  final Map<String, List<String>> errorFields;

  /// Aviso puntual, por ejemplo "Tu sesión expiró. Inicia sesión de nuevo."
  final String? notice;

  AuthUser? get user => session?.context.user;

  AccessContext? get context => session?.context;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && session != null;

  bool get isBootstrapping => status == AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    bool? isSubmitting,
    String? errorMessage,
    Map<String, List<String>>? errorFields,
    String? notice,
    bool clearError = false,
    bool clearSession = false,
    bool clearNotice = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorFields: clearError
          ? const <String, List<String>>{}
          : (errorFields ?? this.errorFields),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  /// Convierte un fallo de la API en estado mostrable.
  AuthState withApiError(ApiException error) => copyWith(
    isSubmitting: false,
    errorMessage: error.message,
    errorFields: error.errors,
  );
}
