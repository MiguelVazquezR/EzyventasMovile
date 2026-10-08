import 'custom_field_definition.dart';
import 'custom_field_value.dart';

/// Normalizadores de lectura de campos personalizados (doc 04 §7.1 y §8.4).
///
/// El servidor **no** valida ni transforma los valores: un mismo campo puede
/// llegar como `true`, `"1"`, `1` o `"true"` según quién lo escribió (web,
/// JSON de la API o multipart). Estos normalizadores son el **único** lugar
/// donde se toleran esas variantes: todo lo que decide el widget la llama
/// antes de pintar o de enviar.

/// Valor «vacío» para cualquier tipo: `null`, `''` o un arreglo/objeto vacío.
bool isBlank(Object? value) {
  if (value == null) {
    return true;
  }

  if (value is String) {
    return value.trim().isEmpty;
  }

  if (value is List) {
    return value.isEmpty;
  }

  if (value is Map) {
    return value.isEmpty;
  }

  return false;
}

/// `boolean` → acepta `true`/`false` y las representaciones string de multipart.
bool normalizeBool(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  final text = value?.toString().toLowerCase().trim();

  return text == '1' || text == 'true' || text == 'si' || text == 'sí';
}

/// `checkbox` → siempre lista de strings, sin repetidos y sin vacíos.
List<String> normalizeList(Object? value) {
  if (value == null) {
    return const <String>[];
  }

  if (value is List) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  if (value is String) {
    // Datos históricos capturados como texto: "Funda, Mica".
    return value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  return <String>[value.toString()];
}

/// `number` → `num?` (acepta `"12"`, `12` y `''` → `null`).
num? normalizeNumber(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value;
  }

  return num.tryParse(value.toString().replaceAll(',', '').trim());
}

/// `pattern` → tolera los cuatro estados de §8.3: objeto con `type`, mapa sin
/// `type` (histórico), arreglo suelto (`[]` es el valor inicial del formulario
/// web) y string suelto (se trata como contraseña).
PatternValue normalizePattern(Object? value) {
  if (value is Map && value['type'] == 'password') {
    return PatternValue.password((value['value'] ?? '').toString());
  }

  if (value is Map) {
    return PatternValue.pattern(_points(value['value']));
  }

  if (value is List) {
    return PatternValue.pattern(_points(value));
  }

  if (value is String && value.trim().isNotEmpty) {
    return PatternValue.password(value.trim());
  }

  return const PatternValue.pattern(<int>[]);
}

/// Traza solo los puntos válidos del tablero 3×3 (1..9), en orden de gesto.
List<int> _points(Object? raw) => (raw is List ? raw : const <Object>[])
    .map((item) => int.tryParse(item.toString()) ?? 0)
    .where((point) => point >= 1 && point <= 9)
    .toList(growable: false);

/// Traduce un valor crudo al tipo que dicta la **definición** (§4).
///
/// Un `"1"` en un campo `boolean` es `true`; el mismo `"1"` en un campo `text`
/// es el texto `"1"`. El tipo del valor recibido nunca manda.
CustomFieldValue parseCustomFieldValue(String type, Object? raw) =>
    switch (type) {
      CustomFieldTypes.boolean => BoolValue(normalizeBool(raw)),
      CustomFieldTypes.number => NumberValue(normalizeNumber(raw)),
      CustomFieldTypes.checkbox => MultiOptionValue(normalizeList(raw)),
      CustomFieldTypes.pattern => normalizePattern(raw),
      CustomFieldTypes.select => SingleOptionValue(raw?.toString() ?? ''),
      // `text`, `textarea` y cualquier tipo desconocido degradan a texto.
      _ => TextValue(raw?.toString() ?? ''),
    };

/// Valor con el que arranca el formulario cuando la orden aún no guarda nada
/// (doc 04 §5): el switch apagado, el checkbox y el patrón como arreglo vacío y
/// el resto en `null` (no se inventan ceros ni cadenas).
Object? initialValueFor(String type) => switch (type) {
  CustomFieldTypes.boolean => false,
  CustomFieldTypes.checkbox => <String>[],
  CustomFieldTypes.pattern => <int>[],
  _ => null,
};

/// Convierte un valor guardado en su forma canónica para volver a enviarlo: el
/// booleano siempre `true`/`false`, el número `num`, el checkbox un arreglo de
/// strings y el patrón el objeto completo (§8.5).
Object? normalizeForType(String type, Object? raw) => switch (type) {
  CustomFieldTypes.boolean => normalizeBool(raw),
  CustomFieldTypes.number => normalizeNumber(raw),
  CustomFieldTypes.checkbox => normalizeList(raw),
  CustomFieldTypes.pattern => parseCustomFieldValue(type, raw).toJson(),
  CustomFieldTypes.select ||
  CustomFieldTypes.text ||
  CustomFieldTypes.textarea => raw?.toString(),
  _ => raw,
};

/// Etiqueta de reserva para un `key` huérfano (sin definición): `_` → espacio y
/// la primera letra en mayúscula (§9.3).
String labelFromKey(String key) {
  final words = key
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (words.isEmpty) {
    return 'Campo';
  }

  return words[0].toUpperCase() + words.substring(1);
}

/// Texto con el que se pinta un valor vacío o no establecido (§9.2).
const String notSetLabel = 'N/A';
