import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';
import 'cash_register_ref.dart';
import 'cash_session_totals.dart';
import 'user_ref.dart';

/// Sesión de caja en la que el usuario está trabajando (`active_session`).
class ActiveCashSession {
  const ActiveCashSession({
    required this.id,
    required this.status,
    required this.openedAt,
    required this.openingCashBalance,
    required this.cashRegister,
    required this.opener,
    required this.users,
    required this.totals,
  });

  factory ActiveCashSession.fromJson(Map<String, dynamic> json) {
    return ActiveCashSession(
      id: JsonReader.integerOr(json['id'], 0),
      status: JsonReader.stringOr(json['status'], 'abierta'),
      openedAt: AppFormatters.parse(json['opened_at']),
      openingCashBalance: Money.toDouble(json['opening_cash_balance']),
      cashRegister: json['cash_register'] == null
          ? null
          : CashRegisterRef.fromJson(JsonReader.toMap(json['cash_register'])),
      opener: json['opener'] == null
          ? null
          : UserRef.fromJson(JsonReader.toMap(json['opener'])),
      users: JsonReader.toMapList(json['users'])
          .map(UserRef.fromJson)
          .toList(growable: false),
      totals: CashSessionTotals.fromJson(JsonReader.toMap(json['totals'])),
    );
  }

  final int id;
  final String status;
  final DateTime? openedAt;
  final double openingCashBalance;
  final CashRegisterRef? cashRegister;
  final UserRef? opener;
  final List<UserRef> users;
  final CashSessionTotals totals;

  /// Nombre de la terminal para la cabecera y los avisos.
  String get cashRegisterName => cashRegister?.name ?? 'Terminal';

  /// Más de un usuario participando: hay que advertir antes de cerrar.
  bool get hasMultipleUsers => users.length > 1;

  bool get isOpen => status == 'abierta';
}
