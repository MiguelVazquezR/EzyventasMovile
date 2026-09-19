import 'dart:convert';

/// Error uniforme de la API `/api/v1`.
///
/// El backend siempre responde `{ "message": "...", "errors": { campo: [...] } }`
/// y, en los errores de negocio, añade `code` (`session_required`,
/// `cash_register_in_use`, `cash_register_in_use`, `already_cancelled`, ...).
///
/// Regla de la app: se muestra **siempre** `message` (ya viene en español) y se
/// usa `code` únicamente para decidir el flujo, nunca para inventar texto.
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.errors = const <String, List<String>>{},
    this.isNetworkError = false,
  });

  /// Construye el error a partir del cuerpo devuelto por el servidor.
  ///
  /// Si el cuerpo no trae `message` se usa el mismo texto por defecto que el
  /// backend (`ApiExceptionRenderer::defaultMessageFor`), de modo que la app
  /// nunca sustituye el mensaje del servidor por uno propio.
  factory ApiException.fromResponse(int? statusCode, Object? body) {
    final map = decodeBody(body);
    final rawMessage = map?['message'];
    final message = rawMessage is String ? rawMessage.trim() : '';

    return ApiException(
      message: message.isNotEmpty
          ? message
          : _defaultMessageFor(statusCode),
      statusCode: statusCode,
      code: map?['code'] is String ? map!['code'] as String : null,
      errors: _parseErrors(map?['errors']),
    );
  }

  /// Fallo de red: sin respuesta del servidor.
  factory ApiException.network() => const ApiException(
    message:
        'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
    isNetworkError: true,
  );

  /// Fallo inesperado del cliente (respuesta ilegible).
  factory ApiException.unexpected([Object? cause]) => const ApiException(
    message: 'Ocurrió un error al procesar la operación.',
  );

  final String message;

  /// Código HTTP (`null` si no hubo respuesta).
  final int? statusCode;

  /// Código de negocio del servidor (solo para decidir el flujo).
  final String? code;

  /// Errores de validación por campo (`422`).
  final Map<String, List<String>> errors;

  final bool isNetworkError;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isValidation => statusCode == 422;
  bool get isRateLimited => statusCode == 429;

  /// Primer error de validación, útil para `errors.status[0]`.
  String? errorFor(String field) {
    final list = errors[field];
    if (list == null || list.isEmpty) {
      return null;
    }

    return list.first;
  }

  /// `true` si algún campo trae errores.
  bool get hasFieldErrors => errors.values.any((messages) => messages.isNotEmpty);

  /// Decodifica el cuerpo de una respuesta en un mapa, si es posible.
  static Map<String, dynamic>? decodeBody(Object? body) {
    if (body == null) {
      return null;
    }

    if (body is Map<String, dynamic>) {
      return body;
    }

    if (body is Map) {
      return body.map((key, value) => MapEntry('$key', value));
    }

    if (body is String && body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry('$key', value));
        }
      } on FormatException {
        return null;
      }
    }

    return null;
  }

  static Map<String, List<String>> _parseErrors(Object? raw) {
    if (raw is! Map) {
      return const <String, List<String>>{};
    }

    final result = <String, List<String>>{};

    raw.forEach((key, value) {
      if (value is List) {
        result['$key'] = value.map((message) => '$message').toList();
      } else if (value != null) {
        result['$key'] = <String>['$value'];
      }
    });

    return result;
  }

  static String _defaultMessageFor(int? statusCode) {
    return switch (statusCode) {
      400 => 'La solicitud no es válida.',
      401 => 'No autenticado.',
      403 => 'Tu usuario no tiene permiso para esta acción.',
      404 => 'Recurso no encontrado.',
      409 =>
        'La operación entra en conflicto con el estado actual del sistema.',
      419 => 'Tu sesión expiró. Inicia sesión de nuevo.',
      422 => 'Los datos enviados no son válidos.',
      429 => 'Demasiadas solicitudes. Espera un momento e inténtalo de nuevo.',
      500 => 'Ocurrió un error en el servidor. Inténtalo de nuevo.',
      503 => 'El servicio no está disponible por el momento.',
      _ => 'Ocurrió un error al procesar la operación.',
    };
  }

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
