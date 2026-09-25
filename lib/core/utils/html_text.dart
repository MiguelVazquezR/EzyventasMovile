/// Texto plano a partir del texto enriquecido que guarda el servidor.
///
/// Las descripciones de producto y los campos largos se capturan con un editor
/// de la web y llegan como HTML (`<p>dsfg</p>`, `<strong>`, `&nbsp;`…). La app
/// no renderiza HTML: muestra el texto, sin etiquetas.
///
/// Es una limpieza de presentación, **no** un parser: no hay que escaparlo ni
/// volver a inyectarlo en HTML en ninguna parte.
class HtmlText {
  const HtmlText._();

  /// Etiquetas que separan bloques (`<p>`, `<br>`, `</div>`, `</li>`…) → salto.
  static final RegExp _blockTag = RegExp(
    r'<\s*/?\s*(br|p|div|li|ul|ol|h[1-6]|tr|blockquote)\s*/?\s*>',
    caseSensitive: false,
  );

  static final RegExp _anyTag = RegExp(r'<[^>]*>');
  static final RegExp _entity = RegExp(r'&(#?[a-zA-Z0-9]+);');
  static final RegExp _inlineSpaces = RegExp(r'[ \t\u00A0]+');
  static final RegExp _blankLines = RegExp(r'\n{3,}');

  /// Entidades con nombre que aparecen en el contenido real (`&nbsp;` sobre todo).
  static const Map<String, String> _entities = <String, String>{
    'nbsp': ' ',
    'amp': '&',
    'lt': '<',
    'gt': '>',
    'quot': '"',
    'apos': "'",
    'laquo': '«',
    'raquo': '»',
    'hellip': '…',
    'mdash': '—',
    'ndash': '–',
    'middot': '·',
    'deg': '°',
    'aacute': 'á',
    'eacute': 'é',
    'iacute': 'í',
    'oacute': 'ó',
    'uacute': 'ú',
    'ntilde': 'ñ',
    'uuml': 'ü',
    'Aacute': 'Á',
    'Eacute': 'É',
    'Iacute': 'Í',
    'Oacute': 'Ó',
    'Uacute': 'Ú',
    'Ntilde': 'Ñ',
    'Uuml': 'Ü',
    'iexcl': '¡',
    'iquest': '¿',
    'euro': '€',
    'nbsp;': ' ',
  };

  /// Texto legible de [html] (`null` o vacío → cadena vacía).
  static String toPlain(String? html) {
    final raw = html ?? '';

    if (raw.trim().isEmpty) {
      return '';
    }

    // Texto sin marcas: se deja tal cual (solo se recortan los extremos).
    if (!raw.contains('<') && !raw.contains('&')) {
      return raw.trim();
    }

    final withoutTags = raw
        .replaceAll(_blockTag, '\n')
        .replaceAll(_anyTag, '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final decoded = withoutTags.replaceAllMapped(
      _entity,
      (match) => _decodeEntity(match.group(1)!, match.group(0)!),
    );

    final lines = decoded
        .split('\n')
        .map((line) => line.replaceAll(_inlineSpaces, ' ').trim())
        .where((line) => line.isNotEmpty);

    return lines.join('\n').replaceAll(_blankLines, '\n\n').trim();
  }

  static String _decodeEntity(String token, String fallback) {
    if (token.startsWith('#')) {
      final numeric = token.substring(1);
      final code = numeric.toLowerCase().startsWith('x')
          ? int.tryParse(numeric.substring(1), radix: 16)
          : int.tryParse(numeric);

      if (code == null || code <= 0 || code > 0x10FFFF) {
        return fallback;
      }

      return String.fromCharCode(code);
    }

    return _entities[token] ?? fallback;
  }
}
