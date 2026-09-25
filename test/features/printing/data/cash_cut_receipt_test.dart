import 'package:ezyventas_app/features/printing/data/models/cash_cut_receipt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'printing_fixtures.dart';

void main() {
  // `AppFormatters` usa `intl` es-MX; en la app lo inicializa
  // `flutter_localizations`.
  setUpAll(() => initializeDateFormatting('es_MX'));

  group('CashCutReceipt', () {
    test('lee el comprobante del corte con la plantilla incorporada', () {
      final receipt = cashCutReceipt();

      expect(receipt.session.id, 41);
      expect(receipt.session.isClosed, isTrue);
      expect(receipt.session.cashRegisterName, 'Caja 1');
      expect(receipt.session.turnLabel, contains('→'));
      expect(receipt.template.id, isNull);
      expect(receipt.template.builtin, isTrue);
      expect(receipt.template.label, 'Corte de caja (incorporada)');
      expect(receipt.paperWidth, '80mm');
      expect(receipt.feedLines, 3);
      expect(receipt.label, '#41 · Caja 1');
      expect(receipt.hasWarnings, isFalse);
      expect(receipt.warningNotice, isNull);
    });

    test('conserva las cifras congeladas del cierre', () {
      final summary = cashCutReceipt().summary;

      expect(summary, isNotNull);
      expect(summary!.expectedTotal, 5050);
      expect(summary.countedTotal, 5040);
      expect(summary.difference, -10);
      expect(summary.transactionsCount, 12);
      expect(summary.paymentsCount, 14);
    });

    test('el texto sale del documento del servidor, sin comandos', () {
      final text = cashCutReceipt().text;

      expect(text, startsWith('CORTE DE CAJA'));
      expect(text, contains('Cajero: José Pérez'));
      expect(text, contains('Esperado en caja: 5,050.00'));
      expect(text, contains('Diferencia: -10.00'));
      expect(text, contains('** ezyventas.com **'));
      expect(text, isNot(contains('\x1B')));
      expect(text, isNot(contains('\x1D')));
    });

    test('los bytes son los del servidor detrás de la tabla de códigos', () {
      final receipt = cashCutReceipt();
      final bytes = receipt.bytes;

      // `ESC t 2`: la tabla CP850 que declara la operación.
      expect(bytes.take(3), <int>[0x1B, 0x74, 0x02]);
      // Después van los bytes tal cual los armó el servidor.
      expect(String.fromCharCodes(bytes.skip(3)), cashCutRawText());
      // El corte de papel sigue al final.
      expect(bytes.skip(bytes.length - 4), <int>[0x1D, 0x56, 0x00, 0x00]);
    });

    test('avisa de lo que el servidor no pudo resolver', () {
      final json = cashCutReceiptFixture();

      json['unsupported_operations'] = <String>[
        'Image: https://ejemplo.test/logo.png',
      ];
      json['warnings'] = <String>[
        'Barcode: la plantilla no resolvió un valor, se usó «P-42».',
      ];

      final receipt = CashCutReceipt.fromJson(json);

      expect(receipt.hasWarnings, isTrue);
      expect(receipt.warningNotice, contains('Image: https://ejemplo.test'));
      expect(receipt.warningNotice, contains('P-42'));
      // El corte se imprime igual: el servidor solo dejó fuera ese elemento.
      expect(receipt.bytes, isNotEmpty);
    });

    test('con la plantilla del negocio el id viaja para el respaldo', () {
      final json = cashCutReceiptFixture();

      json['template'] = <String, dynamic>{
        'id': 12,
        'name': 'Corte de la tienda',
        'builtin': false,
      };

      final receipt = CashCutReceipt.fromJson(json);

      expect(receipt.template.id, 12);
      expect(receipt.template.builtin, isFalse);
      expect(receipt.template.label, 'Corte de la tienda');
    });

    test('una plantilla con imagen deja la operación sin resolver', () {
      final json = cashCutReceiptFixture();

      json['operations'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'nombre': 'DescargarImagenDeInternetEImprimir',
          'argumentos': <Object>['https://ejemplo.test/logo.png', 120],
        },
        <String, dynamic>{
          'nombre': 'TextoSegunPaginaDeCodigos',
          'argumentos': <Object>[0, 'cp850', 'CORTE DE CAJA\n'],
        },
      ];

      final receipt = CashCutReceipt.fromJson(json);

      expect(receipt.encoded.ignored, isNotEmpty);
      expect(receipt.hasWarnings, isTrue);
      expect(receipt.warningNotice, contains('el teléfono no imprime'));
      expect(receipt.text, 'CORTE DE CAJA');
    });
  });
}
