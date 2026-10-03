import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../data/models/auth_session.dart';

/// Servicio desacoplado de autenticación biométrica (huella / Face ID).
///
/// Envuelve `local_auth` para el prompt del sistema y `flutter_secure_storage`
/// para guardar —cifrado por el Keychain/Keystore del teléfono— **la sesión de
/// un login previo** (token de Sanctum + contexto). Ese token cifrado es el
/// "token de refresco" con el que se vuelve a entrar sin escribir la contraseña:
/// la app **nunca** guarda contraseñas en texto plano.
///
/// La biometría **solo** desbloquea credenciales que ya existían en el
/// dispositivo tras un inicio de sesión real; sin credenciales almacenadas el
/// servicio no autentica a nadie.
class BiometricsService {
  BiometricsService({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? storage,
  }) : _localAuth = localAuth ?? LocalAuthentication(),
       _storage = storage ?? const FlutterSecureStorage();

  /// Clave del almacenamiento seguro con la sesión para el acceso biométrico.
  /// Es distinta de `SessionStore.sessionKey` (la sesión que "mantiene abierta"
  /// el arranque automático), para que el token biométrico no se restaure solo.
  static const String credentialsKey = 'ezyventas.biometric.session';

  static const String defaultReason =
      'Inicia sesión en EzyVentas con tu biometría';

  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _storage;

  /// ¿El teléfono tiene hardware biométrico **con huellas/rostro inscritos**?
  ///
  /// `canCheckBiometrics` solo indica soporte de hardware; `getAvailableBiometrics`
  /// confirma que hay al menos una biometría inscrita y `isDeviceSupported` que el
  /// dispositivo ofrece autenticación local.
  Future<bool> checkBiometricsAvailable() async {
    try {
      if (!await _localAuth.canCheckBiometrics) {
        return false;
      }

      if (!await _localAuth.isDeviceSupported()) {
        return false;
      }

      final available = await _localAuth.getAvailableBiometrics();

      return available.isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// `true` si la biometría inscrita es rostro (para pintar Face ID y no huella).
  Future<bool> hasFaceBiometrics() async {
    try {
      final available = await _localAuth.getAvailableBiometrics();

      return available.contains(BiometricType.face);
    } on Object {
      return false;
    }
  }

  /// Lanza el prompt nativo del sistema. Devuelve `true` si la persona se
  /// autenticó con su huella o rostro.
  Future<bool> authenticateWithBiometrics({
    String reason = defaultReason,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on Object {
      return false;
    }
  }

  /// ¿Hay credenciales cifradas de un login previo en este teléfono?
  Future<bool> hasStoredCredentials() async {
    final raw = await _storage.read(key: credentialsKey);

    return raw != null && raw.isNotEmpty;
  }

  /// Lee la sesión guardada para el acceso biométrico, o `null` si no sirve.
  Future<AuthSession?> readStoredSession() async {
    final raw = await _storage.read(key: credentialsKey);
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

      return session.isUsable ? session : null;
    } on FormatException {
      return null;
    }
  }

  /// Guarda —cifrada— la sesión para futuros accesos biométricos.
  ///
  /// Solo se llama tras un login real con contraseña; el token se guarda en el
  /// almacenamiento seguro del sistema operativo.
  Future<void> saveSession(AuthSession session) =>
      _storage.write(key: credentialsKey, value: jsonEncode(session.toJson()));

  /// Borra las credenciales biométricas (p. ej. si el token ya no sirve).
  Future<void> clearCredentials() => _storage.delete(key: credentialsKey);
}

/// Servicio biométrico compartido por la app.
final biometricsServiceProvider = Provider<BiometricsService>(
  (ref) => BiometricsService(),
);
