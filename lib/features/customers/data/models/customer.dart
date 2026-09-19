import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Cliente en formato de listado (`GET /customers` y `POST /customers`).
///
/// Tipos confirmados contra la API real:
/// - `balance` / `credit_limit`: **texto decimal** (`"0.00"`, `"1000.00"`)
/// - `available_credit`: **número** (`1000`)
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.companyName,
    required this.email,
    required this.phone,
    required this.balance,
    required this.creditLimit,
    required this.availableCredit,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    companyName: JsonReader.string(json['company_name']),
    email: JsonReader.string(json['email']),
    phone: JsonReader.string(json['phone']),
    balance: Money.toDouble(json['balance']),
    creditLimit: Money.toDouble(json['credit_limit']),
    availableCredit: Money.toDouble(json['available_credit']),
  );

  final int id;
  final String name;
  final String? companyName;
  final String? email;
  final String? phone;

  /// `balance < 0` = debe; `balance > 0` = saldo a favor.
  final double balance;
  final double creditLimit;

  /// Crédito disponible calculado por el servidor.
  final double availableCredit;

  /// Tiene saldo a favor (se puede ofrecer `use_balance` al cobrar).
  bool get hasBalanceInFavor => balance > 0;

  /// Tiene deuda pendiente.
  bool get hasDebt => balance < 0;

  bool get hasCredit => creditLimit > 0;

  /// Nombre a mostrar: razón social si existe (empresa), si no el nombre.
  String get displayName =>
      (companyName != null && companyName!.isNotEmpty) ? companyName! : name;
}

/// Ficha completa del cliente (`GET /customers/{id}`).
class CustomerDetail {
  const CustomerDetail({
    required this.customer,
    required this.address,
    required this.taxId,
    required this.taxRegime,
    required this.layaways,
    required this.balanceMovements,
  });

  factory CustomerDetail.fromJson(Map<String, dynamic> json) => CustomerDetail(
    customer: Customer.fromJson(json),
    address: JsonReader.toMap(json['address']),
    taxId: JsonReader.string(json['tax_id']),
    taxRegime: JsonReader.string(json['tax_regime']),
    layaways: JsonReader.toMapList(
      json['layaway_transactions'],
    ).map(CustomerLayaway.fromJson).toList(growable: false),
    balanceMovements: JsonReader.toMapList(
      json['balance_movements'],
    ).map(BalanceMovement.fromJson).toList(growable: false),
  );

  final Customer customer;
  final Map<String, dynamic> address;
  final String? taxId;
  final String? taxRegime;

  /// Apartados activos del cliente.
  final List<CustomerLayaway> layaways;

  /// Últimos 50 movimientos de saldo.
  final List<BalanceMovement> balanceMovements;

  /// Dirección en una línea, si hay datos.
  String? get addressLine {
    final parts = <String>[
      JsonReader.stringOr(address['street'], ''),
      JsonReader.stringOr(address['city'], ''),
      JsonReader.stringOr(address['state'], ''),
      JsonReader.stringOr(address['zip_code'], ''),
    ].where((part) => part.isNotEmpty);

    return parts.isEmpty ? null : parts.join(', ');
  }
}

/// Apartado activo de la ficha del cliente.
class CustomerLayaway {
  const CustomerLayaway({
    required this.id,
    required this.folio,
    required this.createdAt,
    required this.expiresAt,
    required this.total,
    required this.totalPaid,
    required this.pendingAmount,
    required this.itemsCount,
  });

  factory CustomerLayaway.fromJson(Map<String, dynamic> json) => CustomerLayaway(
    id: JsonReader.integerOr(json['id'], 0),
    folio: JsonReader.stringOr(json['folio'], ''),
    createdAt: AppFormatters.parse(json['created_at']),
    expiresAt: AppFormatters.parse(json['expires_at']),
    total: Money.toDouble(json['total']),
    totalPaid: Money.toDouble(json['total_paid']),
    pendingAmount: Money.toDouble(json['pending_amount']),
    itemsCount: Money.toInt(json['items_count']),
  );

  final int id;
  final String folio;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final double total;
  final double totalPaid;
  final double pendingAmount;

  /// Número de **líneas** del apartado (no de piezas).
  final int itemsCount;

  /// Días restantes para apartar (negativo si ya venció).
  int? get daysLeft => AppFormatters.daysUntil(expiresAt);
}

/// Movimiento de saldo del cliente (deuda o saldo a favor).
class BalanceMovement {
  const BalanceMovement({
    required this.date,
    required this.type,
    required this.description,
    required this.amount,
    required this.resultingBalance,
    required this.transactionId,
  });

  factory BalanceMovement.fromJson(Map<String, dynamic> json) =>
      BalanceMovement(
        date: AppFormatters.parse(json['date']),
        type: JsonReader.stringOr(json['type'], ''),
        description: JsonReader.string(json['description']),
        amount: Money.toDouble(json['amount']),
        resultingBalance: Money.toDouble(json['resulting_balance']),
        transactionId: JsonReader.integer(json['transaction_id']),
      );

  final DateTime? date;
  final String type;
  final String? description;
  final double amount;
  final double resultingBalance;
  final int? transactionId;

  bool get isCharge => amount < 0;
}
