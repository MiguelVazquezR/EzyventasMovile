import 'package:intl/intl.dart';

/// Utilidades para el dinero que llega de la API.
///
/// El contrato mezcla tipos a propósito:
/// - **texto decimal** (`"270.00"`): `subtotal`, `total_discount`, `total_tax`,
///   `shipping_cost`, `unit_price`, `discount_amount`, `line_total`, `amount`
///   (pagos), saldos de banco y montos de corte.
/// - **número**: `total`, `total_paid`, `remaining_due`, `items_count`,
///   `change`, `cash.*`, `usage.*`.
///
/// Todo se normaliza con [toDouble] antes de operar: **nunca** hay aritmética
/// sobre un String.
class Money {
  const Money._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'es_MX',
    symbol: r'$',
    decimalDigits: 2,
  );

  static final NumberFormat _plain = NumberFormat('#,##0.00', 'es_MX');

  static final NumberFormat _quantity = NumberFormat('#,##0.###', 'es_MX');

  /// Convierte cualquier representación del servidor en `double?`.
  ///
  /// Acepta `null`, números y texto decimal (incluso con `$` o separadores:
  /// `"1,240.00"` → `1240.0`). Devuelve `null` si no hay número utilizable.
  static double? toNullableDouble(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.\-]'), '');
      if (cleaned.isEmpty || cleaned == '-' || cleaned == '.' || cleaned == '-.') {
        return null;
      }

      return double.tryParse(cleaned);
    }

    return null;
  }

  /// Igual que [toNullableDouble] pero con valor de respaldo.
  static double toDouble(Object? value, {double fallback = 0}) =>
      toNullableDouble(value) ?? fallback;

  static int toInt(Object? value, {int fallback = 0}) {
    final parsed = toNullableDouble(value);
    return parsed?.round() ?? fallback;
  }

  /// `$1,240.00` (locale es-MX, cifras tabulares al mostrarse).
  static String format(Object? value) => _currency.format(toDouble(value));

  /// `$1,240.00 MXN` — para totales destacados y tickets.
  static String formatWithCurrency(Object? value) =>
      '${_currency.format(toDouble(value))} ${'MXN'}';

  /// `1,240.00` — sin símbolo, para campos de captura.
  static String formatPlain(Object? value) => _plain.format(toDouble(value));

  /// `1` / `1.5` / `0.25` — cantidades con hasta 3 decimales.
  static String formatQuantity(Object? value) =>
      _quantity.format(toDouble(value));

  /// Convierte una captura del usuario (`"1,240.00"`, `"1240"`) en `double`.
  static double parseInput(String? raw) => toDouble(raw);
}
