/// Lectura tolerante del JSON del servidor.
///
/// Evita `as` encadenados y `null` sueltos en cada `fromJson`: los mapas de la
/// API nunca tienen tipos garantizados (Laravel serializa `(float)`, strings y
/// `null` según el caso).
class JsonReader {
  const JsonReader._();

  /// Convierte cualquier valor en un mapa plano (`{}` si no lo es).
  static Map<String, dynamic> toMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }

    return const <String, dynamic>{};
  }

  /// Lista de mapas (ignora entradas que no sean objetos).
  static List<Map<String, dynamic>> toMapList(Object? value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => toMap(item))
        .toList(growable: false);
  }

  static String? string(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is String) {
      return value;
    }

    return '$value';
  }

  static String stringOr(Object? value, String fallback) =>
      string(value) ?? fallback;

  static int? integer(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(string(value) ?? '');
  }

  static int integerOr(Object? value, int fallback) => integer(value) ?? fallback;

  static bool boolean(Object? value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text = string(value)?.toLowerCase();

    return text == 'true' || text == '1';
  }

  /// Lista de cadenas (acepta `["a","b"]` o valores sueltos).
  static List<String> stringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .where((item) => item != null)
        .map((item) => '$item')
        .toList(growable: false);
  }

  /// Lista de enteros.
  static List<int> intList(Object? value) {
    if (value is! List) {
      return const <int>[];
    }

    return value
        .map(integer)
        .whereType<int>()
        .toList(growable: false);
  }
}
