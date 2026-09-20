import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../cash/data/models/cash_movement.dart';
import '../../../cash/data/models/closed_cash_session.dart';
import '../../../cash/data/models/session_bank_account.dart';

/// Corte de caja armado **en el dispositivo**.
///
/// El endpoint de impresión del servidor no acepta `cash_register_session` como
/// `data_source_type` (contrato §6.3), así que el ticket del corte se genera en
/// el teléfono a partir del `summary` que devuelve el cierre. Este objeto es la
/// única fuente de verdad para el ticket ESC/POS y para el texto de WhatsApp:
/// los montos ya vienen calculados por el servidor (`expected_total`,
/// `counted_total`, `difference`).
class CashCutDocument {
  const CashCutDocument({
    required this.sessionId,
    required this.businessName,
    required this.branchName,
    required this.terminalName,
    required this.openerName,
    required this.usersCount,
    required this.transactionsCount,
    required this.paymentsCount,
    required this.openingCash,
    required this.cashSales,
    required this.inflows,
    required this.outflows,
    required this.expectedTotal,
    required this.countedTotal,
    required this.difference,
    required this.cash,
    required this.card,
    required this.transfer,
    required this.balance,
    required this.movements,
    required this.bankAccounts,
    required this.openedAt,
    required this.closedAt,
  });

  /// Toma los datos del servidor: el resumen del turno y la sesión cerrada.
  factory CashCutDocument.fromCloseResult({
    required CloseCashSessionResult result,
    required String businessName,
    required String branchName,
  }) {
    final summary = result.summary;
    final session = summary.session;

    return CashCutDocument(
      sessionId: session.id,
      businessName: businessName,
      branchName: branchName,
      terminalName: session.cashRegisterName,
      openerName: session.opener?.name ?? '—',
      usersCount: session.users.length,
      transactionsCount: summary.transactionsCount,
      paymentsCount: summary.paymentsCount,
      openingCash: summary.opening,
      cashSales: summary.cashSales,
      inflows: summary.inflows,
      outflows: summary.outflows,
      expectedTotal: summary.expectedTotal,
      countedTotal: result.session.closingCashBalance,
      difference: result.session.cashDifference,
      cash: summary.payments.cash,
      card: summary.payments.card,
      transfer: summary.payments.transfer,
      balance: summary.payments.balance,
      movements: summary.cashMovements,
      bankAccounts: summary.bankAccountsWithMovement,
      openedAt: session.openedAt,
      closedAt: result.session.closedAt,
    );
  }

  final int sessionId;
  final String businessName;
  final String branchName;
  final String terminalName;
  final String openerName;
  final int usersCount;
  final int transactionsCount;
  final int paymentsCount;

  /// Fondo con el que se abrió el turno.
  final double openingCash;

  /// Ventas cobradas en efectivo, ingresos y egresos del turno.
  final double cashSales;
  final double inflows;
  final double outflows;

  /// `opening + cash_sales + inflows - outflows` (lo calcula el servidor).
  final double expectedTotal;

  /// Efectivo contado por el cajero al cerrar.
  final double countedTotal;

  /// `counted_total - expected_total`.
  final double difference;

  /// Cobros por método (los cuatro del contrato).
  final double cash;
  final double card;
  final double transfer;
  final double balance;

  final List<CashMovement> movements;
  final List<SessionBankAccount> bankAccounts;
  final DateTime? openedAt;
  final DateTime? closedAt;

  bool get hasDifference => difference.abs() >= 0.01;

  /// Cobros por método, ya etiquetados (los montos los formatea el render).
  List<MapEntry<String, double>> get paymentBreakdown => <MapEntry<String, double>>[
    MapEntry<String, double>('Efectivo', cash),
    MapEntry<String, double>('Tarjeta', card),
    MapEntry<String, double>('Transferencia', transfer),
    MapEntry<String, double>('Saldo a favor', balance),
  ];

  /// Periodo del turno (`18 sep 2026, 13:00 → 18 sep 2026, 20:05`).
  String get periodLabel {
    final from = openedAt == null ? '—' : AppFormatters.dateTime(openedAt);
    final to = closedAt == null ? '—' : AppFormatters.dateTime(closedAt);

    return '$from → $to';
  }

  /// Montos con `intl` es-MX (`$1,250.50`).
  String money(Object? value) => Money.format(value);
}
