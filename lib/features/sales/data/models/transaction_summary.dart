import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Referencia ligera `{id, name}` de la API (cliente, usuario, sucursal).
class TransactionRef {
  const TransactionRef({required this.id, required this.name});

  factory TransactionRef.fromJson(Map<String, dynamic> json) => TransactionRef(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], '—'),
  );

  /// `null` cuando el objeto viene nulo o vacío.
  static TransactionRef? fromJsonOrNull(Object? value) {
    final map = JsonReader.toMap(value);

    return map.isEmpty ? null : TransactionRef.fromJson(map);
  }

  final int id;
  final String name;
}

/// Venta del historial (`GET /transactions`, contrato §8).
///
/// Tipos **reales** del payload (no se hace aritmética con texto):
/// - **texto decimal**: `subtotal`, `total_discount`, `shipping_cost`.
/// - **número**: `total`, `total_paid`, `remaining_due`, `items_count`.
///
/// `items_count` es el número de **líneas**, no la suma de cantidades. El
/// servidor excluye el canal `abono_a_saldo` de este listado.
class TransactionSummary {
  const TransactionSummary({
    required this.id,
    required this.folio,
    required this.status,
    required this.channel,
    required this.customer,
    required this.user,
    required this.contactName,
    required this.contactPhone,
    required this.deliveryDate,
    required this.layawayExpirationDate,
    required this.subtotal,
    required this.totalDiscount,
    required this.shippingCost,
    required this.total,
    required this.totalPaid,
    required this.remainingDue,
    required this.itemsCount,
    required this.isOrder,
    required this.invoiced,
    required this.createdAt,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    final contact = JsonReader.toMap(json['contact_info']);

    return TransactionSummary(
      id: JsonReader.integerOr(json['id'], 0),
      folio: JsonReader.stringOr(json['folio'], ''),
      status: JsonReader.stringOr(json['status'], ''),
      channel: JsonReader.stringOr(json['channel'], ''),
      customer: TransactionRef.fromJsonOrNull(json['customer']),
      user: TransactionRef.fromJsonOrNull(json['user']),
      contactName: JsonReader.string(contact['name']),
      contactPhone: JsonReader.string(contact['phone']),
      deliveryDate: AppFormatters.parse(json['delivery_date']),
      layawayExpirationDate: AppFormatters.parse(
        json['layaway_expiration_date'],
      ),
      subtotal: Money.toDouble(json['subtotal']),
      totalDiscount: Money.toDouble(json['total_discount']),
      shippingCost: Money.toDouble(json['shipping_cost']),
      total: Money.toDouble(json['total']),
      totalPaid: Money.toDouble(json['total_paid']),
      remainingDue: Money.toDouble(json['remaining_due']),
      itemsCount: JsonReader.integerOr(json['items_count'], 0),
      isOrder: JsonReader.boolean(json['is_order']),
      invoiced: JsonReader.boolean(json['invoiced']),
      createdAt: AppFormatters.parse(json['created_at']),
    );
  }

  final int id;

  /// Folio real del servidor (`V-014`, `ABONO-003`).
  final String folio;
  final String status;
  final String channel;

  /// Cliente asignado (`null` = público en general).
  final TransactionRef? customer;

  /// Usuario que registró la venta.
  final TransactionRef? user;

  /// Nombre y teléfono del pedido/comanda cuando no hay cliente.
  final String? contactName;
  final String? contactPhone;

  /// Fecha de entrega: si existe, la venta es un **pedido**.
  final DateTime? deliveryDate;

  /// Límite para liquidar el **apartado**.
  final DateTime? layawayExpirationDate;

  final double subtotal;
  final double totalDiscount;
  final double shippingCost;
  final double total;
  final double totalPaid;

  /// Saldo pendiente (crédito, apartado o pedido parcial).
  final double remainingDue;

  /// Número de **líneas** (no de piezas).
  final int itemsCount;

  /// Pedido o comanda (`delivery_date` o estatus logístico).
  final bool isOrder;
  final bool invoiced;
  final DateTime? createdAt;

  /// Nombre a mostrar en la lista y en el detalle.
  String get customerLabel {
    final name = customer?.name ?? contactName;
    return (name == null || name.isEmpty) ? 'Público general' : name;
  }

  /// Hay saldo pendiente real: la venta no está anulada (una venta cancelada o
  /// reembolsada conserva su `remaining_due` histórico, pero ya no se cobra).
  bool get hasPendingBalance => remainingDue > 0.01 && !isCancelled;

  /// Venta ya anulada: no admite abonos ni edición de pagos.
  bool get isCancelled => status == 'cancelado' || status == 'reembolsado';

  bool get isLayaway => status == 'apartado';

  /// Días restantes del apartado (negativo si ya venció).
  int? get layawayDaysLeft => AppFormatters.daysUntil(layawayExpirationDate);
}
