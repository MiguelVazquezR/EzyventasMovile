import '../../../../core/utils/status_catalog.dart';

/// Etiquetas del módulo de ventas (español, sentence case).
class SalesLabels {
  const SalesLabels._();

  /// Estatus ofrecidos en los chips del historial, en orden de flujo.
  static const List<String> statusFilters = <String>[
    'completado',
    'pendiente',
    'apartado',
    'por_entregar',
    'en_ruta',
    'entregado_por_pagar',
    'cancelado',
    'reembolsado',
    'cambiado',
  ];

  /// Estatus de los pedidos con entrega pendiente (`TransactionStatus::TO_DELIVER`).
  ///
  /// Lo usan los avisos de "Entregas próximas" para abrir el historial ya
  /// filtrado por el mismo estatus que cuenta el servidor.
  static const String toDeliver = 'por_entregar';

  /// Estatus que cuenta `expiring_debts` (`GET /notifications`).
  ///
  /// El contador mezcla apartados y créditos: el historial los pide juntos en
  /// una sola llamada (`?status[]=apartado&status[]=pendiente`, contrato §8).
  static const List<String> expiringDebtStatuses = <String>[
    'apartado',
    'pendiente',
  ];

  /// Canal de la venta (`channel` del contrato §8).
  static const Map<String, String> _channelLabels = <String, String>{
    'punto_de_venta': 'Punto de venta',
    'tienda_en_linea': 'Tienda en línea',
    'orden_de_servicio': 'Orden de servicio',
    'cotizacion': 'Cotización',
    'manual': 'Manual',
    'abono_a_saldo': 'Abono a saldo',
    'whatsapp': 'WhatsApp',
  };

  static String status(String status) => StatusCatalog.transactionLabel(status);

  static String channel(String channel) =>
      _channelLabels[channel] ?? (channel.isEmpty ? '—' : channel);

  /// `3 líneas` / `1 línea`.
  static String lines(int count) => count == 1 ? '1 línea' : '$count líneas';
}
