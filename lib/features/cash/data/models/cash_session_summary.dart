import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';
import 'active_cash_session.dart';
import 'cash_movement.dart';
import 'session_bank_account.dart';

/// Cobros del turno por método (`summary.payments_by_method`).
class CashPaymentTotals {
  const CashPaymentTotals({
    required this.cash,
    required this.card,
    required this.transfer,
    required this.balance,
  });

  const CashPaymentTotals.empty()
    : cash = 0,
      card = 0,
      transfer = 0,
      balance = 0;

  factory CashPaymentTotals.fromJson(Map<String, dynamic> json) =>
      CashPaymentTotals(
        cash: Money.toDouble(json['efectivo']),
        card: Money.toDouble(json['tarjeta']),
        transfer: Money.toDouble(json['transferencia']),
        balance: Money.toDouble(json['saldo']),
      );

  final double cash;
  final double card;
  final double transfer;

  /// Cobrado con el saldo a favor del cliente (método `saldo`).
  final double balance;

  double get total => Money.round2(cash + card + transfer + balance);
}

/// Resumen del corte (`GET /cash-register-sessions/{id}/summary`).
///
/// Alimenta la pantalla de cierre: total esperado de efectivo, cobros por
/// método, movimientos manuales y arqueo de bancos. Las fórmulas las calcula el
/// servidor (idénticas a la web); la app solo pinta y calcula la diferencia en
/// vivo mientras se captura el efectivo contado.
class CashSessionSummary {
  const CashSessionSummary({
    required this.session,
    required this.opening,
    required this.cashSales,
    required this.inflows,
    required this.outflows,
    required this.expectedTotal,
    required this.countedTotal,
    required this.difference,
    required this.payments,
    required this.cashMovements,
    required this.bankAccounts,
    required this.transactionsCount,
    required this.paymentsCount,
  });

  factory CashSessionSummary.fromJson(Map<String, dynamic> json) {
    final cash = JsonReader.toMap(json['cash']);
    final counts = JsonReader.toMap(json['counts']);

    return CashSessionSummary(
      session: ActiveCashSession.fromJson(JsonReader.toMap(json['session'])),
      opening: Money.toDouble(cash['opening']),
      cashSales: Money.toDouble(cash['cash_sales']),
      inflows: Money.toDouble(cash['inflows']),
      outflows: Money.toDouble(cash['outflows']),
      expectedTotal: Money.toDouble(cash['expected_total']),
      countedTotal: Money.toNullableDouble(cash['counted_total']),
      difference: Money.toNullableDouble(cash['difference']),
      payments: CashPaymentTotals.fromJson(
        JsonReader.toMap(json['payments_by_method']),
      ),
      cashMovements: JsonReader.toMapList(
        json['cash_movements'],
      ).map(CashMovement.fromJson).toList(growable: false),
      bankAccounts: JsonReader.toMapList(
        json['bank_accounts'],
      ).map(SessionBankAccount.fromJson).toList(growable: false),
      transactionsCount: JsonReader.integerOr(counts['transactions'], 0),
      paymentsCount: JsonReader.integerOr(counts['payments'], 0),
    );
  }

  final ActiveCashSession session;

  /// Fondo de efectivo con el que se abrió el turno.
  final double opening;
  final double cashSales;
  final double inflows;
  final double outflows;

  /// `opening + cash_sales + inflows - outflows`.
  final double expectedTotal;

  /// Efectivo contado (null mientras el turno siga abierto).
  final double? countedTotal;

  /// `counted_total - expected_total` (null si aún no se cierra).
  final double? difference;

  final CashPaymentTotals payments;
  final List<CashMovement> cashMovements;
  final List<SessionBankAccount> bankAccounts;
  final int transactionsCount;
  final int paymentsCount;

  /// Diferencia en vivo para la captura del corte (`contado − esperado`).
  double differenceFor(double countedCash) =>
      Money.round2(countedCash - expectedTotal);

  bool get isClosed => session.status == 'cerrada';

  /// La app no registra movimientos: solo los muestra si existen.
  bool get hasMovements => cashMovements.isNotEmpty;

  /// Cuentas con movimiento en el turno (el bloque se oculta si no hay ninguna).
  List<SessionBankAccount> get bankAccountsWithMovement =>
      bankAccounts.where((account) => account.hasMovement).toList(
        growable: false,
      );
}
