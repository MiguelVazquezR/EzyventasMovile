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

  /// Sitio web público de EzyVentas.
  ///
  /// Es fijo a propósito: el login del teléfono abre el sitio de producción
  /// aunque la API del build apunte al servidor local o al túnel USB.
  static const String websiteUrl = 'https://ezyventas.com';

  /// Login de la web (el enlace que ofrece la pantalla de inicio de sesión).
  static const String webLoginUrl = '$websiteUrl/login';


  /// URL de un medio del servidor lista para descargar desde este dispositivo.
  ///
  /// Los medios llegan con **URL absoluta** al host del servidor
  /// (`https://ezyventas2.test/storage/6/iphone.png`). En el teléfono físico ese
  /// dominio **no resuelve** (comprobado: `ping: unknown host ezyventas2.test`),
  /// así que la imagen nunca cargaba y `Image.network` caía siempre en su
  /// marcador. Cuando la app corre contra el túnel USB (`API_HOST_HEADER`), el
  /// origen se reescribe al de [apiBaseUrl] (`https://127.0.0.1:8443`) y
  /// [mediaHeaders] añade el `Host` con el que Herd elige el sitio.
  ///
  /// En producción (sin `API_HOST_HEADER`) devuelve la URL tal cual, y los hosts
  /// externos (`ui-avatars.com`, `placehold.co`) **nunca** se reescriben.
  ///
  /// Devuelve `null` cuando no hay una URL utilizable.
  static Uri? mediaUri(
    String? url, {
    String hostHeader = apiHostHeader,
    String apiBaseUrlOverride = apiBaseUrl,
  }) {
    final raw = url?.trim() ?? '';

    if (raw.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(raw);

    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }

    if (hostHeader.isEmpty || parsed.host != hostHeader) {
      return parsed;
    }

    final base = Uri.tryParse(apiBaseUrlOverride);

    if (base == null || base.host.isEmpty) {
      return parsed;
    }

    return parsed.replace(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );
  }

  /// Headers con los que descargar un medio por el túnel USB (vacío en release).
  static Map<String, String> get mediaHeaders => apiHostHeader.isEmpty
      ? const <String, String>{}
      : <String, String>{'Host': apiHostHeader};

  /// Intentos de descarga de un medio, **en orden**.
  ///
  /// `Image.network` no reintenta: si el primer origen no es alcanzable desde el
  /// teléfono, la imagen se queda en el marcador de la pantalla (`ServerImage`
  /// los prueba uno tras otro).
  ///
  /// 1. **Con túnel USB** (`API_HOST_HEADER`): primero el origen de la API con el
  ///    `Host` del vhost de Herd y después la URL tal cual (por si el dominio sí
  ///    resuelve en la red donde está el teléfono).
  /// 2. **Sin túnel**: la URL tal cual y, si el archivo vive en el `/storage/`
  ///    de otro host, un intento contra el origen de la API con ese `Host` (el
  ///    caso de un APK al servidor local sin `API_HOST_HEADER`).
  ///
  /// Los hosts externos (`placehold.co`, `ui-avatars.com`) nunca se reescriben y
  /// una imagen sin URL no genera intentos.
  static List<MediaRequest> mediaRequests(
    String? url, {
    String hostHeader = apiHostHeader,
    String apiBaseUrlOverride = apiBaseUrl,
  }) {
    final raw = url?.trim() ?? '';

    if (raw.isEmpty) {
      return const <MediaRequest>[];
    }

    final parsed = Uri.tryParse(raw);

    if (parsed == null) {
      return const <MediaRequest>[];
    }

    final base = Uri.tryParse(apiBaseUrlOverride);
    final hasBase = base != null && base.host.isNotEmpty;

    // Ruta relativa del servidor (`/storage/6/iphone.png`): se resuelve contra
    // el origen de la API (el dominio del servidor no resuelve en el teléfono).
    if (!parsed.hasScheme) {
      if (!hasBase || !parsed.path.startsWith('/storage/')) {
        return const <MediaRequest>[];
      }

      return <MediaRequest>[
        MediaRequest(
          uri: Uri.parse('${base.scheme}://${base.authority}').replace(
            path: parsed.path,
            query: parsed.hasQuery ? parsed.query : null,
          ),
        ),
      ];
    }

    if (parsed.host.isEmpty) {
      return const <MediaRequest>[];
    }

    Uri viaApi() => parsed.replace(
      scheme: base!.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
    );

    if (hostHeader.isNotEmpty && parsed.host == hostHeader) {
      return <MediaRequest>[
        if (hasBase)
          MediaRequest(
            uri: viaApi(),
            headers: <String, String>{'Host': hostHeader},
          ),
        MediaRequest(uri: parsed),
      ];
    }

    return <MediaRequest>[
      MediaRequest(uri: parsed),
      if (hasBase && parsed.path.startsWith('/storage/') && parsed.host != base.host)
        MediaRequest(
          uri: viaApi(),
          headers: <String, String>{'Host': parsed.host},
        ),
    ];
  }

  /// Pie máximo (KB) de cada foto de diagnóstico aceptado por el servidor.
  static const int maxEvidenceImageKb = 2048;
  static const int maxEvidenceImages = 5;

  /// Pie máximo (KB) de la foto de perfil (`PUT /profile`, contrato §11b.4).
  static const int maxProfilePhotoKb = 1024;
}

/// Un intento de descarga de un medio del servidor: URL + headers de la
/// petición (`Host` del vhost cuando se usa el túnel USB).
class MediaRequest {
  const MediaRequest({
    required this.uri,
    this.headers = const <String, String>{},
  });

  final Uri uri;
  final Map<String, String> headers;
}
