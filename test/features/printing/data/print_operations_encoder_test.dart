import 'dart:convert';

import 'package:ezyventas_app/features/printing/data/print_operations_encoder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Operación de ticket como la manda el servidor (§10).
Map<String, dynamic> codepageOperation(String raw, {String codepage = 'cp850'}) =>
    <String, dynamic>{
      'nombre': 'TextoSegunPaginaDeCodigos',
      'argumentos': <Object>[0, codepage, raw],
    };

void main() {
  group('PrintOperationsEncoder', () {
    test('TextoSegunPaginaDeCodigos: tabla de códigos + los bytes del servidor', () {
      final encoded = PrintOperationsEncoder.encode(<Map<String, dynamic>>[
        codepageOperation('\x1B@\x1Ba\x00Hola\n'),
      ]);

      expect(encoded.bytes.take(3), <int>[0x1B, 0x74, 0x02]);
      expect(
        encoded.bytes.skip(3),
        <int>[0x1B, 0x40, 0x1B, 0x61, 0x00, ...'Hola\n'.codeUnits],
      );
      expect(encoded.text, 'Hola');
      expect(encoded.isEmpty, isFalse);
      expect(encoded.ignored, isEmpty);
      expect(encoded.ignoredNotice, isNull);
    });

    test('conserva los bytes ≥ 0x80 (no los reencoda a UTF-8)', () {
      // La 'ó' del texto del servidor viaja como byte CP850 (0xA2), no como los
      // dos bytes de UTF-8 (0xC3 0xB3).
      final encoded = PrintOperationsEncoder.encode(<Map<String, dynamic>>[
        codepageOperation('L\u00A2pez\n'),
      ]);

      expect(encoded.bytes.contains(0xA2), isTrue);
      expect(encoded.bytes.contains(0xC3), isFalse);
      expect(encoded.text, 'L\u00A2pez');
    });

    test('traduce el nombre de la tabla y cae al número si no lo conoce', () {
      List<int> table(String name, {int index = 0}) =>
          PrintOperationsEncoder.encode(<Map<String, dynamic>>[
            <String, dynamic>{
              'nombre': 'TextoSegunPaginaDeCodigos',
              'argumentos': <Object>[index, name, 'x\n'],
            },
          ]).bytes.take(3).toList();

      expect(table('cp850'), <int>[0x1B, 0x74, 0x02]);
      expect(table('cp437'), <int>[0x1B, 0x74, 0x00]);
      expect(table('desconocida', index: 5), <int>[0x1B, 0x74, 0x05]);
    });

    test('EscribirTexto manda el TSPL de la etiqueta en UTF-8', () {
      final encoded = PrintOperationsEncoder.encode(<Map<String, dynamic>>[
        <String, dynamic>{
          'nombre': 'EscribirTexto',
          'argumentos': <Object>[
            'SIZE 50 mm,30 mm\nBITMAP 10,10,4,8,0,FF\nPRINT 1,1\n',
          ],
        },
      ]);

      expect(utf8.decode(encoded.bytes), contains('BITMAP 10,10,4,8,0,FF'));
      expect(utf8.decode(encoded.bytes), endsWith('PRINT 1,1\n'));
      expect(encoded.text, isEmpty);
    });

    test('AbrirCajon manda el pulso del cajón', () {
      final encoded = PrintOperationsEncoder.encode(<Map<String, dynamic>>[
        <String, dynamic>{
          'nombre': 'AbrirCajon',
          'argumentos': <Object>[],
        },
      ]);

      expect(encoded.bytes, PrintOperationsEncoder.drawerKick);
    });

    test('una operación que el teléfono no puede emitir se reporta', () {
      final encoded = PrintOperationsEncoder.encode(<Map<String, dynamic>>[
        <String, dynamic>{
          'nombre': 'DescargarImagenDeInternetEImprimir',
          'argumentos': <Object>['https://ejemplo.test/logo.png', 120],
        },
        codepageOperation('Hola\n'),
      ]);

      expect(encoded.ignored, <String>['DescargarImagenDeInternetEImprimir']);
      expect(
        encoded.ignoredNotice,
        contains('DescargarImagenDeInternetEImprimir'),
      );
      // Lo que sí se pudo resolver se sigue imprimiendo.
      expect(encoded.text, 'Hola');
    });

    test('sin operaciones no hay nada que imprimir', () {
      final encoded = PrintOperationsEncoder.encode(const <Map<String, dynamic>>[]);

      expect(encoded.isEmpty, isTrue);
      expect(encoded.text, isEmpty);
      expect(encoded.ignored, isEmpty);
    });
  });

  group('EscPosTextExtractor', () {
    test('quita los comandos y deja el texto que emite el servidor', () {
      final raw =
          '\x1B@\x1Ba\x00CORTE DE CAJA\n'
          '\x1Ba\x00Esperado en caja: 5,050.00\n'
          '\x1Ba\x01\x1BE\x01\n** ezyventas.com **\n\x1BE\x00\x1Ba\x00\n\n\n'
          '\x1DV\x00\x00';

      expect(
        EscPosTextExtractor.extract(raw),
        'CORTE DE CAJA\nEsperado en caja: 5,050.00\n\n** ezyventas.com **',
      );
    });

    test('quita el código de barras con sus datos', () {
      // GS h 80, GS w 2, GS k 73 6 'P-0042'
      final raw = 'Hola\n\x1Dh\x50\x1Dw\x02\x1Dk\x49\x06P-0042\n';

      expect(EscPosTextExtractor.extract(raw), 'Hola');
    });

    test('quita el QR completo', () {
      // GS ( k 4 0 '1A' 50 0 + el bloque final
      final raw =
          'Hola\n\x1D(k\x04\x001A\x32\x00\x1D(k\x03\x001Q0\n';

      expect(EscPosTextExtractor.extract(raw), 'Hola');
    });
  });
}
