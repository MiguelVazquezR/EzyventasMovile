import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/status_catalog.dart';

/// Estatus de una orden de servicio (`status` del contrato §9).
///
/// Los valores son los que acepta `PATCH /service-orders/{id}/status`
/// (`Rule::enum(ServiceOrderStatus::class)`); las etiquetas y las severidades se
/// leen del catálogo del design system (§7) para no duplicar textos.
enum ServiceOrderStatus {
  pending('pendiente'),
  inProgress('en_progreso'),
  waitingParts('esperando_refaccion'),
  finished('terminado'),
  delivered('entregado'),
  cancelled('cancelado');

  const ServiceOrderStatus(this.value);

  /// Valor que viaja en la API.
  final String value;

  /// Texto de UI (sentence case).
  String get label => StatusCatalog.serviceOrderLabel(value);

  EzySeverity get severity => StatusCatalog.serviceOrderSeverity(value);

  bool get isCancelled => this == ServiceOrderStatus.cancelled;

  /// `null` si el servidor devolvió un estatus desconocido (no inventar).
  static ServiceOrderStatus? fromValue(String? value) {
    for (final status in ServiceOrderStatus.values) {
      if (status.value == value) {
        return status;
      }
    }

    return null;
  }

  /// Flujo natural de la orden (§8.2): `cancelado` no forma parte del stepper.
  static const List<ServiceOrderStatus> flow = <ServiceOrderStatus>[
    ServiceOrderStatus.pending,
    ServiceOrderStatus.inProgress,
    ServiceOrderStatus.waitingParts,
    ServiceOrderStatus.finished,
    ServiceOrderStatus.delivered,
  ];

  /// Posición dentro del stepper (`-1` cuando la orden está cancelada).
  int get flowIndex => flow.indexOf(this);

  /// Pasos posteriores a los que se puede avanzar (requieren
  /// `services.orders.change_status`).
  List<ServiceOrderStatus> get stepsAhead {
    final index = flowIndex;

    return index < 0 ? const <ServiceOrderStatus>[] : flow.sublist(index + 1);
  }

  /// Pasos anteriores a los que se puede regresar (requieren
  /// `services.orders.edit` y confirmación explícita).
  List<ServiceOrderStatus> get stepsBehind {
    final index = flowIndex;

    return index <= 0
        ? const <ServiceOrderStatus>[]
        : flow.sublist(0, index).reversed.toList(growable: false);
  }

  /// Primer paso siguiente natural, si existe.
  ServiceOrderStatus? get nextStep {
    final steps = stepsAhead;

    return steps.isEmpty ? null : steps.first;
  }

  /// La orden sigue en el taller (se pueden capturar avances).
  bool get isOpen => !isCancelled && this != ServiceOrderStatus.delivered;
}
