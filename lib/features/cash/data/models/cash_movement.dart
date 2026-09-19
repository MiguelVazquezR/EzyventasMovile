import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';
import 'user_ref.dart';

/// Movimiento manual de efectivo del turno (`summary.cash_movements`).
///
/// La app **no** crea ingresos ni egresos (eso se hace en la web): solo los
/// muestra en el resumen del corte.
class CashMovement {
  const CashMovement({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.user,
    required this.createdAt,
  });

  factory CashMovement.fromJson(Map<String, dynamic> json) => CashMovement(
    id: JsonReader.integerOr(json['id'], 0),
    type: JsonReader.stringOr(json['type'], ''),
    // `amount` llega como texto decimal.
    amount: Money.toDouble(json['amount']),
    description: JsonReader.string(json['description']),
    user: json['user'] == null
        ? null
        : UserRef.fromJson(JsonReader.toMap(json['user'])),
    createdAt: AppFormatters.parse(json['created_at']),
  );

  /// `ingreso` | `egreso`.
  final String type;
  final int id;
  final double amount;
  final String? description;
  final UserRef? user;
  final DateTime? createdAt;

  bool get isInflow => type == 'ingreso';

  String get label => isInflow ? 'Ingreso' : 'Egreso';
}
