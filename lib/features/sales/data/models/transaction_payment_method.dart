/// Métodos de pago de una venta (`payment_method` del contrato).
///
/// Los pagos de venta solo se registran con `efectivo`, `tarjeta` o
/// `transferencia`; `saldo` e `intercambio` los escribe el servidor y solo se
/// pueden **editar** (PUT) conservando el valor actual.
enum TransactionPaymentMethod {
  cash('efectivo', 'Efectivo'),
  card('tarjeta', 'Tarjeta'),
  transfer('transferencia', 'Transferencia'),
  balance('saldo', 'Saldo de cliente'),
  exchange('intercambio', 'Intercambio');

  const TransactionPaymentMethod(this.value, this.label);

  /// Valor tal como viaja en `payment_method`.
  final String value;

  /// Texto de UI (sentence case).
  final String label;

  /// `tarjeta` y `transferencia` exigen `bank_account_id`.
  bool get requiresBankAccount =>
      this == TransactionPaymentMethod.card ||
      this == TransactionPaymentMethod.transfer;

  /// `true` si el servidor permite elegirlo en un **abono** nuevo.
  bool get isAllowedOnAbono =>
      this == TransactionPaymentMethod.cash ||
      this == TransactionPaymentMethod.card ||
      this == TransactionPaymentMethod.transfer;

  static TransactionPaymentMethod? fromValue(String? value) {
    for (final method in TransactionPaymentMethod.values) {
      if (method.value == value) {
        return method;
      }
    }

    return null;
  }

  /// Etiqueta de un valor del servidor (`—` si es desconocido).
  static String labelOf(String? value) => fromValue(value)?.label ?? '—';

  /// Opciones del formulario de edición: las mismas que la web (efectivo,
  /// tarjeta, transferencia y saldo) más el método actual cuando es
  /// `intercambio`, para no perderlo al guardar.
  static List<TransactionPaymentMethod> editableOptions(
    TransactionPaymentMethod? current,
  ) {
    final options = <TransactionPaymentMethod>[
      TransactionPaymentMethod.cash,
      TransactionPaymentMethod.card,
      TransactionPaymentMethod.transfer,
      TransactionPaymentMethod.balance,
    ];

    if (current == TransactionPaymentMethod.exchange) {
      options.add(TransactionPaymentMethod.exchange);
    }

    return options;
  }
}
