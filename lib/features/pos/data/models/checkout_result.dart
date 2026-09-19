import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Pista de impresión que devuelve el cobro (`print`).
///
/// La app solo guarda los ids de plantilla; el ticket se genera en la etapa de
/// impresión con `POST /print/bluetooth-payload`.
class PrintHint {
  const PrintHint({
    required this.dataSourceType,
    required this.dataSourceId,
    required this.templateIds,
  });

  factory PrintHint.fromJson(Map<String, dynamic> json) => PrintHint(
    dataSourceType: JsonReader.stringOr(json['data_source_type'], ''),
    dataSourceId: JsonReader.integerOr(json['data_source_id'], 0),
    templateIds: JsonReader.intList(json['template_ids']),
  );

  final String dataSourceType;
  final int dataSourceId;
  final List<int> templateIds;
}

/// Venta registrada (`transaction` de la respuesta del cobro).
class CheckoutTransaction {
  const CheckoutTransaction({
    required this.id,
    required this.folio,
    required this.status,
    required this.channel,
    required this.subtotal,
    required this.totalDiscount,
    required this.total,
    required this.totalPaid,
    required this.remainingDue,
    required this.itemsCount,
    required this.customerName,
    required this.createdAt,
  });

  factory CheckoutTransaction.fromJson(Map<String, dynamic> json) {
    final customer = JsonReader.toMap(json['customer']);

    return CheckoutTransaction(
      id: JsonReader.integerOr(json['id'], 0),
      folio: JsonReader.stringOr(json['folio'], ''),
      status: JsonReader.stringOr(json['status'], ''),
      channel: JsonReader.stringOr(json['channel'], ''),
      subtotal: Money.toDouble(json['subtotal']),
      totalDiscount: Money.toDouble(json['total_discount']),
      total: Money.toDouble(json['total']),
      totalPaid: Money.toDouble(json['total_paid']),
      remainingDue: Money.toDouble(json['remaining_due']),
      itemsCount: JsonReader.integerOr(json['items_count'], 0),
      customerName: JsonReader.string(customer['name']),
      createdAt: AppFormatters.parse(json['created_at']),
    );
  }

  final int id;

  /// Folio real que asigna el servidor (`V-014`).
  final String folio;
  final String status;
  final String channel;
  final double subtotal;
  final double totalDiscount;
  final double total;
  final double totalPaid;

  /// Saldo pendiente (venta a crédito, apartado o pedido parcial).
  final double remainingDue;

  /// Número de **líneas**, no de piezas.
  final int itemsCount;
  final String? customerName;
  final DateTime? createdAt;

  bool get isFullyPaid => remainingDue <= 0.01;
}

/// Respuesta de `POST /pos/checkout`, `/pos/layaway` y `/pos/store-order`.
class CheckoutResult {
  const CheckoutResult({
    required this.transaction,
    required this.change,
    required this.printHint,
  });

  factory CheckoutResult.fromJson(Map<String, dynamic> json) => CheckoutResult(
    transaction: CheckoutTransaction.fromJson(
      JsonReader.toMap(json['transaction']),
    ),
    // Cambio en efectivo calculado por el servidor (0 en pagos mixtos).
    change: Money.toDouble(json['change']),
    printHint: PrintHint.fromJson(JsonReader.toMap(json['print'])),
  );

  final CheckoutTransaction transaction;
  final double change;
  final PrintHint printHint;

  bool get hasChange => change > 0.01;
}
