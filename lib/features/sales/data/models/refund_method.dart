/// Métodos de reembolso de una venta (`refund_method` en `/cancel` y `/refund`).
///
/// No confundir con [TransactionPaymentMethod]: aquí `cash` exige una sesión de
/// caja abierta y `balance` un cliente asignado a la venta.
enum RefundMethod {
  cash(
    'cash',
    'Entregar efectivo de caja',
    requiresSession: true,
  ),
  balance(
    'balance',
    'Abonar a su saldo a favor',
  ),
  transfer(
    'transfer',
    'Transferencia bancaria',
    requiresBankAccount: true,
  );

  const RefundMethod(
    this.value,
    this.label, {
    this.requiresSession = false,
    this.requiresBankAccount = false,
  });

  /// Valor que viaja en `refund_method`.
  final String value;

  /// Texto de UI (sentence case), igual que la web.
  final String label;

  /// Necesita una sesión de caja abierta (el servidor responde `422` si no).
  final bool requiresSession;

  /// Necesita `bank_account_id`.
  final bool requiresBankAccount;

  static RefundMethod? fromValue(String? value) {
    for (final method in RefundMethod.values) {
      if (method.value == value) {
        return method;
      }
    }

    return null;
  }
}
