import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Cuenta bancaria que la app precarga al abrir caja.
///
/// Mismo formato en `GET /cash-register-sessions/current`, `GET /bank-accounts`
/// y en `payments[].bank_account` (`name` ya viene listo para mostrar:
/// `"Cuenta principal - BBVA (...4471)"`).
class BankAccount {
  const BankAccount({
    required this.id,
    required this.name,
    required this.bankName,
    required this.accountName,
    required this.balance,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    bankName: JsonReader.string(json['bank_name']),
    accountName: JsonReader.string(json['account_name']),
    // `balance` llega como texto decimal (`"5000.00"`).
    balance: Money.toDouble(json['balance']),
  );

  final int id;

  /// Etiqueta lista para mostrar.
  final String name;
  final String? bankName;
  final String? accountName;

  /// Saldo actual de la cuenta (el servidor lo aplica al abrirlo caja).
  final double balance;

  String get label => name.isEmpty ? 'Cuenta $id' : name;
}
