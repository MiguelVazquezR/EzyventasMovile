import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Saldo bancario declarado/congelado al abrir el turno
/// (`active_session.opening_bank_balances`).
///
/// Es el snapshot que la pantalla de corte usa como saldo inicial; el servidor
/// lo completa con las cuentas que el cajero no declaró (heredando el último
/// corte de esa terminal).
class OpeningBankBalance {
  const OpeningBankBalance({
    required this.id,
    required this.accountName,
    required this.bankName,
    required this.balance,
  });

  factory OpeningBankBalance.fromJson(Map<String, dynamic> json) =>
      OpeningBankBalance(
        id: JsonReader.integerOr(json['id'], 0),
        accountName: JsonReader.string(json['account_name']),
        bankName: JsonReader.string(json['bank_name']),
        // El servidor lo envía como número, pero se normaliza por seguridad.
        balance: Money.toDouble(json['balance']),
      );

  final int id;
  final String? accountName;
  final String? bankName;
  final double balance;

  /// `Cuenta principal · BBVA`
  String get label {
    final parts = <String>[
      accountName ?? '',
      bankName ?? '',
    ].where((part) => part.isNotEmpty);

    return parts.isEmpty ? 'Cuenta $id' : parts.join(' · ');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'account_name': accountName,
    'bank_name': bankName,
    'balance': balance,
  };
}
