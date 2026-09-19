import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';
import '../../../cash/data/models/bank_account.dart';
import 'transaction_payment_method.dart';
import 'transaction_summary.dart';

/// Cliente del detalle: el listado solo trae `{id, name}`, el detalle añade
/// `balance` y `credit_limit` (**texto decimal**).
class TransactionCustomer {
  const TransactionCustomer({
    required this.id,
    required this.name,
    required this.balance,
    required this.creditLimit,
  });

  factory TransactionCustomer.fromJson(Map<String, dynamic> json) =>
      TransactionCustomer(
        id: JsonReader.integerOr(json['id'], 0),
        name: JsonReader.stringOr(json['name'], '—'),
        // `balance < 0` = debe; `balance > 0` = saldo a favor.
        balance: Money.toDouble(json['balance']),
        creditLimit: Money.toDouble(json['credit_limit']),
      );

  /// `null` cuando la venta es de público general.
  static TransactionCustomer? fromJsonOrNull(Object? value) {
    final map = JsonReader.toMap(value);

    return map.isEmpty ? null : TransactionCustomer.fromJson(map);
  }

  final int id;
  final String name;
  final double balance;
  final double creditLimit;

  /// Saldo a favor disponible.
  bool get hasBalanceInFavor => balance > 0.01;

  /// Deuda pendiente con el negocio.
  bool get hasDebt => balance < -0.01;
}

/// Línea de la venta (`items[]` del detalle).
///
/// Dinero en **texto decimal**: `unit_price`, `discount_amount`, `tax_amount` y
/// `line_total`; `quantity` es numérico con hasta 3 decimales.
class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.description,
    required this.itemableType,
    required this.itemableId,
    required this.quantity,
    required this.unitPrice,
    required this.discountAmount,
    required this.discountReason,
    required this.taxAmount,
    required this.lineTotal,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) =>
      TransactionItem(
        id: JsonReader.integerOr(json['id'], 0),
        description: JsonReader.stringOr(json['description'], ''),
        itemableType: JsonReader.stringOr(json['itemable_type'], ''),
        itemableId: JsonReader.integer(json['itemable_id']),
        quantity: Money.toDouble(json['quantity'], fallback: 1),
        unitPrice: Money.toDouble(json['unit_price']),
        discountAmount: Money.toDouble(json['discount_amount']),
        discountReason: JsonReader.string(json['discount_reason']),
        taxAmount: Money.toDouble(json['tax_amount']),
        lineTotal: Money.toDouble(json['line_total']),
      );

  final int id;

  /// Texto congelado al momento de la venta.
  final String description;

  /// Modelo de origen (`App\Models\Product`, `App\Models\Service`, ...).
  final String itemableType;
  final int? itemableId;
  final double quantity;

  /// Precio unitario final (con descuento aplicado).
  final double unitPrice;

  /// Descuento **por unidad**.
  final double discountAmount;
  final String? discountReason;
  final double taxAmount;
  final double lineTotal;

  bool get hasDiscount => discountAmount > 0.001;
  bool get isIncrease => (discountReason ?? '') == 'Aumento manual';
}

/// Pago de la venta (`payments[]` del detalle). `amount` es **texto decimal** y
/// puede ser negativo (devolución o reembolso).
class TransactionPayment {
  const TransactionPayment({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.paymentDate,
    required this.notes,
    required this.bankAccount,
  });

  factory TransactionPayment.fromJson(Map<String, dynamic> json) {
    final bank = JsonReader.toMap(json['bank_account']);

    return TransactionPayment(
      id: JsonReader.integerOr(json['id'], 0),
      amount: Money.toDouble(json['amount']),
      paymentMethod: JsonReader.stringOr(json['payment_method'], ''),
      status: JsonReader.stringOr(json['status'], ''),
      paymentDate: AppFormatters.parse(json['payment_date']),
      notes: JsonReader.string(json['notes']),
      bankAccount: bank.isEmpty ? null : BankAccount.fromJson(bank),
    );
  }

  final int id;
  final double amount;
  final String paymentMethod;
  final String status;
  final DateTime? paymentDate;
  final String? notes;

  /// Cuenta destino (formato de `GET /bank-accounts`), `null` en efectivo.
  final BankAccount? bankAccount;

  /// Etiqueta del método (`Efectivo`, `Tarjeta`, `Saldo de cliente`, ...).
  String get methodLabel => TransactionPaymentMethod.labelOf(paymentMethod);

  TransactionPaymentMethod? get method =>
      TransactionPaymentMethod.fromValue(paymentMethod);

  /// Devolución de dinero (monto negativo).
  bool get isRefund => amount < -0.001;
}

