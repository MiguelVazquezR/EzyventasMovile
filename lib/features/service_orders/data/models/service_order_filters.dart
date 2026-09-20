/// Orden del listado de órdenes (`sortField` / `sortOrder` del contrato §9).
///
/// El servidor solo acepta `received_at`, `promised_at`, `folio` y
/// `final_total`; cualquier otro valor se ignora.
enum ServiceOrderSort {
  recent(
    label: 'Más recientes',
    field: 'received_at',
    order: 'desc',
  ),
  oldest(
    label: 'Más antiguas',
    field: 'received_at',
    order: 'asc',
  ),
  promised(
    label: 'Promesa de entrega',
    field: 'promised_at',
    order: 'asc',
  ),
  folio(
    label: 'Folio',
    field: 'folio',
    order: 'asc',
  ),
  total(
    label: 'Total (mayor a menor)',
    field: 'final_total',
    order: 'desc',
  );

  const ServiceOrderSort({
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

/// Filtros del listado de órdenes (`GET /service-orders`).
///
/// Todo se resuelve en el servidor: la app no filtra ni ordena localmente.
class ServiceOrderFilters {
  const ServiceOrderFilters({
    this.search = '',
    this.status,
    this.sort = ServiceOrderSort.recent,
  });

  /// Folio, cliente o descripción del equipo.
  final String search;

  /// Estatus de la orden (`pendiente`, `en_progreso`, ...).
  final String? status;

  final ServiceOrderSort sort;

  /// Hay algún filtro aplicado (sin contar el orden).
  bool get hasFilters => search.isNotEmpty || status != null;

  /// Parámetros exactos del contrato (`search`, `status`, `sortField`,
  /// `sortOrder`); la paginación la agrega el repositorio.
  Map<String, dynamic> toQuery() => <String, dynamic>{
    'search': search.isEmpty ? null : search,
    'status': status,
    'sortField': sort.field,
    'sortOrder': sort.order,
  };

  ServiceOrderFilters copyWith({
    String? search,
    String? status,
    ServiceOrderSort? sort,
    bool clearStatus = false,
  }) {
    return ServiceOrderFilters(
      search: search ?? this.search,
      status: clearStatus ? null : (status ?? this.status),
      sort: sort ?? this.sort,
    );
  }
}
