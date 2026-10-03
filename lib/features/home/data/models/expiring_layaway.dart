import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Texto decimal del contrato: dos decimales y sin separador de miles.
String _decimal(double value) => value.toStringAsFixed(2);

/// Fila de `GET /dashboard/expiring-layaways` (§3b.3).
///
/// `days_remaining` e `is_overdue` los calcula el **servidor** con la zona
/// horaria del negocio: aquí solo se guardan.
class ExpiringLayaway {
  const ExpiringLayaway({
    required this.id,
    required this.folio,
    required this.type,
    required this.status,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.totalAmount,
    required this.totalPaid,
    required this.pendingAmount,
    required this.expirationDate,
    required this.daysRemaining,
    required this.isOverdue,
  });

  factory ExpiringLayaway.fromJson(Map<String, dynamic> json) {
    return ExpiringLayaway(
      id: JsonReader.integerOr(json['id'], 0),
      folio: JsonReader.stringOr(json['folio'], ''),
      type: JsonReader.stringOr(json['type'], ''),
      status: JsonReader.stringOr(json['status'], ''),
      customerId: JsonReader.integer(json['customer_id']),
      customerName: JsonReader.stringOr(json['customer_name'], ''),
      customerPhone: JsonReader.string(json['customer_phone']),
      totalAmount: Money.toDouble(json['total_amount']),
      totalPaid: Money.toDouble(json['total_paid']),
      pendingAmount: Money.toDouble(json['pending_amount']),
      expirationDate: JsonReader.stringOr(json['expiration_date'], ''),
      daysRemaining: JsonReader.integerOr(json['days_remaining'], 0),
      isOverdue: JsonReader.boolean(json['is_overdue']),
    );
  }

  final int id;
  final String folio;

  /// `apartado` | `credito`: etiqueta para la UI.
  final String type;

  /// Valor real del enum (`apartado` | `pendiente`).
  final String status;

  /// `null` si la venta no tiene cliente registrado.
  final int? customerId;

  /// `"Público en general"` cuando la venta no tiene cliente.
  final String customerName;

  final String? customerPhone;
  final double totalAmount;
  final double totalPaid;
  final double pendingAmount;

  /// Fecha **local** `YYYY-MM-DD`, sin hora (así se captura en el POS).
  final String expirationDate;

  /// Días de calendario hasta la fecha: hoy es `0`, negativo si venció.
  final int daysRemaining;

  final bool isOverdue;

  bool get isDueToday => daysRemaining == 0 && !isOverdue;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'folio': folio,
    'type': type,
    'status': status,
    'customer_id': customerId,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'total_amount': _decimal(totalAmount),
    'total_paid': _decimal(totalPaid),
    'pending_amount': _decimal(pendingAmount),
    'expiration_date': expirationDate,
    'days_remaining': daysRemaining,
    'is_overdue': isOverdue,
  };
}

/// Envoltura de la respuesta completa: `days` es la ventana **realmente**
/// aplicada y se reusa en el título («Próximos 3 días»).
class ExpiringLayawaysResult {
  const ExpiringLayawaysResult({required this.days, required this.items});

  factory ExpiringLayawaysResult.fromJson(Map<String, dynamic> json) {
    return ExpiringLayawaysResult(
      days: JsonReader.integerOr(json['days'], 0),
      items: JsonReader.toMapList(
        json['data'],
      ).map(ExpiringLayaway.fromJson).toList(growable: false),
    );
  }

  final int days;
  final List<ExpiringLayaway> items;

  static const ExpiringLayawaysResult empty = ExpiringLayawaysResult(
    days: 0,
    items: <ExpiringLayaway>[],
  );
}
