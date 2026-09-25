import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/models/auth_session.dart';

/// Contrato de persistencia de la sesión.
///
/// Permite sustituir el almacenamiento seguro por un doble en pruebas (la app
/// usa [SessionStore], que guarda en `flutter_secure_storage`).
abstract class SessionPersistence {
  Future<String?> readToken();

  Future<AuthSession?> readSession();

  /// Guarda [session] en el almacenamiento seguro.
  ///
  /// Con `persist: false` la sesión vive **solo en memoria** (el usuario no marcó
  /// "mantener la sesión abierta"): al cerrar la app hay que volver a iniciar
  /// sesión. `persist: null` conserva el modo de la sesión en curso.
  Future<void> saveSession(AuthSession session, {bool? persist});

  Future<void> clearSession();
}

/// Guarda la sesión (token + contexto) en el almacenamiento seguro del sistema.
///
/// La app **nunca** sube credenciales al repositorio: el token vive aquí y se
/// borra al cerrar sesión o al recibir un `401`.
class SessionStore implements SessionPersistence {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String sessionKey = 'ezyventas.session';
  static const String themeModeKey = 'ezyventas.theme_mode';

  final FlutterSecureStorage _storage;

  AuthSession? _cached;
  bool _isLoaded = false;

  /// `true` mientras la sesión en curso deba quedar guardada en el dispositivo.
  bool _persist = true;

  /// Token en memoria (se lee del almacenamiento seguro solo la primera vez).
  @override
  Future<String?> readToken() async => (await readSession())?.token;

  @override
  Future<AuthSession?> readSession() async {
    if (_isLoaded) {
      return _cached;
    }

    _isLoaded = true;
    final raw = await _storage.read(key: sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }

      final session = AuthSession.fromJson(
        decoded.map((key, value) => MapEntry('$key', value)),
      );

      _cached = session.isUsable ? session : null;
    } on FormatException {
      _cached = null;
    }

    return _cached;
  }

  @override
  Future<void> saveSession(AuthSession session, {bool? persist}) async {
    if (persist != null) {
      _persist = persist;
    }

    _cached = session;
    _isLoaded = true;

    if (!_persist) {
      // Sin "mantener la sesión abierta": se borra lo que hubiera guardado para
      // que el arranque siguiente no restaure nada.
      await _storage.delete(key: sessionKey);
      return;
    }

    await _storage.write(
      key: sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> clearSession() async {
    _cached = null;
    _isLoaded = true;
    _persist = true;
    await _storage.delete(key: sessionKey);
  }


  /// Preferencia local del tema (`dark` por defecto).
  Future<String?> readThemeMode() => _storage.read(key: themeModeKey);

  Future<void> saveThemeMode(String mode) =>
      _storage.write(key: themeModeKey, value: mode);
}
