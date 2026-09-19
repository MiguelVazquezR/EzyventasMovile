/// Configuración de entorno de la app.
///
/// La URL base **nunca** se escribe dentro de un widget: se inyecta al compilar
/// con `--dart-define=API_BASE_URL=https://ezyventas2.test/api/v1`.
///
/// El valor por defecto apunta al entorno local de desarrollo; los builds de
/// release deben sobreescribirlo (ver `README.md`).
class AppConfig {
  const AppConfig._();

  /// Base URL de la API REST `/api/v1` del backend Laravel.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ezyventas2.test/api/v1',
  );

  /// Nombre con el que Sanctum identifica el token de este dispositivo.
  static const String deviceName = String.fromEnvironment(
    'DEVICE_NAME',
    defaultValue: 'EzyVentas Android',
  );

  /// Acepta el certificado autofirmado del servidor local.
  ///
  /// Solo se aplica cuando `kDebugMode` es verdadero (ver `ApiClient`): en
  /// release el certificado se valida siempre.
  static const bool allowBadCertificate = bool.fromEnvironment(
    'ALLOW_BAD_CERTIFICATE',
    defaultValue: true,
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Las evidencias fotográficas pesan más: timeout amplio.
  static const Duration uploadTimeout = Duration(minutes: 2);

  static const String currency = 'MXN';
  static const String locale = 'es_MX';

  /// Pie máximo (KB) de cada foto de diagnóstico aceptado por el servidor.
  static const int maxEvidenceImageKb = 2048;
  static const int maxEvidenceImages = 5;
}
