import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/status_catalog.dart';
import '../../data/models/service_order_detail.dart';

/// Etiquetas del módulo de órdenes de servicio (español, sentence case).
class ServiceOrderLabels {
  const ServiceOrderLabels._();

  /// Estatus de los chips del listado, en orden de flujo y con `cancelado` al
  /// final (el servidor valida el mismo conjunto).
  static const List<String> statusFilters = <String>[
    'pendiente',
    'en_progreso',
    'esperando_refaccion',
    'terminado',
    'entregado',
    'cancelado',
  ];

  /// Confirmación del borrado (acción irreversible, el servidor responde 204).
  static const String deleteWarning =
      'Esta acción no se puede deshacer: se eliminará la orden y su venta '
      'vinculada.';

  /// Aviso al regresar el estatus (§8.2 del documento maestro).
  static const String revertWarning =
      '¿Seguro que quieres regresar la orden a esta etapa? Esto podría anular '
      'el progreso de las etapas posteriores.';

  static String status(String status) => StatusCatalog.serviceOrderLabel(status);

  /// `Mano de obra` / `Refacción` / `Concepto`.
  static String itemType(String? itemableType) =>
      ServiceOrderItemType.labelOf(itemableType);

  /// `Porcentaje 20 %` / `Monto fijo $150.00`.
  static String commission({
    required String? type,
    required double value,
  }) {
    if (type == 'fixed') {
      return 'Monto fijo ${Money.format(value)}';
    }

    return 'Porcentaje ${Money.formatQuantity(value)} %';
  }

  /// `4 fotos` / `1 foto`.
  static String photos(int count) => count == 1 ? '1 foto' : '$count fotos';

  /// Aviso cuando la cámara o la galería no devolvieron la foto.
  static const String photoFailed =
      'No pudimos obtener la foto. Revisa los permisos de cámara y galería.';

  /// Aviso de fotos descartadas por exceder el peso que acepta el servidor.
  static String photosSkipped(int count) =>
      'Se descartaron $count foto${count == 1 ? '' : 's'} por exceder 2 MB.';

  /// `2 conceptos` / `1 concepto`.
  static String items(int count) =>
      count == 1 ? '1 concepto' : '$count conceptos';

  /// `Recibida 15 sep 2026` — nunca se esconde la fecha de recepción.
  static String received(Object? value) =>
      'Recibida ${AppFormatters.date(value)}';

  /// Texto de la promesa de entrega con los días restantes.
  static String promised(Object? promisedAt, int? daysLeft) {
    final date = AppFormatters.date(promisedAt);

    if (daysLeft == null) {
      return 'Entrega $date';
    }

    if (daysLeft < 0) {
      return 'Entrega vencida ($date)';
    }

    if (daysLeft == 0) {
      return 'Entrega hoy ($date)';
    }

    return 'Entrega en $daysLeft día${daysLeft == 1 ? '' : 's'} ($date)';
  }
}
