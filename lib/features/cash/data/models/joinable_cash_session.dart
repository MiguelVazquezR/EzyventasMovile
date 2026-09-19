import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import 'cash_register_ref.dart';
import 'user_ref.dart';

/// Sesión de caja abierta en la sucursal a la que el usuario puede unirse.
class JoinableCashSession {
  const JoinableCashSession({
    required this.id,
    required this.openedAt,
    required this.cashRegister,
    required this.opener,
  });

  factory JoinableCashSession.fromJson(Map<String, dynamic> json) {
    return JoinableCashSession(
      id: JsonReader.integerOr(json['id'], 0),
      openedAt: AppFormatters.parse(json['opened_at']),
      cashRegister: json['cash_register'] == null
          ? null
          : CashRegisterRef.fromJson(JsonReader.toMap(json['cash_register'])),
      opener: json['opener'] == null
          ? null
          : UserRef.fromJson(JsonReader.toMap(json['opener'])),
    );
  }

  final int id;
  final DateTime? openedAt;
  final CashRegisterRef? cashRegister;
  final UserRef? opener;
}
