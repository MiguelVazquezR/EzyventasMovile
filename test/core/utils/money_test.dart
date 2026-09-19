import 'package:ezyventas_app/core/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.toNullableDouble', () {
    test('acepta texto decimal con dos decimales (contrato)', () {
      expect(Money.toNullableDouble('270.00'), 270.0);
      expect(Money.toNullableDouble('0.00'), 0.0);
      expect(Money.toNullableDouble('-50.25'), -50.25);
    });

    test('acepta números (campos que el servidor envía como numéricos)', () {
      expect(Money.toNullableDouble(270), 270.0);
      expect(Money.toNullableDouble(270.5), 270.5);
      expect(Money.toNullableDouble(0), 0.0);
    });

    test('tolera separadores de miles y símbolo de moneda', () {
      expect(Money.toNullableDouble('1,240.00'), 1240.0);
      expect(Money.toNullableDouble(r'$1,240.50'), 1240.5);
      expect(Money.toNullableDouble('  3,000.10  '), 3000.1);
    });

    test('devuelve null cuando no hay número utilizable', () {
      expect(Money.toNullableDouble(null), isNull);
      expect(Money.toNullableDouble(''), isNull);
      expect(Money.toNullableDouble('abc'), isNull);
      expect(Money.toNullableDouble('-'), isNull);
      expect(Money.toNullableDouble('.'), isNull);
    });
  });

  group('Money.toDouble / toInt', () {
    test('usa el respaldo cuando el valor falta', () {
      expect(Money.toDouble(null), 0);
      expect(Money.toDouble('sin valor', fallback: 12.5), 12.5);
    });

    test('convierte a entero (items_count)', () {
      expect(Money.toInt('12'), 12);
      expect(Money.toInt(12.6), 13);
      expect(Money.toInt(null), 0);
    });
  });

  group('Formato es-MX', () {
    test('format usa símbolo de peso y dos decimales', () {
      expect(Money.format(1240), r'$1,240.00');
      expect(Money.format('270.00'), r'$270.00');
    });

    test('formatWithCurrency agrega la divisa', () {
      expect(Money.formatWithCurrency('270.00'), r'$270.00 MXN');
    });

    test('formatPlain sirve para capturar en campos de texto', () {
      expect(Money.formatPlain(1240.5), '1,240.50');
    });

    test('formatQuantity quita ceros sobrantes (hasta 3 decimales)', () {
      expect(Money.formatQuantity(2), '2');
      expect(Money.formatQuantity(1.5), '1.5');
      expect(Money.formatQuantity(0.25), '0.25');
    });

    test('parseInput convierte una captura del usuario', () {
      expect(Money.parseInput('1,240.00'), 1240.0);
      expect(Money.parseInput(''), 0);
    });
  });
}
