import '../../../../core/utils/json_reader.dart';

/// Catálogo de tipos de campo personalizado que valida el backend
/// (`CustomFieldDefinitionController`, doc 04 §4).
///
/// ⚠️ El comentario de la migración (`text, number, boolean, textarea`) está
/// desactualizado: el catálogo real es el que está aquí, con siete entradas.
class CustomFieldTypes {
  const CustomFieldTypes._();

  static const String text = 'text';
  static const String number = 'number';
  static const String textarea = 'textarea';
  static const String boolean = 'boolean';
  static const String select = 'select';
  static const String checkbox = 'checkbox';
  static const String pattern = 'pattern';

  /// Los siete tipos del catálogo, en el orden del documento 04 §4.
  static const List<String> all = <String>[
    text,
    number,
    textarea,
    boolean,
    select,
    checkbox,
    pattern,
  ];

  /// `select` y `checkbox` son los únicos que usan `options`.
  static bool usesOptions(String type) => type == select || type == checkbox;
}

/// Definición («molde») de un campo personalizado
/// (`custom_field_definitions`, doc 04 §2.1).
///
/// Llega por dos vías con la misma forma: `GET /service-orders/custom-fields`
/// (alta) y la llave `custom_field_definitions` del detalle (edición). El
/// `key` es **inmutable** (se genera una sola vez con `Str::snake` del `name`),
/// así que la app indexa siempre por `key` y nunca por `name`.
class CustomFieldDefinition {
  const CustomFieldDefinition({
    this.id = 0,
    required this.key,
    required this.name,
    required this.type,
    this.options = const <String>[],
    this.isRequired = false,
  });

  factory CustomFieldDefinition.fromJson(Map<String, dynamic> json) =>
      CustomFieldDefinition(
        id: JsonReader.integerOr(json['id'], 0),
        key: JsonReader.stringOr(json['key'], ''),
        name: JsonReader.stringOr(json['name'], ''),
        type: JsonReader.stringOr(json['type'], CustomFieldTypes.text),
        options: JsonReader.stringList(json['options']),
        isRequired: JsonReader.boolean(json['is_required']),
      );

  /// Se manda tal cual al servidor; la app **no** gestiona definiciones (§11).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'key': key,
    'name': name,
    'type': type,
    'options': options.isEmpty ? null : options,
    'is_required': isRequired,
  };

  final int id;
  final String key;
  final String name;

  /// Uno de [CustomFieldTypes]; un tipo nuevo del servidor degrada a texto.
  final String type;

  /// Arreglo de strings; solo tiene sentido en `select` y `checkbox`.
  final List<String> options;
  final bool isRequired;

  bool get isText => type == CustomFieldTypes.text;
  bool get isTextarea => type == CustomFieldTypes.textarea;
  bool get isNumber => type == CustomFieldTypes.number;
  bool get isBoolean => type == CustomFieldTypes.boolean;
  bool get isSelect => type == CustomFieldTypes.select;
  bool get isCheckbox => type == CustomFieldTypes.checkbox;
  bool get isPattern => type == CustomFieldTypes.pattern;

  /// `false` para los tipos que este documento no conoce: se pinta como texto.
  bool get isKnown => CustomFieldTypes.all.contains(type);

  /// `select`/`checkbox` sin `options`: el campo se apaga con el aviso
  /// «Sin opciones configuradas» (§11).
  bool get hasNoOptions =>
      CustomFieldTypes.usesOptions(type) && options.isEmpty;
}

/// Nombre anterior del modelo (se conserva para no tocar los llamadores del
/// detalle y del repositorio).
typedef ServiceOrderCustomFieldDefinition = CustomFieldDefinition;
