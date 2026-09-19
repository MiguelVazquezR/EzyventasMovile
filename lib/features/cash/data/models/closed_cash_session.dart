import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';
import 'cash_session_summary.dart';

/// Sesión ya cerrada que devuelve `PUT /cash-register-sessions/{id}`.
class ClosedCashSession {
  const ClosedCashSession({
    required this.id,
    required this.status,
    required this.closedAt,
    required this.calculatedCashTotal,
    required this.closingCashBalance,
    required this.cashDifference,
  });

  factory ClosedCashSession.fromJson(Map<String, dynamic> json) =>
      ClosedCashSession(
        id: JsonReader.integerOr(json['id'], 0),
        status: JsonReader.stringOr(json['status'], 'cerrada'),
        closedAt: AppFormatters.parse(json['closed_at']),
        calculatedCashTotal: Money.toDouble(json['calculated_cash_total']),
        closingCashBalance: Money.toDouble(json['closing_cash_balance']),
        cashDifference: Money.toDouble(json['cash_difference']),
      );

  final int id;
  final String status;
  final DateTime? closedAt;

  /// Efectivo que el servidor esperaba (`calculated_cash_total`).
  final double calculatedCashTotal;

  /// Efectivo contado por el cajero.
  final double closingCashBalance;
  final double cashDifference;

  bool get hasDifference => cashDifference.abs() >= 0.01;
}

/// Resultado del corte: la sesión cerrada + el resumen definitivo + `message`.
class CloseCashSessionResult {
  const CloseCashSessionResult({
    required this.session,
    required this.summary,
    required this.message,
  });

  factory CloseCashSessionResult.fromJson(Map<String, dynamic> json) =>
      CloseCashSessionResult(
        session: ClosedCashSession.fromJson(
          JsonReader.toMap(json['session']),
        ),
        summary: CashSessionSummary.fromJson(
          JsonReader.toMap(json['summary']),
        ),
        message: JsonReader.stringOr(json['message'], ''),
      );

  final ClosedCashSession session;
  final CashSessionSummary summary;
  final String message;
}