/// Factura CFDI de la venta (solo identidad; el detalle fiscal no es móvil).
class TransactionInvoice {
  const TransactionInvoice({
    required this.id,
    required this.folio,
    required this.status,
  });

  factory TransactionInvoice.fromJson(Map<String, dynamic> json) =>
      TransactionInvoice(
        id: JsonReader.integerOr(json['id'], 0),
        folio: JsonReader.stringOr(json['folio'], ''),
        status: JsonReader.stringOr(json['status'], ''),
      );

  final int id;
  final String folio;
  final String status;
}

/// Detalle completo de una venta (`GET /transactions/{id}`, contrato §8).
///
/// Reutiliza [TransactionSummary] para los campos del listado y añade los que
/// solo trae el detalle: `branch`, `customer` con saldos, `notes`,
/// `shipping_address`, `total_tax`, `paid_amount`, `pending_balance`, `is_paid`,
/// `cash_register_session` (solo id), `invoice`, `items[]` y `payments[]`.
class TransactionDetail {
  const TransactionDetail({
    required this.summary,
    required this.branch,
    required this.customer,
    required this.notes,
    required this.shippingAddress,
    required this.totalTax,
    required this.paidAmount,
    required this.pendingBalance,
    required this.isPaid,
    required this.cashRegisterSessionId,
    required this.invoice,
    required this.items,
    required this.payments,
  });

  factory TransactionDetail.fromJson(Map<String, dynamic> json) {
    final session = JsonReader.toMap(json['cash_register_session']);
    final invoice = JsonReader.toMap(json['invoice']);

    return TransactionDetail(
      summary: TransactionSummary.fromJson(json),
      branch: TransactionRef.fromJsonOrNull(json['branch']),
      customer: TransactionCustomer.fromJsonOrNull(json['customer']),
      notes: JsonReader.string(json['notes']),
      shippingAddress: JsonReader.string(json['shipping_address']),
      totalTax: Money.toDouble(json['total_tax']),
      paidAmount: Money.toDouble(json['paid_amount']),
      pendingBalance: Money.toDouble(json['pending_balance']),
      isPaid: JsonReader.boolean(json['is_paid']),
      cashRegisterSessionId: JsonReader.integer(session['id']),
      invoice: invoice.isEmpty ? null : TransactionInvoice.fromJson(invoice),
      items: JsonReader.toMapList(
        json['items'],
      ).map(TransactionItem.fromJson).toList(growable: false),
      payments: JsonReader.toMapList(
        json['payments'],
      ).map(TransactionPayment.fromJson).toList(growable: false),
    );
  }

  final TransactionSummary summary;

  /// Sucursal donde se cobró.
  final TransactionRef? branch;

  /// Cliente con saldo y límite de crédito (`null` = público general).
  final TransactionCustomer? customer;

  final String? notes;
  final String? shippingAddress;

  /// Siempre `0` en POS (no hay motor de impuestos).
  final double totalTax;

  /// Desglose de pagos ya resuelto por el servidor.
  final double paidAmount;
  final double pendingBalance;
  final bool isPaid;

  /// Sesión de caja donde se cobró (solo el id).
  final int? cashRegisterSessionId;

  final TransactionInvoice? invoice;
  final List<TransactionItem> items;
  final List<TransactionPayment> payments;

  // --- Atajos del listado (evitan encadenar `summary.` en la UI) -------------

  int get id => summary.id;
  String get folio => summary.folio;
  String get status => summary.status;
  String get channel => summary.channel;
  double get subtotal => summary.subtotal;
  double get totalDiscount => summary.totalDiscount;
  double get shippingCost => summary.shippingCost;
  double get total => summary.total;
  double get remainingDue => summary.remainingDue;
  int get itemsCount => summary.itemsCount;
  bool get isOrder => summary.isOrder;
  DateTime? get createdAt => summary.createdAt;
  DateTime? get deliveryDate => summary.deliveryDate;
  DateTime? get layawayExpirationDate => summary.layawayExpirationDate;
  bool get isCancelled => summary.isCancelled;
  bool get isLayaway => summary.isLayaway;
  int? get layawayDaysLeft => summary.layawayDaysLeft;
  String get customerLabel => summary.customerLabel;

  /// Se puede abonar: queda saldo y la venta no está anulada.
  bool get canReceivePayment => !isCancelled && pendingBalance > 0.01;

  /// Se puede anular/reembolsar.
  bool get canBeCancelled => !isCancelled;

  /// Se pueden editar o borrar pagos (misma regla que la web).
  bool get canEditPayments => !isCancelled && payments.isNotEmpty;

  bool get hasInvoice => invoice != null;
}
