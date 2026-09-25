import 'package:ezyventas_app/core/printing/bluetooth_printer_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Troceado del envío a la impresora.
///
/// Es la parte que provocaba que un ticket con el logo del negocio (bitmap
/// ESC/POS de ~8.7 KB) tardara ~11 s: el bloque era de **20 bytes con 25 ms de
/// pausa** (≈800 B/s, el procedimiento de Web Bluetooth del contrato §10). Ahora
/// el bloque sale del MTU negociado (`MTU - 3`) y se escribe con ACK.
void main() {
  group('chunkSizeFor', () {
    test('con el mínimo BLE (23) se queda en los 20 bytes del contrato §10', () {
      expect(BluetoothPrinterService.chunkSizeFor(23), 20);
      expect(BluetoothPrinterService.chunkSizeFor(null), 20);
      expect(BluetoothPrinterService.chunkSizeFor(10), 20);
    });

    test('usa MTU - 3 (la cabecera ATT) cuando el teléfono negocia más', () {
      expect(BluetoothPrinterService.chunkSizeFor(185), 182);
      expect(BluetoothPrinterService.chunkSizeFor(517), 512);
    });

    test('un MTU mayor que el tope se queda en 512 bytes útiles', () {
      expect(BluetoothPrinterService.chunkSizeFor(2048), 512);
    });
  });

  group('chunkRanges', () {
    test('cubre el documento entero, sin perder ni repetir bytes', () {
      // Los 8 739 bytes del ticket real de la plantilla #3 (con el logo).
      final ranges = BluetoothPrinterService.chunkRanges(8739, 512);

      expect(ranges.length, 18);
      expect(ranges.first, (0, 512));

      var expected = 0;

      for (final (start, end) in ranges) {
        expect(start, expected, reason: 'sin huecos entre bloques');
        expect(end, greaterThan(start));
        expected = end;
      }

      expect(expected, 8739, reason: 'el último bloque cierra el documento');
      expect(ranges.last, (8704, 8739), reason: 'el último bloque va corto');
    });

    test('un documento que cabe en un bloque sale entero', () {
      expect(BluetoothPrinterService.chunkRanges(40, 512), <(int, int)>[(0, 40)]);
    });

    test('sin bytes no hay nada que enviar', () {
      expect(BluetoothPrinterService.chunkRanges(0, 512), isEmpty);
    });

    test('un tamaño de bloque inválido no se acepta', () {
      expect(
        () => BluetoothPrinterService.chunkRanges(10, 0),
        throwsArgumentError,
      );
    });
  });
}
