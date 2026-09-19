import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Arqueo de una cuenta bancaria en el corte (`summary.bank_accounts[]`).
///
/// `final_balance = initial_balance + received - spent + transferred_in -
/// transferred_out` (lo calcula el servidor; la app solo lo muestra).
class SessionBankAccount {
  const SessionBankAccount({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.initialBalance,
    required this.received,
    required this.spent,
    required this.transferredIn,
    required this.transferredOut,
    required this.finalBalance,
  });

  factory SessionBankAccount.fromJson(Map<String, dynamic> json) =>
      SessionBankAccount(
        id: JsonReader.integerOr(json['id'], 0),
        accountName: JsonReader.string(json['account_name']),
        bankName: JsonReader.string(json['bank_name']),
        initialBalance: Money.toDouble(json['initial_balance']),
        received: Money.toDouble(json['received']),
        spent: Money.toDouble(json['spent']),
        transferredIn: Money.toDouble(json['transferred_in']),
        transferredOut: Money.toDouble(json['transferred_out']),
        finalBalance: Money.toDouble(json['final_balance']),
      );

  final int id;
  final String? accountName;
  final String? bankName;
  final double initialBalance;
  final double received;
  final double spent;
  final double transferredIn;
  final double transferredOut;
  final double finalBalance;

  /// `Cuenta principal · BBVA`
  String get label {
    final parts = <String>[
      accountName ?? '',
      bankName ?? '',
    ].where((part) => part.isNotEmpty);

    return parts.isEmpty ? 'Cuenta $id' : parts.join(' · ');
  }

  /// `true` si hubo movimiento en el turno (para no listar cuentas intactas).
  bool get hasMovement =>
      received != 0 || spent != 0 || transferredIn != 0 || transferredOut != 0;
}
