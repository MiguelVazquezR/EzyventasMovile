import '../../../../core/utils/money.dart';

/// Cobros del turno agrupados por método (`totals` de la sesión de caja).
///
/// El servidor los envía como **número** (`"cash.*"` en el contrato), pero se
/// normalizan con [Money.toDouble] para tolerar strings decimales.
class CashSessionTotals {
  const CashSessionTotals({
    required this.cash,
    required this.card,
    required this.transfer,
    required this.balance,
  });

  const CashSessionTotals.empty()
    : cash = 0,
      card = 0,
      transfer = 0,
      balance = 0;

  factory CashSessionTotals.fromJson(Map<String, dynamic> json) {
    return CashSessionTotals(
      cash: Money.toDouble(json['cash']),
      card: Money.toDouble(json['card']),
      transfer: Money.toDouble(json['transfer']),
      balance: Money.toDouble(json['balance']),
    );
  }

  final double cash;
  final double card;
  final double transfer;

  /// Cobrado con saldo a favor del cliente.
  final double balance;

  double get total => cash + card + transfer + balance;
}
