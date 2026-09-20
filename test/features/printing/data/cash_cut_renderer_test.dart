import 'package:ezyventas_app/features/printing/data/cash_cut_renderer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'printing_fixtures.dart';

void main() {
  // `AppFormatters` usa `intl` es-MX; en la app lo inicializa
  // `flutter_localizations`.
  setUpAll(() => initializeDateFormatting('es_MX'));

  group('CashCutDocument', () {
    test('toma los montos que calculó el servidor', () {
      final cut = cashCutDocument();

      expect(cut.sessionId, 41);
      expect(cut.businessName, 'Refaccionaria López');
      expect(cut.branchName, 'León Centro');
      expect(cut.terminalName, 'Caja 1');
      expect(cut.openerName, 'José Pérez');
      expect(cut.openingCash, 1500);
      expect(cut.cashSales, 3500);
      expect(cut.inflows, 200);
      expect(cut.outflows, 150);
      expect(cut.expectedTotal, 5050);
      expect(cut.countedTotal, 5040);
      expect(cut.difference, -10);
      expect(cut.cash, 3500);
      expect(cut.card, 1200);
      expect(cut.transfer, 300);
      expect(cut.balance, 0);
      expect(cut.transactionsCount, 12);
      expect(cut.paymentsCount, 14);
    });

    test('resume métodos, movimientos y bancos del turno', () {
      final cut = cashCutDocument();

      expect(cut.hasDifference, isTrue);
      expect(cut.paymentBreakdown.map((entry) => entry.key), <String>[
        'Efectivo',
        'Tarjeta',
        'Transferencia',
        'Saldo a favor',
      ]);
      expect(cut.movements.single.label, 'Egreso');
      expect(cut.movements.single.description, 'Compra de bolsas');
      expect(cut.bankAccounts.single.label, 'Cuenta principal · BBVA');
      expect(cut.bankAccounts.single.finalBalance, 5900);
      expect(cut.money(cut.expectedTotal), '\$5,050.00');
      expect(cut.periodLabel, contains('→'));
    });
  });

  group('CashCutRenderer · texto', () {
    test('incluye el desglose completo del corte', () {
      final text = CashCutRenderer.text(cashCutDocument());

      expect(text, startsWith('CORTE DE CAJA'));
      expect(text, contains('Refaccionaria López'));
      expect(text, contains('Terminal: Caja 1'));
      expect(text, contains('Usuario único en el turno'));
      expect(text, contains('Fondo inicial'));
      expect(text, contains('\$1,500.00'));
      expect(text, contains('TOTAL ESPERADO'));
      expect(text, contains('\$5,050.00'));
      expect(text, contains('Efectivo contado'));
      expect(text, contains('\$5,040.00'));
      expect(text, contains('DIFERENCIA'));
      expect(text, contains('-\$10.00'));
      expect(text, contains('COBROS POR METODO'));
      expect(text, contains('MOVIMIENTOS'));
      expect(text, contains('Egreso · \$150.00 · Compra de bolsas'));
      expect(text, contains('BANCOS'));
      expect(text, contains('Cuenta principal · BBVA'));
      expect(text, contains('Ventas: 12   Cobros: 14'));
    });

    test('alinea los montos al ancho del papel', () {
      final text = CashCutRenderer.text(
        cashCutDocument(),
        charactersPerLine: 32,
      );

      final totalLine = text
          .split('\n')
          .firstWhere((line) => line.startsWith('TOTAL ESPERADO'));

      expect(totalLine.length, 32);
      expect(totalLine, endsWith('\$5,050.00'));
      expect(text.contains('-' * 32), isTrue);
    });

    test('avisa cuando el turno tuvo varios usuarios', () {
      final cut = cashCutDocument();

      expect(CashCutRenderer.usersLine(cut), 'Usuario único en el turno');
    });
  });

  group('CashCutRenderer · ESC/POS', () {
    test('inicia con la página CP850 y cierra con avance y corte', () {
      final bytes = CashCutRenderer.escPos(cashCutDocument());

      expect(bytes.take(5), <int>[0x1B, 0x40, 0x1B, 0x74, 0x02]);
      // 3 avances de papel y `GS V 66 0` (corte parcial).
      expect(bytes.sublist(bytes.length - 7), <int>[
        0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x42, 0x00,
      ]);
    });

    test('imprime los montos y el nombre del negocio en CP850', () {
      final bytes = CashCutRenderer.escPos(cashCutDocument());
      final text = String.fromCharCodes(
        bytes.map((byte) => byte == 0x0A ? 0x0A : byte),
      );

      // '\$5,050.00' y '-\$10.00' viajan tal cual (ASCII).
      expect(text.contains('\$5,050.00'), isTrue);
      expect(text.contains('-\$10.00'), isTrue);
      // 'López' con ó = 0xA2 de CP850 (no 0xF3 de Latin-1).
      expect(bytes.contains(0xA2), isTrue);
      expect(bytes.contains(0xF3), isFalse);
      // El comando de doble tamaño ('CORTE DE CAJA') está presente.
      expect(_contains(bytes, <int>[0x1D, 0x21, 0x11]), isTrue);
    });

    test('el corte de 58 mm respeta el ancho de línea', () {
      final bytes = CashCutRenderer.escPos(
        cashCutDocument(),
        charactersPerLine: 32,
      );

      // El separador de 32 guiones viaja al final de cada bloque.
      expect(_contains(bytes, List<int>.filled(32, 0x2D)), isTrue);
      expect(_contains(bytes, List<int>.filled(48, 0x2D)), isFalse);
    });
  });
}

/// ¿[bytes] contiene la subsecuencia [pattern]?
bool _contains(List<int> bytes, List<int> pattern) {
  if (pattern.isEmpty || bytes.length < pattern.length) {
    return false;
  }

  for (var start = 0; start <= bytes.length - pattern.length; start++) {
    var matches = true;

    for (var index = 0; index < pattern.length; index++) {
      if (bytes[start + index] != pattern[index]) {
        matches = false;
        break;
      }
    }

    if (matches) {
      return true;
    }
  }

  return false;
}
