import '../theme/status_palette.dart';

/// Catálogo de estatus: valor de la API → etiqueta en español + severidad.
///
/// Copiado literalmente del design system (§7). Los estatus completos y
/// correctos son los que devuelve el servidor; aquí solo se traducen para
/// pintarlos.
class StatusCatalog {
  const StatusCatalog._();

  static const Map<String, String> transactionLabels = <String, String>{
    'completado': 'Completado',
    'pendiente': 'Pendiente',
    'apartado': 'Apartado',
    'entregado_por_pagar': 'Entregado por pagar',
    'por_entregar': 'Por entregar',
    'en_ruta': 'En ruta',
    'reembolsado': 'Reembolsado',
    'cambiado': 'Cambiado',
    'cancelado': 'Cancelado',
  };

  static const Map<String, EzySeverity> transactionSeverities =
      <String, EzySeverity>{
        'completado': EzySeverity.success,
        'pendiente': EzySeverity.warn,
        'apartado': EzySeverity.warn,
        'entregado_por_pagar': EzySeverity.warn,
        'por_entregar': EzySeverity.info,
        'en_ruta': EzySeverity.info,
        'reembolsado': EzySeverity.info,
        'cambiado': EzySeverity.neutral,
        'cancelado': EzySeverity.danger,
      };

  static const Map<String, String> serviceOrderLabels = <String, String>{
    'pendiente': 'Pendiente',
    'en_progreso': 'En progreso',
    'esperando_refaccion': 'Esperando refacción',
    'terminado': 'Terminado',
    'entregado': 'Entregado',
    'cancelado': 'Cancelado',
  };

  static const Map<String, EzySeverity> serviceOrderSeverities =
      <String, EzySeverity>{
        'pendiente': EzySeverity.warn,
        'en_progreso': EzySeverity.info,
        'esperando_refaccion': EzySeverity.neutral,
        'terminado': EzySeverity.success,
        'entregado': EzySeverity.success,
        'cancelado': EzySeverity.danger,
      };

  /// Orden del flujo de una orden de servicio (stepper, §8.2).
  static const List<String> serviceOrderFlow = <String>[
    'pendiente',
    'en_progreso',
    'esperando_refaccion',
    'terminado',
    'entregado',
  ];

  static String transactionLabel(String status) =>
      transactionLabels[status] ?? status;

  static String serviceOrderLabel(String status) =>
      serviceOrderLabels[status] ?? status;

  static EzySeverity transactionSeverity(String status) =>
      transactionSeverities[status] ?? EzySeverity.neutral;

  static EzySeverity serviceOrderSeverity(String status) =>
      serviceOrderSeverities[status] ?? EzySeverity.neutral;

  /// Índice del estatus dentro del flujo (`-1` si es `cancelado`).
  static int serviceOrderStepIndex(String status) =>
      serviceOrderFlow.indexOf(status);
}
