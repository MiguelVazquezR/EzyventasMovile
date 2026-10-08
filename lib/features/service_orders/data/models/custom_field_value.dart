/// Valor capturado de un campo personalizado, tipado (doc 04 §4).
///
/// Es la unión sellada que usa la app para no volver a razonar sobre `dynamic`:
/// cada tipo del catálogo tiene su clase y solo `pattern` es compuesto.
sealed class CustomFieldValue {
  const CustomFieldValue();

  /// Valor listo para `custom_fields[key]` del payload: tipos reales, nunca
  /// un JSON convertido a cadena (§6 y regla 4).
  Object? toJson();

  /// Sin contenido: `''`, `[]`, `0 puntos` o contraseña vacía.
  bool get isBlank;
}

/// `text` y `textarea` → string.
class TextValue extends CustomFieldValue {
  const TextValue(this.text);

  final String text;

  @override
  Object? toJson() => text;

  @override
  bool get isBlank => text.trim().isEmpty;
}

/// `number` → número real (`num`), nunca string (`"12"` se lee, no se escribe).
class NumberValue extends CustomFieldValue {
  const NumberValue(this.value);

  final num? value;

  @override
  Object? toJson() => value;

  @override
  bool get isBlank => value == null;
}

/// `boolean` → `true`/`false` reales (nunca el string `"false"`).
class BoolValue extends CustomFieldValue {
  const BoolValue(this.value);

  final bool value;

  @override
  Object? toJson() => value;

  @override
  bool get isBlank => false;
}

/// `select` → un solo string de `options`.
class SingleOptionValue extends CustomFieldValue {
  const SingleOptionValue(this.value);

  final String value;

  @override
  Object? toJson() => value;

  @override
  bool get isBlank => value.trim().isEmpty;
}

/// `checkbox` → arreglo de strings (`[]` es válido: «ninguno»).
class MultiOptionValue extends CustomFieldValue {
  const MultiOptionValue(this.options);

  final List<String> options;

  @override
  Object? toJson() => options;

  @override
  bool get isBlank => options.isEmpty;
}

/// `pattern` → único valor estructurado (§8).
///
/// `mode` es el **modo** elegido por el usuario (`pattern` dibujado o
/// `password` escrito), no el tipo del campo. `points` viene en orden de trazo
/// y `password` es el texto tal cual (se guarda en claro: el taller necesita el
/// desbloqueo para probar el equipo).
class PatternValue extends CustomFieldValue {
  const PatternValue.pattern(this.points)
    : mode = 'pattern',
      password = '';

  const PatternValue.password(this.password)
    : mode = 'password',
      points = const <int>[];

  /// `{'type':…,'value':…}` — el objeto completo viaja siempre así (§8.5.4).
  @override
  Object? toJson() => <String, dynamic>{
    'type': mode,
    'value': mode == 'password' ? password : points,
  };

  @override
  bool get isBlank =>
      mode == 'password' ? password.isEmpty : points.isEmpty;

  final String mode;
  final List<int> points;
  final String password;

  /// Contraseña enmascarada con `•` para listados y detalle (§8.1).
  String get maskedPassword =>
      password.isEmpty ? '' : List<String>.filled(password.length.clamp(1, 12), '•').join();

  /// Etiqueta del modo activo (sentence case, microcopy §11).
  String get modeLabel => mode == 'password' ? 'Contraseña' : 'Patrón';
}
