import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Texto decimal del contrato: dos decimales y sin separador de miles.
String _decimal(double value) => value.toStringAsFixed(2);

/// Fila de `GET /dashboard/upcoming-deliveries` (§3b.4).
///
/// `delivery_date` se guarda como **día en medianoche UTC**: no se convierte a
/// hora local (en México el instante cae el día anterior). Para pintar la fecha
/// se usa [deliveryDay] (la parte `YYYY-MM-DD`) o los campos que ya calcula el
/// servidor ([daysRemaining], [isToday], [isOverdue]).
class UpcomingDelivery {
  const UpcomingDelivery({
    required this.id,
    required this.folio,
    required this.status,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.shippingAddress,
    this.notes,
    required this.totalAmount,
    required this.totalPaid,
    required this.pendingAmount,
    required this.deliveryDate,
    required this.daysRemaining,
    required this.isToday,
    required this.isOverdue,
  });

  factory UpcomingDelivery.fromJson(Map<String, dynamic> json) {
    return UpcomingDelivery(
      id: JsonReader.integerOr(json['id'], 0),
      folio: JsonReader.stringOr(json['folio'], ''),
      status: JsonReader.stringOr(json['status'], ''),
      customerId: JsonReader.integer(json['customer_id']),
      customerName: JsonReader.stringOr(json['customer_name'], ''),
      customerPhone: JsonReader.string(json['customer_phone']),
      shippingAddress: JsonReader.string(json['shipping_address']),
      notes: JsonReader.string(json['notes']),
      totalAmount: Money.toDouble(json['total_amount']),
      totalPaid: Money.toDouble(json['total_paid']),
      pendingAmount: Money.toDouble(json['pending_amount']),
      deliveryDate: JsonReader.stringOr(json['delivery_date'], ''),
      daysRemaining: JsonReader.integerOr(json['days_remaining'], 0),
      isToday: JsonReader.boolean(json['is_today']),
      isOverdue: JsonReader.boolean(json['is_overdue']),
    );
  }

  final int id;
  final String folio;

  /// Siempre `por_entregar` (solo informativo).
  final String status;

  final int? customerId;

  /// `"Cliente invitado"` si no hay cliente ni contacto en el pedido.
  final String customerName;

  final String? customerPhone;
  final String? shippingAddress;

  /// Nota del pedido; puede venir `null`.
  final String? notes;

  final double totalAmount;

  /// Suma de los abonos (`"total_paid"` en este payload, **no** `paid_amount`).
  final double totalPaid;

  /// Lo que se cobra al entregar; nunca negativo.
  final double pendingAmount;

  /// ISO-8601 UTC del día de entrega (sin hora real).
  final String deliveryDate;

  /// 0 = hoy, negativo = vencida.
  final int daysRemaining;

  final bool isToday;
  final bool isOverdue;

  /// `YYYY-MM-DD` del día de entrega, sin conversión de zona horaria.
  String get deliveryDay => deliveryDate.length >= 10
      ? deliveryDate.substring(0, 10)
      : deliveryDate;

  bool get hasPendingAmount => pendingAmount > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'folio': folio,
    'status': status,
    'customer_id': customerId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'shipping_address': shippingAddress,
    'notes': notes,
    'total_amount': _decimal(totalAmount),
    'total_paid': _decimal(totalPaid),
    'pending_amount': _decimal(pendingAmount),
    'delivery_date': deliveryDate,
    'days_remaining': daysRemaining,
    'is_today': isToday,
    'is_overdue': isOverdue,
  };
}

/// Envoltura de la respuesta completa (`days` = ventana aplicada).
class UpcomingDeliveriesResult {
  const UpcomingDeliveriesResult({required this.days, required this.items});

  factory UpcomingDeliveriesResult.fromJson(Map<String, dynamic> json) {
    return UpcomingDeliveriesResult(
      days: JsonReader.integerOr(json['days'], 0),
      items: JsonReader.toMapList(
        json['data'],
      ).map(UpcomingDelivery.fromJson).toList(growable: false),
    );
  }

  final int days;
  final List<UpcomingDelivery> items;

  static const UpcomingDeliveriesResult empty = UpcomingDeliveriesResult(
    days: 0,
    items: <UpcomingDelivery>[],
  );
}
