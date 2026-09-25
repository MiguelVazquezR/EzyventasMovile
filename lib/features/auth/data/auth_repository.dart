import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/session_store.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/uuid_generator.dart';
import 'models/access_context.dart';
import 'models/auth_session.dart';

/// Acceso a los endpoints de autenticaciÃ³n (`/auth/login|me|logout`).
///
/// Toda la lÃ³gica de negocio (permisos, mÃ³dulos, sucursal activa, turno de caja)
/// la decide el servidor; aquÃ­ solo se arma la peticiÃ³n y se persiste el
/// resultado.
class AuthRepository {
  AuthRepository({required this.api, required this.sessionStore});

  final ApiClient api;
  final SessionPersistence sessionStore;

  /// `POST /auth/login` â†’ token + contexto de acceso.
  ///
  /// Con [keepSession] en `false` el token **no** se guarda en el dispositivo: la
  /// sesión vive solo en memoria y al cerrar la app se vuelve al login.
  Future<AuthSession> login({
    required String email,
    required String password,
    bool keepSession = true,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.login,
      data: <String, dynamic>{
        'email': email.trim().toLowerCase(),
        'password': password,
        'device_name': resolveDeviceName(),
        'client_uuid': UuidGenerator.v4(),
      },
    );

    final session = AuthSession(
      token: JsonReader.stringOr(data['token'], ''),
      context: AccessContext.fromJson(data),
    );

    if (!session.isUsable) {
      throw ApiException.unexpected();
    }

    await sessionStore.saveSession(session, persist: keepSession);

    return session;
  }


  /// `GET /auth/me` â†’ contexto actualizado (permisos, sucursal, turno).
  Future<AccessContext> fetchAccessContext() async {
    final data = await api.getJson(ApiEndpoints.me);

    return AccessContext.fromJson(data);
  }

  /// `POST /auth/logout`. Revoca el token de **este** dispositivo.
  ///
  /// Aunque el servidor falle (token ya revocado, sin red), la sesiÃ³n local se
  /// limpia igualmente: la app nunca conserva un token que ya no sirve.
  Future<void> logout() async {
    try {
      await api.postJson(ApiEndpoints.logout);
    } finally {
      await sessionStore.clearSession();
    }
  }

  Future<AuthSession?> readStoredSession() => sessionStore.readSession();

  Future<void> saveSession(AuthSession session) =>
      sessionStore.saveSession(session);

  Future<void> clearSession() => sessionStore.clearSession();

  /// Nombre del dispositivo con el que Sanctum identifica el token.
  ///
  /// Se puede fijar con `--dart-define=DEVICE_NAME=...`; si no, se compone con
  /// el sistema operativo (sin depender de paquetes extra de identificaciÃ³n).
  static String resolveDeviceName() {
    const fallback = AppConfig.deviceName;

    if (kIsWeb) {
      return fallback;
    }

    final os = Platform.operatingSystem;
    final version = Platform.operatingSystemVersion
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final candidate = version.isEmpty ? '$fallback ($os)' : '$fallback ($os $version)';

    return candidate.length <= 120 ? candidate : candidate.substring(0, 120);
  }
}

