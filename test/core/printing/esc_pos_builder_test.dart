import 'package:ezyventas_app/core/printing/cp850.dart';
import 'package:ezyventas_app/core/printing/esc_pos_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Cp850', () {
    test('mantiene el ASCII tal cual', () {
      expect(Cp850.encode('CORTE 2026 \$1,250.00'), <int>[
        0x43, 0x4F, 0x52, 0x54, 0x45, 0x20, 0x32, 0x30, 0x32, 0x36, // CORTE 2026
        0x20, 0x24, 0x31, 0x2C, 0x32, 0x35, 0x30, 0x2E, 0x30, 0x30, // $1,250.00
      ]);
    });

    test('codifica los acentos del castellano como CP850', () {
      // La web usa `codepage: cp850` en el servidor: los mismos bytes.
      expect(Cp850.encode('áéíóú'), <int>[0xA0, 0x82, 0xA1, 0xA2, 0xA3]);
      expect(Cp850.encode('ñÑ¿¡'), <int>[0xA4, 0xA5, 0xA8, 0xAD]);
      expect(Cp850.encode('ÁÉÍÓÚ'), <int>[0xB5, 0x90, 0xD6, 0xE0, 0xE9]);
      expect(Cp850.encode('Jos\u00E9 P\u00E9rez'), <int>[
        0x4A, 0x6F, 0x73, 0x82, 0x20, 0x50, 0x82, 0x72, 0x65, 0x7A,
      ]);
    });

    test('aproxima los signos que la impresora no tiene', () {
      expect(Cp850.encode('—'), <int>[0x2D]); // guion largo → guion
      expect(Cp850.encode('…'), <int>[0x2E]);
      expect(Cp850.encode('€'), <int>[0x3F]); // sin glifo → ?
    });
  });

  group('EscPosBuilder', () {
    test('emite los comandos de inicialización y de página de códigos', () {
      final bytes = (EscPosBuilder()..initialize()..selectCp850()).build();

      expect(bytes, <int>[0x1B, 0x40, 0x1B, 0x74, 0x02]);
    });

    test('emite inicio de ticket: alineación, negritas y doble tamaño', () {
      final bytes = (EscPosBuilder()
            ..align(EscPosAlign.center)
            ..bold(enabled: true)
            ..doubleSize(enabled: true)
            ..bold(enabled: false))
          .build();

      expect(bytes, <int>[
        0x1B, 0x61, 0x01, // centrado
        0x1B, 0x45, 0x01, // negritas activadas
        0x1D, 0x21, 0x11, // doble alto/ancho
        0x1B, 0x45, 0x00, // negritas apagadas
      ]);
    });

    test('cierra el ticket con avance, corte y pulso de cajón', () {
      final bytes = (EscPosBuilder()
            ..feed(2)
            ..cut()
            ..openDrawer())
          .build();

      expect(bytes.take(2), <int>[0x0A, 0x0A]);
      // GS V 66 0 → corte parcial.
      expect(bytes.sublist(2, 6), <int>[0x1D, 0x56, 0x42, 0x00]);
      // ESC p 0 25 250 → pulso del cajón.
      expect(bytes.sublist(bytes.length - 5), <int>[
        0x1B, 0x70, 0x00, 0x19, 0xFA,
      ]);
    });

    test('alinea la etiqueta y el valor dentro del ancho del papel', () {
      final bytes = (EscPosBuilder(charactersPerLine: 32)
            ..leftRight('TOTAL ESPERADO', '\$5,050.00'))
          .build();

      final line = String.fromCharCodes(bytes.sublist(0, 32));

      expect(line.startsWith('TOTAL ESPERADO'), isTrue);
      expect(line.endsWith('\$5,050.00'), isTrue);
      expect(line.length, 32);
      expect(bytes.last, 0x0A);
    });

    test('sin espacio pone el valor en su propia línea a la derecha', () {
      final builder = EscPosBuilder(charactersPerLine: 20)
        ..leftRight('TOTAL ESPERADO DEL TURNO', '\$5,050.00');

      final lines = String.fromCharCodes(builder.build()).split('\n');

      expect(lines.first, 'TOTAL ESPERADO DEL T');
      expect(lines[lines.length - 2], endsWith('\$5,050.00'));
      expect(lines[lines.length - 2].length, 20);
    });

    test('envuelve el texto largo en varias líneas', () {
      final bytes = (EscPosBuilder(charactersPerLine: 16)
            ..text('Sucursal Centro Zapateria'))
          .build();

      final lines = String.fromCharCodes(bytes).split('\n');

      expect(lines.length, 3);
      expect(lines.first, 'Sucursal Centro ');
      expect(lines.first.length, 16);
      expect(lines[1], 'Zapateria');
    });

    test('el separador ocupa todo el ancho del papel', () {
      final bytes = (EscPosBuilder(charactersPerLine: 32)..separator()).build();

      expect(String.fromCharCodes(bytes), '${'-' * 32}\n');
    });

    test('arma el renglón de tres columnas del corte', () {
      final bytes = (EscPosBuilder(charactersPerLine: 32)
            ..quantityRow('1', 'Cambio', '\$30.00'))
          .build();

      final line = String.fromCharCodes(bytes).trimRight();

      expect(line.length, 32);
      expect(line.startsWith('1'), isTrue);
      expect(line.contains('Cambio'), isTrue);
      expect(line.endsWith('\$30.00'), isTrue);
    });
  });
}
