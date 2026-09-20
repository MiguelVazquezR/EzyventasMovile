import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/utils/evidence_image.dart';
import '../../cash/application/cash_register_controller.dart';
import '../../pos/data/models/payment_draft.dart';
import '../../sales/data/models/sales_mutation_results.dart';
import '../data/models/service_order_detail.dart';
import '../data/models/service_order_filters.dart';
import '../data/models/service_order_form.dart';
import '../data/models/service_order_mutation_results.dart';
import '../data/models/service_order_summary.dart';
import '../data/service_orders_repository.dart';

/// Repositorio de órdenes de servicio.
final serviceOrdersRepositoryProvider = Provider<ServiceOrdersRepository>(
  (ref) => ServiceOrdersRepository(api: ref.watch(apiClientProvider)),
);

/// Estado del listado: páginas acumuladas + filtros + paginación.
class ServiceOrdersState {
  const ServiceOrdersState({
    this.items = const <ServiceOrderSummary>[],
    this.filters = const ServiceOrderFilters(),
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final List<ServiceOrderSummary> items;
  final ServiceOrderFilters filters;
  final int page;
  final bool hasMore;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;

  /// `message` del servidor tal cual (nunca un texto inventado).
  final String? errorMessage;

  bool get isEmpty => items.isEmpty && !isLoading && errorMessage == null;

  ServiceOrdersState copyWith({
    List<ServiceOrderSummary>? items,
    ServiceOrderFilters? filters,
    int? page,
    bool? hasMore,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ServiceOrdersState(
      items: items ?? this.items,
      filters: filters ?? this.filters,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Lista de trabajo de órdenes de servicio.
///
/// El servidor filtra, ordena y pagina; aquí solo se acumulan las páginas que
/// el usuario va pidiendo y se refresca tras cada operación de escritura.
class ServiceOrdersController extends Notifier<ServiceOrdersState> {
  static const int pageSize = 20;

  @override
  ServiceOrdersState build() {
    Future<void>.microtask(loadFirstPage);

    return const ServiceOrdersState(isLoading: true);
  }

  Future<void> loadFirstPage() => _load(page: 1, reset: true);

  Future<void> loadMore() {
    final current = state;

    if (current.isLoading || current.isLoadingMore || !current.hasMore) {
      return Future<void>.value();
    }

    return _load(page: current.page + 1);
  }

  /// Búsqueda por folio, cliente o equipo.
  Future<void> setSearch(String search) {
    final trimmed = search.trim();

    if (trimmed == state.filters.search) {
      return Future<void>.value();
    }

    state = state.copyWith(filters: state.filters.copyWith(search: trimmed));

    return loadFirstPage();
  }

  /// Filtro por estatus (`null` = todos).
  Future<void> setStatus(String? status) {
    if (status == state.filters.status) {
      return Future<void>.value();
    }

    state = state.copyWith(
      filters: status == null
          ? state.filters.copyWith(clearStatus: true)
          : state.filters.copyWith(status: status),
    );

    return loadFirstPage();
  }

  Future<void> setSort(ServiceOrderSort sort) {
    if (sort == state.filters.sort) {
      return Future<void>.value();
    }

    state = state.copyWith(filters: state.filters.copyWith(sort: sort));

    return loadFirstPage();
  }

  Future<void> clearFilters() {
    if (!state.filters.hasFilters) {
      return Future<void>.value();
    }

    state = state.copyWith(
      filters: ServiceOrderFilters(sort: state.filters.sort),
    );

    return loadFirstPage();
  }

  Future<void> refresh() => loadFirstPage();

  Future<void> _load({required int page, bool reset = false}) async {
    state = reset
        ? state.copyWith(isLoading: true, clearError: true)
        : state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final result = await ref
          .read(serviceOrdersRepositoryProvider)
          .fetchServiceOrders(
            filters: state.filters,
            page: page,
            perPage: pageSize,
          );

      state = state.copyWith(
        items: reset
            ? result.items
            : <ServiceOrderSummary>[...state.items, ...result.items],
        page: result.currentPage,
        hasMore: result.hasMore,
        total: result.total,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: error.message,
      );
    }
  }
}

final serviceOrdersControllerProvider =
    NotifierProvider<ServiceOrdersController, ServiceOrdersState>(
      ServiceOrdersController.new,
    );

/// Detalle de una orden (`GET /service-orders/{id}`) para precargar el
/// formulario de edición.
final serviceOrderDetailProvider = FutureProvider.family<ServiceOrderDetail, int>(
  (ref, id) => ref.watch(serviceOrdersRepositoryProvider).fetchServiceOrder(id),
);

/// Estado del detalle y de sus acciones.
class ServiceOrderDetailState {
  const ServiceOrderDetailState({
    this.serviceOrderId,
    this.detail,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.notice,
    this.receipt,
    this.statusMessage,
  });

  /// Orden cargada (la hoja del detalle solo pinta cuando coincide con su id).
  final int? serviceOrderId;
  final ServiceOrderDetail? detail;
  final bool isLoading;

  /// Cambio de estatus, diagnóstico, anticipo o borrado en curso.
  final bool isSubmitting;

  /// `message` del servidor de la última operación fallida.
  final String? errorMessage;

  /// `message` del servidor de la última operación exitosa.
  final String? notice;

  /// Texto de `errors.status[0]` del `422` del cambio de estatus.
  final String? statusMessage;

  /// Ticket de abono que devolvió el anticipo (`print.payload`).
  final AbonoReceipt? receipt;

  bool belongsTo(int id) => serviceOrderId == id;

  bool get hasDetail => detail != null;

  ServiceOrderDetailState copyWith({
    int? serviceOrderId,
    ServiceOrderDetail? detail,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? notice,
    String? statusMessage,
    AbonoReceipt? receipt,
    bool clearError = false,
    bool clearNotice = false,
    bool clearStatusMessage = false,
    bool clearReceipt = false,
    bool clearDetail = false,
  }) {
    return ServiceOrderDetailState(
      serviceOrderId: serviceOrderId ?? this.serviceOrderId,
      detail: clearDetail ? null : (detail ?? this.detail),
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      receipt: clearReceipt ? null : (receipt ?? this.receipt),
    );
  }
}

/// Detalle de una orden con sus acciones: estatus, diagnóstico, anticipos,
/// `ensure-transaction` y borrado.
///
/// Solo hay una hoja de detalle abierta a la vez, así que el estado guarda el id
/// cargado y la UI comprueba que coincide. Después de cada operación se refresca
/// el listado para que la tarjeta muestre el estatus y el saldo definitivos.
class ServiceOrderDetailController extends Notifier<ServiceOrderDetailState> {
  @override
  ServiceOrderDetailState build() => const ServiceOrderDetailState();

  /// `GET /service-orders/{id}`.
  Future<void> load(int serviceOrderId) async {
    final keepDetail = state.belongsTo(serviceOrderId) && state.hasDetail;

    state = state.copyWith(
      serviceOrderId: serviceOrderId,
      isLoading: !keepDetail,
      clearError: true,
      clearNotice: true,
      clearStatusMessage: true,
      clearReceipt: true,
      clearDetail: !keepDetail,
    );

    try {
      final detail = await ref
          .read(serviceOrdersRepositoryProvider)
          .fetchServiceOrder(serviceOrderId);

      state = state.copyWith(detail: detail, isLoading: false, clearError: true);
    } on ApiException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    }
  }

  Future<void> refresh() async {
    final id = state.serviceOrderId;

    if (id == null) {
      return Future<void>.value();
    }

    return load(id);
  }

  /// `PATCH /service-orders/{id}/status`.
  ///
  /// El `422` de un estatus repetido o inválido trae el motivo real en
  /// `errors.status[0]`: se guarda en [ServiceOrderDetailState.statusMessage].
  Future<bool> changeStatus(String status) async {
    final id = state.serviceOrderId;
    if (id == null) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
      clearStatusMessage: true,
    );

    try {
      final result = await ref
          .read(serviceOrdersRepositoryProvider)
          .updateStatus(serviceOrderId: id, status: status);

      state = state.copyWith(
        isSubmitting: false,
        notice: result.message,
      );

      await refresh();
      await _refreshList();

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        statusMessage: error.errorFor('status') ?? error.message,
        errorMessage: error.errorFor('status') == null ? error.message : null,
        clearError: error.errorFor('status') != null,
      );

      return false;
    }
  }

  /// `POST /service-orders/{id}/diagnosis` (multipart, hasta 5 fotos).
  ///
  /// Con `diagnosis: null` el diagnóstico previo se conserva; con `''` se
  /// borra (comportamiento exacto del contrato §9).
  Future<bool> saveDiagnosis({
    required String? diagnosis,
    List<EvidenceImage> images = const <EvidenceImage>[],
  }) async {
    final id = state.serviceOrderId;
    if (id == null) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await ref
          .read(serviceOrdersRepositoryProvider)
          .saveDiagnosis(
            serviceOrderId: id,
            diagnosis: diagnosis,
            images: images,
          );

      state = state.copyWith(
        isSubmitting: false,
        detail: result.detail,
        notice: result.message,
      );

      await _refreshList();

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  /// `POST /service-orders/{id}/payments` — anticipo (efectivo, tarjeta,
  /// transferencia o saldo a favor del cliente).
  Future<ServiceOrderPaymentResult?> addPayment({
    required int sessionId,
    bool useBalance = false,
    List<PaymentDraft> payments = const <PaymentDraft>[],
  }) async {
    final id = state.serviceOrderId;
    if (id == null) {
      return null;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
      clearReceipt: true,
    );

    try {
      final result = await ref
          .read(serviceOrdersRepositoryProvider)
          .addPayment(
            serviceOrderId: id,
            sessionId: sessionId,
            useBalance: useBalance,
            payments: payments,
          );

      state = state.copyWith(
        isSubmitting: false,
        detail: result.detail,
        receipt: result.receipt,
      );

      await _refreshList();

      return result;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
        clearReceipt: true,
      );

      await _syncCashSessionWhenNeeded(error);

      return null;
    }
  }

  /// `POST /service-orders/{id}/ensure-transaction`.
  ///
  /// Crea la venta vinculada de una orden antigua antes de cobrar. Devuelve
  /// `true` cuando la orden ya tiene venta (recién creada o existente).
  Future<bool> ensureTransaction() async {
    final id = state.serviceOrderId;
    if (id == null) {
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      await ref
          .read(serviceOrdersRepositoryProvider)
          .ensureTransaction(id);

      state = state.copyWith(isSubmitting: false);

      await refresh();

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  /// `DELETE /service-orders/{id}` (204). El servidor elimina también la venta
  /// vinculada, por eso la UI pide confirmación explícita.
  Future<bool> deleteOrder() async {
    final id = state.serviceOrderId;
    if (id == null) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      await ref.read(serviceOrdersRepositoryProvider).deleteServiceOrder(id);

      state = state.copyWith(isSubmitting: false);

      await _refreshList();

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  void consumeNotice() {
    if (state.notice != null) {
      state = state.copyWith(clearNotice: true);
    }
  }

  void consumeError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void consumeStatusMessage() {
    if (state.statusMessage != null) {
      state = state.copyWith(clearStatusMessage: true);
    }
  }

  void consumeReceipt() {
    if (state.receipt != null) {
      state = state.copyWith(clearReceipt: true);
    }
  }

  /// Descarta el detalle (al cerrar la hoja).
  void clear() {
    state = const ServiceOrderDetailState();
  }

  /// El listado muestra estatus y saldos: se refresca tras cada operación.
  Future<void> _refreshList() =>
      ref.read(serviceOrdersControllerProvider.notifier).refresh();

  /// El turno pudo cerrarse desde otro dispositivo (`session_required`).
  Future<void> _syncCashSessionWhenNeeded(ApiException error) async {
    if (error.code != 'session_required') {
      return;
    }

    await ref.read(cashRegisterControllerProvider.notifier).refresh();
  }
}

final serviceOrderDetailControllerProvider =
    NotifierProvider<ServiceOrderDetailController, ServiceOrderDetailState>(
      ServiceOrderDetailController.new,
    );

/// Estado del formulario de alta/edición.
class ServiceOrderFormState {
  const ServiceOrderFormState({
    this.isSubmitting = false,
    this.errorMessage,
    this.notice,
    this.savedDetail,
  });

  final bool isSubmitting;

  /// `message` (o `errors.campo[0]`) del servidor.
  final String? errorMessage;

  /// `message` del servidor cuando la orden se guardó.
  final String? notice;

  /// Orden guardada: el formulario la usa para cerrarse y avisar.
  final ServiceOrderDetail? savedDetail;

  ServiceOrderFormState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    String? notice,
    ServiceOrderDetail? savedDetail,
    bool clearError = false,
    bool clearNotice = false,
    bool clearSaved = false,
  }) {
    return ServiceOrderFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      savedDetail: clearSaved ? null : (savedDetail ?? this.savedDetail),
    );
  }
}

/// Guarda una orden (alta o edición) con el payload del contrato.
///
/// La sesión de caja la exige el servidor (`cash_register_session_id`): si no
/// hay turno abierto, la pantalla lleva al flujo de apertura en lugar de enviar.
class ServiceOrderFormController extends Notifier<ServiceOrderFormState> {
  @override
  ServiceOrderFormState build() => const ServiceOrderFormState();

  /// `POST /service-orders` (alta) o `PUT /service-orders/{id}` (edición).
  Future<ServiceOrderDetail?> submit({
    required ServiceOrderFormData form,
    required int sessionId,
    int? serviceOrderId,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
      clearSaved: true,
    );

    try {
      final repository = ref.read(serviceOrdersRepositoryProvider);
      final result = serviceOrderId == null
          ? await repository.createServiceOrder(
              form: form,
              sessionId: sessionId,
            )
          : await repository.updateServiceOrder(
              serviceOrderId: serviceOrderId,
              form: form,
            );

      state = state.copyWith(
        isSubmitting: false,
        notice: result.message,
        savedDetail: result.detail,
      );

      await ref.read(serviceOrdersControllerProvider.notifier).refresh();

      return result.detail;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _firstFieldError(error),
      );

      await _syncCashSessionWhenNeeded(error);

      return null;
    }
  }

  /// Diagnóstico y/o evidencias de cierre de una orden existente.
  Future<bool> saveDiagnosis({
    required int serviceOrderId,
    String? diagnosis,
    List<EvidenceImage> images = const <EvidenceImage>[],
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await ref
          .read(serviceOrdersRepositoryProvider)
          .saveDiagnosis(
            serviceOrderId: serviceOrderId,
            diagnosis: diagnosis,
            images: images,
          );

      state = state.copyWith(
        isSubmitting: false,
        notice: result.message,
        savedDetail: result.detail,
      );

      await ref.read(serviceOrdersControllerProvider.notifier).refresh();

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _firstFieldError(error),
      );

      return false;
    }
  }

  void consumeError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void consumeNotice() {
    if (state.notice != null) {
      state = state.copyWith(clearNotice: true);
    }
  }

  void clear() {
    state = const ServiceOrderFormState();
  }

  /// Primer error de validación del servidor (o su `message`).
  static String _firstFieldError(ApiException error) {
    for (final messages in error.errors.values) {
      if (messages.isNotEmpty) {
        return messages.first;
      }
    }

    return error.message;
  }

  Future<void> _syncCashSessionWhenNeeded(ApiException error) async {
    if (error.code != 'session_required') {
      return;
    }

    await ref.read(cashRegisterControllerProvider.notifier).refresh();
  }
}

final serviceOrderFormControllerProvider =
    NotifierProvider<ServiceOrderFormController, ServiceOrderFormState>(
      ServiceOrderFormController.new,
    );

