import '../../../../core/utils/app_formatters.dart';

/// Orden del historial de ventas.
///
/// `sortField` acepta `created_at`, `folio`, `total` y `customer.name`
/// (contrato §8); el servidor ignora cualquier otro valor.
enum TransactionSort {
  recent(
    label: 'Más recientes',
    field: 'created_at',
    order: 'desc',
  ),
  oldest(
    label: 'Más antiguas',
    field: 'created_at',
    order: 'asc',
  ),
  folio(
    label: 'Folio',
    field: 'folio',
    order: 'asc',
  ),
  customer(
    label: 'Cliente',
    field: 'customer.name',
    order: 'asc',
  ),
  total(
    label: 'Total (mayor a menor)',
    field: 'total',
    order: 'desc',
  );

  const TransactionSort({
    required this.label,
    required this.field,
    required this.order,
  });

  /// Texto de UI (sentence case).
  final String label;

  /// Valor de `sortField`.
  final String field;

  /// Valor de `sortOrder`.
  final String order;
}

/// Filtros del historial (`GET /transactions`).
///
/// Todo se arma aquí y viaja al servidor: la app **no** filtra ni ordena
/// localmente (el servidor pagina el resultado ya filtrado).
class TransactionFilters {
  const TransactionFilters({
    this.search = '',
    this.statuses = const <String>[],
    this.dateStart,
    this.dateEnd,
    this.sort = TransactionSort.recent,
  });

  final String search;

  /// Estatus de la venta (`completado`, `pendiente`, `apartado`, ...).
  ///
  /// El servidor acepta **varios a la vez** desde el 2026-09-20 (§8), que es lo
  /// que necesita «Deudas por vencer» (apartados + créditos pendientes). Con un
  /// solo elemento el comportamiento es el de antes.
  final List<String> statuses;

  /// Rango de fechas (día inicial y final, hora local del dispositivo).
  final DateTime? dateStart;
  final DateTime? dateEnd;

  final TransactionSort sort;

  /// Hay algún filtro aplicado (sin contar el orden).
  bool get hasFilters =>
      search.isNotEmpty ||
      statuses.isNotEmpty ||
      dateStart != null ||
      dateEnd != null;

  /// Rango de fechas en formato `d MMM y`.
  String? get dateRangeLabel {
    if (dateStart == null && dateEnd == null) {
      return null;
    }

    return '${dateStart == null ? 'Inicio' : AppFormatters.date(dateStart)} → '
        '${dateEnd == null ? 'Hoy' : AppFormatters.date(dateEnd)}';
  }

  /// Parámetros exactos del contrato (`search`, `status[]`, `date_start`,
  /// `date_end`, `sortField`, `sortOrder`).
  ///
  /// La clave lleva los corchetes a propósito: Dio serializa una lista pelada
  /// repitiendo la clave (`status=a&status=b`) y **PHP se queda con la última**,
  /// mientras que `status[]=a&status[]=b` sí llega como arreglo (contrato §8).
  Map<String, dynamic> toQuery() => <String, dynamic>{
    'search': search.isEmpty ? null : search,
    if (statuses.isNotEmpty) 'status[]': statuses,
    'date_start': dateStart == null
        ? null
        : AppFormatters.apiDate(dateStart!),
    'date_end': dateEnd == null ? null : AppFormatters.apiDate(dateEnd!),
    'sortField': sort.field,
    'sortOrder': sort.order,
  };

  TransactionFilters copyWith({
    String? search,
    List<String>? statuses,
    DateTime? dateStart,
    DateTime? dateEnd,
    TransactionSort? sort,
    bool clearStatus = false,
    bool clearDateStart = false,
    bool clearDateEnd = false,
  }) {
    return TransactionFilters(
      search: search ?? this.search,
      statuses: clearStatus ? const <String>[] : (statuses ?? this.statuses),
      dateStart: clearDateStart ? null : (dateStart ?? this.dateStart),
      dateEnd: clearDateEnd ? null : (dateEnd ?? this.dateEnd),
      sort: sort ?? this.sort,
    );
  }
}
