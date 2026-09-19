/// Métodos de pago que el servidor acepta en `payments[].method`.
///
/// El saldo a favor **no** es un pago: se envía con `use_balance: true` y el
/// servidor lo registra como método `saldo` (contrato §7.3).
enum PosPaymentMethod {
  cash('efectivo', 'Efectivo'),
  card('tarjeta', 'Tarjeta'),
  transfer('transferencia', 'Transferencia');

  const PosPaymentMethod(this.value, this.label);

  /// Valor que viaja en `payments[].method`.
  final String value;

  /// Texto de UI (sentence case).
  final String label;

  /// `tarjeta` y `transferencia` exigen `bank_account_id`.
  bool get requiresBankAccount => this != PosPaymentMethod.cash;

  static PosPaymentMethod? fromValue(String? value) {
    for (final method in PosPaymentMethod.values) {
      if (method.value == value) {
        return method;
      }
    }

    return null;
  }
}

/// Línea de pago del cobro (pago mixto).
class PaymentDraft {
  const PaymentDraft({
    required this.method,
    required this.amount,
    this.bankAccountId,
    this.bankAccountName,
    this.notes,
  });

  final PosPaymentMethod method;
  final double amount;

  /// Cuenta destino (obligatoria para tarjeta y transferencia).
  final int? bankAccountId;

  /// Etiqueta de la cuenta, solo para mostrarla en el resumen.
  final String? bankAccountName;

  final String? notes;

  bool get isCash => method == PosPaymentMethod.cash;

  /// Monto capturado y, si el método lo exige, cuenta destino elegida.
  bool get isComplete =>
      amount > 0 &&
      (!method.requiresBankAccount || (bankAccountId ?? 0) > 0);

  /// Falta elegir la cuenta destino de un pago con tarjeta o transferencia.
  bool get needsBankAccount => method.requiresBankAccount && amount > 0 && bankAccountId == null;

  PaymentDraft copyWith({
    PosPaymentMethod? method,
    double? amount,
    int? bankAccountId,
    String? bankAccountName,
    String? notes,
    bool clearBankAccount = false,
  }) {
    return PaymentDraft(
      method: method ?? this.method,
      amount: amount ?? this.amount,
      bankAccountId: clearBankAccount ? null : (bankAccountId ?? this.bankAccountId),
      bankAccountName:
          clearBankAccount ? null : (bankAccountName ?? this.bankAccountName),
      notes: notes ?? this.notes,
    );
  }

  /// Forma exacta que espera `POST /pos/checkout`.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'amount': amount,
    'method': method.value,
    'bank_account_id': bankAccountId,
    'notes': notes,
  };
}
