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

  /// Header `Host` que [ApiClient] añade a **todas** las peticiones.
  ///
  /// Por defecto vacío: en producción lo envía el sistema operativo a partir de
  /// `API_BASE_URL` y este valor **no** se define.
  ///
  /// Existe para un caso concreto del desarrollo: el servidor local (Laravel
  /// Herd) publica cada proyecto en un dominio `.test` que solo resuelve en el
  /// equipo donde corre Herd, y Herd escucha únicamente en `127.0.0.1`. Para
  /// probar en un teléfono físico se usa el túnel de `adb reverse` y la app se
  /// conecta a `https://127.0.0.1:8443/api/v1`; como Herd elige el sitio por el
  /// header `Host`, el túnel necesita declararlo:
  ///
  /// ```bash
  /// flutter run --dart-define=API_BASE_URL=https://127.0.0.1:8443/api/v1 \
  ///             --dart-define=API_HOST_HEADER=ezyventas2.test
  /// ```
  ///
  /// Ver README §4 ("Correr en un teléfono Android").
  static const String apiHostHeader = String.fromEnvironment(
    'API_HOST_HEADER',
    defaultValue: '',
  );

  /// Puerto del túnel USB (`adb reverse tcp:<puerto> tcp:443`) que usa el
  /// teléfono para llegar al Herd del equipo. Solo documental: la URL real va
  /// en `API_BASE_URL`.
  static const int devTunnelPort = 8443;

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Las evidencias fotográficas pesan más: timeout amplio.
  static const Duration uploadTimeout = Duration(minutes: 2);

  static const String currency = 'MXN';
  static const String locale = 'es_MX';

  /// Dominio de la web derivado de la base de la API
  /// (`https://host/api/v1` → `https://host`).
  ///
  /// Evita hardcodear el dominio del entorno: el release apunta al mismo host
  /// que `API_BASE_URL`.
  static String get webBaseUrl {
    final base = apiBaseUrl.endsWith('/')
        ? apiBaseUrl.substring(0, apiBaseUrl.length - 1)
        : apiBaseUrl;
    final marker = base.indexOf('/api/v1');

    return marker > 0 ? base.substring(0, marker) : base;
  }

  /// Checkout de la web para renovar o mejorar el plan (contrato §11b.5).
  ///
  /// La app **no** reimplementa el pago de Mercado Pago: solo abre esta dirección
  /// en el navegador externo.
  static String get subscriptionManageUrl => '$webBaseUrl/subscription/manage';

  /// Pie máximo (KB) de cada foto de diagnóstico aceptado por el servidor.
  static const int maxEvidenceImageKb = 2048;
  static const int maxEvidenceImages = 5;

  /// Pie máximo (KB) de la foto de perfil (`PUT /profile`, contrato §11b.4).
  static const int maxProfilePhotoKb = 1024;
}
