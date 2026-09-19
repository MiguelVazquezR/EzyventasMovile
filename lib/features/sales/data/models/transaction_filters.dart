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
    this.status,
    this.dateStart,
    this.dateEnd,
    this.sort = TransactionSort.recent,
  });

  final String search;

  /// Estatus de la venta (`completado`, `pendiente`, `apartado`, ...).
  final String? status;

  /// Rango de fechas (día inicial y final, hora local del dispositivo).
  final DateTime? dateStart;
  final DateTime? dateEnd;

  final TransactionSort sort;

  /// Hay algún filtro aplicado (sin contar el orden).
  bool get hasFilters =>
      search.isNotEmpty || status != null || dateStart != null || dateEnd != null;

  /// Rango de fechas en formato `d MMM y`.
  String? get dateRangeLabel {
    if (dateStart == null && dateEnd == null) {
      return null;
    }

    return '${dateStart == null ? 'Inicio' : AppFormatters.date(dateStart)} → '
        '${dateEnd == null ? 'Hoy' : AppFormatters.date(dateEnd)}';
  }

  /// Parámetros exactos del contrato (`search`, `status`, `date_start`,
  /// `date_end`, `sortField`, `sortOrder`).
  Map<String, dynamic> toQuery() => <String, dynamic>{
    'search': search.isEmpty ? null : search,
    'status': status,
    'date_start': dateStart == null
        ? null
        : AppFormatters.apiDate(dateStart!),
    'date_end': dateEnd == null ? null : AppFormatters.apiDate(dateEnd!),
    'sortField': sort.field,
    'sortOrder': sort.order,
  };

  TransactionFilters copyWith({
    String? search,
    String? status,
    DateTime? dateStart,
    DateTime? dateEnd,
    TransactionSort? sort,
    bool clearStatus = false,
    bool clearDateStart = false,
    bool clearDateEnd = false,
  }) {
    return TransactionFilters(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      dateStart: clearDateStart ? null : (dateStart ?? this.dateStart),
      dateEnd: clearDateEnd ? null : (dateEnd ?? this.dateEnd),
      sort: sort ?? this.sort,
    );
  }
}
