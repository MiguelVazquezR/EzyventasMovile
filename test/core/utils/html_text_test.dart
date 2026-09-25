import 'package:ezyventas_app/core/utils/html_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// `HtmlText.toPlain`: las descripciones se capturan en la web con un editor de
/// texto enriquecido y llegan como HTML (`<p>dsfg</p>`); la app las muestra sin
/// etiquetas.
void main() {
  group('HtmlText.toPlain', () {
    test('quita las etiquetas de bloque y deja el texto', () {
      expect(HtmlText.toPlain('<p>dsfg</p>'), 'dsfg');
    });

    test('separa los párrafos con un salto de línea', () {
      expect(
        HtmlText.toPlain('<p>Primera <strong>línea</strong></p><p>Segunda</p>'),
        'Primera línea\nSegunda',
      );
    });

    test('respeta los saltos de <br> y limpia el espacio de las etiquetas', () {
      expect(HtmlText.toPlain('Uno<br>Dos<br />Tres'), 'Uno\nDos\nTres');
      expect(HtmlText.toPlain('<div>  a   b  </div>'), 'a b');
    });

    test('decodifica las entidades del editor', () {
      expect(
        HtmlText.toPlain('Precio&nbsp;final &amp; listo'),
        'Precio final & listo',
      );
      expect(HtmlText.toPlain('caf&#39;&eacute;'), "caf'é");
    });

    test('el texto sin marcas se deja tal cual (sin los extremos)', () {
      expect(HtmlText.toPlain('  Filtro de aceite  '), 'Filtro de aceite');
    });

    test('null o vacío devuelve cadena vacía', () {
      expect(HtmlText.toPlain(null), '');
      expect(HtmlText.toPlain('   '), '');
      expect(HtmlText.toPlain('<p></p>'), '');
    });

    test('no deja líneas vacías de sobra', () {
      expect(HtmlText.toPlain('<p>a</p><p></p><p>b</p>'), 'a\nb');
    });
  });
}
