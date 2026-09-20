import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/status_catalog.dart';
import 'service_order_status.dart';

/// Orden de servicio del listado (`GET /service-orders`, contrato §9).
///
/// Tipos **reales** del payload (nunca se hace aritmética con texto):
/// - **texto decimal**: `subtotal`, `discount_amount`, `final_total`.
/// - **número**: `total_paid`, `amount_due`.
///
/// `has_transaction` es `false` en órdenes antiguas que aún no tienen venta
/// vinculada: en esas primero se llama a `ensure-transaction`.
class ServiceOrderSummary {
  const ServiceOrderSummary({
    required this.id,
    required this.folio,
    required this.customerName,
    required this.customerPhone,
    required this.itemDescription,
    required this.status,
    required this.technicianName,
    required this.receivedAt,
    required this.promisedAt,
    required this.subtotal,
    required this.discountAmount,
    required this.finalTotal,
    required this.totalPaid,
    required this.amountDue,
    required this.hasTransaction,
    required this.createdAt,
  });

  factory ServiceOrderSummary.fromJson(Map<String, dynamic> json) =>
      ServiceOrderSummary(
        id: JsonReader.integerOr(json['id'], 0),
        folio: JsonReader.stringOr(json['folio'], ''),
        customerName: JsonReader.string(json['customer_name']),
        customerPhone: JsonReader.string(json['customer_phone']),
        itemDescription: JsonReader.stringOr(json['item_description'], ''),
        status: JsonReader.stringOr(json['status'], ''),
        technicianName: JsonReader.string(json['technician_name']),
        receivedAt: AppFormatters.parse(json['received_at']),
        promisedAt: AppFormatters.parse(json['promised_at']),
        subtotal: Money.toDouble(json['subtotal']),
        discountAmount: Money.toDouble(json['discount_amount']),
        finalTotal: Money.toDouble(json['final_total']),
        totalPaid: Money.toDouble(json['total_paid']),
        amountDue: Money.toDouble(json['amount_due']),
        hasTransaction: JsonReader.boolean(json['has_transaction']),
        createdAt: AppFormatters.parse(json['created_at']),
      );

  final int id;

  /// Folio real del servidor (`OS-014`).
  final String folio;

  /// `null` en las órdenes de mostrador sin cliente registrado.
  final String? customerName;
  final String? customerPhone;

  /// Equipo recibido (`item_description`).
  final String itemDescription;
  final String status;
  final String? technicianName;

  /// Cuándo se recibió el equipo (hora local del dispositivo).
  final DateTime? receivedAt;

  /// Fecha prometida de entrega.
  final DateTime? promisedAt;

  final double subtotal;
  final double discountAmount;

  /// `final_total`: lo que paga el cliente por la orden.
  final double finalTotal;

  /// Suma de los pagos de la venta vinculada.
  final double totalPaid;

  /// `final_total - Σ pagos`, nunca negativo.
  final double amountDue;

  /// `false` en órdenes antiguas sin venta vinculada.
  final bool hasTransaction;
  final DateTime? createdAt;

  ServiceOrderStatus? get orderStatus => ServiceOrderStatus.fromValue(status);

  String get statusLabel => StatusCatalog.serviceOrderLabel(status);

  /// Nombre a mostrar en la lista.
  String get customerLabel {
    final name = customerName;

    return (name == null || name.trim().isEmpty) ? 'Sin cliente' : name;
  }

  /// Queda saldo por cobrar y la orden no está cancelada.
  bool get hasPendingAmount => amountDue > 0.01 && !isCancelled;

  bool get isCancelled =>
      orderStatus?.isCancelled ?? (status == 'cancelado');

  /// La orden se puede cobrar: tiene venta vinculada y queda saldo.
  bool get canReceivePayment => hasTransaction && hasPendingAmount;

  /// Días restantes para la fecha prometida (negativo si ya venció).
  int? get promiseDaysLeft => AppFormatters.daysUntil(promisedAt);

  /// La promesa de entrega ya venció y la orden sigue abierta.
  bool get isPromiseLate {
    final days = promiseDaysLeft;

    return days != null && days < 0 && !isCancelled && status != 'entregado';
  }
}
