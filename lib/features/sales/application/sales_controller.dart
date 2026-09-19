import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../cash/application/cash_register_controller.dart';
import '../../pos/data/models/payment_draft.dart';
import '../data/models/refund_method.dart';
import '../data/models/sales_mutation_results.dart';
import '../data/models/transaction_detail.dart';
import '../data/models/transaction_filters.dart';
import '../data/models/transaction_summary.dart';
import '../data/sales_repository.dart';

/// Repositorio del historial de ventas.
final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepository(api: ref.watch(apiClientProvider)),
);

/// Estado del historial: lista acumulada + filtros + paginación.
class TransactionsState {
  const TransactionsState({
    this.items = const <TransactionSummary>[],
    this.filters = const TransactionFilters(),
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final List<TransactionSummary> items;
  final TransactionFilters filters;
  final int page;
  final bool hasMore;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;

  /// `message` del servidor tal cual (nunca un texto inventado).
  final String? errorMessage;

  bool get isEmpty => items.isEmpty && !isLoading && errorMessage == null;

  TransactionsState copyWith({
    List<TransactionSummary>? items,
    TransactionFilters? filters,
    int? page,
    bool? hasMore,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransactionsState(
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

/// Historial de ventas de la sucursal.
///
/// El servidor filtra, ordena y pagina: aquí solo se acumulan las páginas que
/// el usuario va pidiendo.
class TransactionsController extends Notifier<TransactionsState> {
  static const int pageSize = 20;

  @override
  TransactionsState build() {
    Future<void>.microtask(loadFirstPage);

    return const TransactionsState(isLoading: true);
  }

  Future<void> loadFirstPage() => _load(page: 1, reset: true);

  Future<void> loadMore() {
    final current = state;
    if (current.isLoading || current.isLoadingMore || !current.hasMore) {
      return Future<void>.value();
    }

    return _load(page: current.page + 1);
  }

  /// Aplica la búsqueda (folio, cliente o contacto) y vuelve a la página 1.
  Future<void> setSearch(String search) {
    final trimmed = search.trim();
    if (trimmed == state.filters.search) {
      return Future<void>.value();
    }

    state = state.copyWith(filters: state.filters.copyWith(search: trimmed));

    return loadFirstPage();
  }

  /// Filtra por estatus (`null` = todos).
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

  /// Filtra por rango de fechas (`null` limpia ese extremo).
  Future<void> setDateRange({DateTime? start, DateTime? end}) {
    state = state.copyWith(
      filters: state.filters.copyWith(
        dateStart: start,
        dateEnd: end,
        clearDateStart: start == null,
        clearDateEnd: end == null,
      ),
    );

    return loadFirstPage();
  }

  Future<void> setSort(TransactionSort sort) {
    if (sort == state.filters.sort) {
      return Future<void>.value();
    }

    state = state.copyWith(filters: state.filters.copyWith(sort: sort));

    return loadFirstPage();
  }

  /// Quita búsqueda, estatus y fechas (conserva el orden elegido).
  Future<void> clearFilters() {
    if (!state.filters.hasFilters) {
      return Future<void>.value();
    }

    state = state.copyWith(
      filters: TransactionFilters(sort: state.filters.sort),
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
          .read(salesRepositoryProvider)
          .fetchTransactions(
            filters: state.filters,
            page: page,
            perPage: pageSize,
          );

      state = state.copyWith(
        items: reset
            ? result.items
            : <TransactionSummary>[...state.items, ...result.items],
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

final transactionsControllerProvider =
    NotifierProvider<TransactionsController, TransactionsState>(
      TransactionsController.new,
    );

/// Estado del detalle de una venta.
class TransactionDetailState {
  const TransactionDetailState({
    this.transactionId,
    this.detail,
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.notice,
    this.receipt,
  });

  /// Venta cargada (la hoja del detalle solo pinta cuando coincide con su id).
  final int? transactionId;
  final TransactionDetail? detail;
  final bool isLoading;

  /// Abono, cancelación, reembolso o edición de pago en curso.
  final bool isSubmitting;

  /// `message` del servidor (error).
  final String? errorMessage;

  /// `message` del servidor de la última operación exitosa.
  final String? notice;

  /// Ticket de WhatsApp que devolvió el abono (`print.payload`).
  final AbonoReceipt? receipt;

  bool belongsTo(int id) => transactionId == id;

  bool get hasDetail => detail != null;

  TransactionDetailState copyWith({
    int? transactionId,
    TransactionDetail? detail,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? notice,
    AbonoReceipt? receipt,
    bool clearError = false,
    bool clearNotice = false,
    bool clearReceipt = false,
    bool clearDetail = false,
  }) {
    return TransactionDetailState(
      transactionId: transactionId ?? this.transactionId,
      detail: clearDetail ? null : (detail ?? this.detail),
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      receipt: clearReceipt ? null : (receipt ?? this.receipt),
    );
  }
}

/// Detalle de una venta y sus acciones (abono, cancelación/reembolso y edición
/// de pagos).
///
/// Solo hay una hoja de detalle abierta a la vez, así que el estado guarda el id
/// de la venta cargada y la UI comprueba que coincide antes de pintar. Después
/// de cada operación se refresca el historial para que la lista muestre el
/// estatus y el saldo definitivos que calculó el servidor.
class TransactionDetailController extends Notifier<TransactionDetailState> {
  static const String paymentDeletedMessage = 'Pago eliminado correctamente.';

  @override
  TransactionDetailState build() => const TransactionDetailState();

  /// `GET /transactions/{id}`.
  Future<void> load(int transactionId) async {
    final keepDetail = state.belongsTo(transactionId) && state.hasDetail;

    state = state.copyWith(
      transactionId: transactionId,
      isLoading: !keepDetail,
      clearError: true,
      clearNotice: true,
      clearReceipt: true,
      clearDetail: !keepDetail,
    );

    try {
      final detail = await ref
          .read(salesRepositoryProvider)
          .fetchTransaction(transactionId);

      state = state.copyWith(detail: detail, isLoading: false, clearError: true);
    } on ApiException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    }
  }

  /// Vuelve a leer la venta abierta.
  Future<void> refresh() async {
    final id = state.transactionId;
    if (id == null) {
      return Future<void>.value();
    }

    return load(id);
  }

  /// `POST /transactions/{id}/payments`.
  Future<AbonoResult?> addPayment({
    required int sessionId,
    bool useBalance = false,
    List<PaymentDraft> payments = const <PaymentDraft>[],
  }) async {
    final id = state.transactionId;
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
          .read(salesRepositoryProvider)
          .addPayment(
            transactionId: id,
            sessionId: sessionId,
            useBalance: useBalance,
            payments: payments,
          );

      state = state.copyWith(
        isSubmitting: false,
        detail: result.transaction,
        receipt: result.receipt,
        notice: result.receipt == null
            ? 'Abono registrado. Folio: ${result.transaction.folio}'
            : null,
        clearNotice: result.receipt != null,
      );

      await _refreshHistory();

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

  /// `POST /transactions/{id}/cancel` con `action = penalty`.
  Future<TransactionMutationResult?> cancelWithPenalty() async {
    final id = state.transactionId;
    if (id == null) {
      return null;
    }

    return _mutate(
      () => ref.read(salesRepositoryProvider).cancelWithPenalty(id),
    );
  }

  /// `POST /transactions/{id}/refund`.
  Future<TransactionMutationResult?> refund({
    required RefundMethod method,
    int? bankAccountId,
  }) async {
    final id = state.transactionId;
    if (id == null) {
      return null;
    }

    return _mutate(
      () => ref
          .read(salesRepositoryProvider)
          .refund(
            transactionId: id,
            method: method,
            bankAccountId: bankAccountId,
          ),
    );
  }

  /// `PUT /transactions/{id}/payments/{paymentId}`.
  Future<bool> updatePayment({
    required int paymentId,
    required double amount,
    required String paymentMethod,
    int? bankAccountId,
    String? notes,
  }) async {
    final id = state.transactionId;
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
          .read(salesRepositoryProvider)
          .updatePayment(
            transactionId: id,
            paymentId: paymentId,
            amount: amount,
            paymentMethod: paymentMethod,
            bankAccountId: bankAccountId,
            notes: notes,
          );

      state = state.copyWith(
        isSubmitting: false,
        detail: result.transaction,
        notice: result.message.isEmpty
            ? 'Pago actualizado correctamente.'
            : result.message,
      );

      await _refreshHistory();

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  /// `DELETE /transactions/{id}/payments/{paymentId}` (`204` sin cuerpo).
  Future<bool> deletePayment(int paymentId) async {
    final id = state.transactionId;
    if (id == null) {
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      await ref
          .read(salesRepositoryProvider)
          .deletePayment(transactionId: id, paymentId: paymentId);

      state = state.copyWith(isSubmitting: false, notice: paymentDeletedMessage);

      // El servidor responde 204: se vuelve a leer la venta para mostrar el
      // saldo y los pagos definitivos que quedaron en la base de datos.
      await refresh();
      await _refreshHistory();

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

  void consumeReceipt() {
    if (state.receipt != null) {
      state = state.copyWith(clearReceipt: true);
    }
  }

  /// Descarta el detalle (al cerrar la hoja).
  void clear() {
    state = const TransactionDetailState();
  }

  Future<TransactionMutationResult?> _mutate(
    Future<TransactionMutationResult> Function() request,
  ) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await request();

      state = state.copyWith(
        isSubmitting: false,
        detail: result.transaction,
        notice: result.message.isEmpty ? null : result.message,
        clearNotice: result.message.isEmpty,
      );

      await _refreshHistory();

      return result;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return null;
    }
  }

  /// El historial muestra estatus y saldos: se refresca tras cada operación.
  Future<void> _refreshHistory() =>
      ref.read(transactionsControllerProvider.notifier).refresh();

  /// El turno pudo cerrarse desde otro dispositivo: se sincroniza para que el
  /// botón de abonar refleje la realidad.
  Future<void> _syncCashSessionWhenNeeded(ApiException error) async {
    if (error.code != 'session_required') {
      return;
    }

    await ref.read(cashRegisterControllerProvider.notifier).refresh();
  }
}

final transactionDetailControllerProvider =
    NotifierProvider<TransactionDetailController, TransactionDetailState>(
      TransactionDetailController.new,
    );
