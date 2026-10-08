import 'custom_field_definition.dart';
import 'custom_field_normalizers.dart';
import 'custom_field_value.dart';

/// Bolsa `custom_fields` de una orden: `{ "<key>": <valor> }` (doc 04 §2.2).
///
/// Se serializa **idéntica** al contrato (§4): tipos reales, el checkbox vacío
/// como `[]` y el patrón como objeto completo. La app guarda esta bolsa en su
/// estado y la reenvía completa en el `POST` y en el `PUT` (el `PUT` reemplaza
/// el JSON entero, así que nunca se derivan los campos al vuelo).
class CustomFieldsBag {
  const CustomFieldsBag(this.values);

  const CustomFieldsBag.empty() : values = const <String, dynamic>{};

  /// Los valores tal como llegaron (sin normalizar): solo para conservarlos.
  factory CustomFieldsBag.fromJson(Map<String, dynamic> json) =>
      CustomFieldsBag(Map<String, dynamic>.of(json));

  /// Bolsa del formulario: una entrada por definición, en el orden de la API.
  ///
  /// - Si la orden ya guarda `custom_fields[key]`, ese valor manda, normalizado
  ///   al tipo de la definición (§5.2).
  /// - Si no, se usa el valor inicial del tipo (§5).
  /// - Las claves **huérfanas** (sin definición) se conservan al final con su
  ///   valor original: el `PUT` reemplaza la bolsa completa y no debe borrarlas.
  factory CustomFieldsBag.initialFor(
    List<CustomFieldDefinition> definitions, {
    Map<String, dynamic> stored = const <String, dynamic>{},
  }) {
    final values = <String, dynamic>{};

    for (final definition in definitions) {
      if (definition.key.isEmpty) {
        continue;
      }

      values[definition.key] = stored.containsKey(definition.key)
          ? normalizeForType(definition.type, stored[definition.key])
          : initialValueFor(definition.type);
    }

    for (final entry in stored.entries) {
      values.putIfAbsent(entry.key, () => entry.value);
    }

    return CustomFieldsBag(values);
  }

  /// `{ "<key>": <valor> }` con los tipos reales de cada tipo.
  final Map<String, dynamic> values;

  bool get isEmpty => values.isEmpty;

  bool containsKey(String key) => values.containsKey(key);

  /// Valor crudo guardado (normalizado al escribir, no al leer).
  Object? raw(String key) => values[key];

  /// Valor tipado según la definición: el tipo lo dicta la definición (§4).
  CustomFieldValue typed(CustomFieldDefinition definition) =>
      parseCustomFieldValue(definition.type, values[definition.key]);

  /// Bolsa nueva con `key` actualizada (el estado es inmutable).
  CustomFieldsBag withValue(String key, Object? value) =>
      CustomFieldsBag(<String, dynamic>{...values, key: value});

  /// Claves guardadas que ya no tienen definición (definiciones borradas o
  /// renombradas): se pintan al final como texto plano (§9.3).
  List<String> orphanKeys(List<CustomFieldDefinition> definitions) {
    final known = <String>{
      for (final definition in definitions) definition.key,
    };

    return values.keys.where((key) => !known.contains(key)).toList(
      growable: false,
    );
  }

  /// Cuerpo del payload: estructura real, nunca una cadena JSON (§6).
  Map<String, dynamic> toJson() => Map<String, dynamic>.of(values);
}
