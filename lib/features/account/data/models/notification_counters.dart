import '../../../../core/utils/json_reader.dart';

/// Categorías de la campana de notificaciones (`GET /notifications`).
///
/// Los cuatro contadores llegan **siempre** (aunque el usuario no tenga acceso a
/// ventas: en ese caso vienen en `0`), así que la pantalla nunca inventa filas.
enum NotificationCategory {
  expiringDebts(
    wire: 'expiring_debts',
    label: 'Deudas por vencer',
    description: 'Apartados y créditos que vencen en los próximos 3 días.',
  ),
  upcomingDeliveries(
    wire: 'upcoming_deliveries',
    label: 'Entregas próximas',
    description: 'Pedidos por entregar con fecha en los próximos 3 días.',
  ),
  unreadUpdates(
    wire: 'unread_updates',
    label: 'Novedades',
    description: 'Notas de la versión que no has leído.',
  ),
  pendingOrders(
    wire: 'pending_orders',
    label: 'Pedidos pendientes',
    description: 'Pedidos de la tienda en línea pendientes o en revisión.',
  );

  const NotificationCategory({
    required this.wire,
    required this.label,
    required this.description,
  });

  /// Nombre exacto del campo en la respuesta del servidor.
  final String wire;

  /// Texto de UI (sentence case, §11 del design system).
  final String label;

  /// Explicación de lo que cuenta el contador.
  final String description;
}

/// Contadores del icono de campana (`GET /notifications`, contrato §11b.2).
///
/// `total` lo calcula el servidor (suma de los cuatro); la app solo lo muestra.
class NotificationCounters {
  const NotificationCounters({
    this.expiringDebts = 0,
    this.upcomingDeliveries = 0,
    this.unreadUpdates = 0,
    this.pendingOrders = 0,
    this.total = 0,
  });

  factory NotificationCounters.fromJson(Map<String, dynamic> json) =>
      NotificationCounters(
        expiringDebts: JsonReader.integerOr(json['expiring_debts'], 0),
        upcomingDeliveries: JsonReader.integerOr(
          json['upcoming_deliveries'],
          0,
        ),
        unreadUpdates: JsonReader.integerOr(json['unread_updates'], 0),
        pendingOrders: JsonReader.integerOr(json['pending_orders'], 0),
        total: JsonReader.integerOr(json['total'], 0),
      );

  const NotificationCounters.empty() : this();

  final int expiringDebts;
  final int upcomingDeliveries;
  final int unreadUpdates;
  final int pendingOrders;

  /// Suma de los cuatro contadores, calculada por el servidor.
  final int total;

  /// `true` si todos los contadores están en cero.
  bool get isEmpty =>
      expiringDebts == 0 &&
      upcomingDeliveries == 0 &&
      unreadUpdates == 0 &&
      pendingOrders == 0;

  /// Contador de una categoría.
  int countFor(NotificationCategory category) => switch (category) {
    NotificationCategory.expiringDebts => expiringDebts,
    NotificationCategory.upcomingDeliveries => upcomingDeliveries,
    NotificationCategory.unreadUpdates => unreadUpdates,
    NotificationCategory.pendingOrders => pendingOrders,
  };

  /// Categorías con al menos un aviso, en el orden del design system (§14.6).
  List<NotificationCategory> get categoriesWithItems => NotificationCategory
      .values
      .where((category) => countFor(category) > 0)
      .toList(growable: false);

  /// Cuerpo tal como lo entrega el servidor (se guarda en la caché local).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'expiring_debts': expiringDebts,
    'upcoming_deliveries': upcomingDeliveries,
    'unread_updates': unreadUpdates,
    'pending_orders': pendingOrders,
    'total': total,
  };
}
