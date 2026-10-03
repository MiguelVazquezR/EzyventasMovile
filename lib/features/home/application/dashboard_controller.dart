import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../data/dashboard_repository.dart';
import '../data/models/expiring_layaway.dart';
import '../data/models/mobile_dashboard.dart';
import '../data/models/upcoming_delivery.dart';

/// Repositorio del inicio (los 3 endpoints de §3b).
final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(api: ref.watch(apiClientProvider)),
);

/// Estado del inicio: sin datos, cargando, con datos o con error.
class DashboardState {
  const DashboardState({
    this.dashboard,
    this.isLoading = false,
    this.errorMessage,
  });

  final MobileDashboard? dashboard;
  final bool isLoading;

  /// `message` del servidor (o el error de contrato), nunca uno inventado.
  final String? errorMessage;

  bool get hasData => dashboard != null;

  /// Primera carga sin nada que mostrar todavía.
  bool get isFirstLoad => isLoading && !hasData;

  DashboardState copyWith({
    MobileDashboard? dashboard,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DashboardState(
      dashboard: dashboard ?? this.dashboard,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controlador del inicio.
///
/// Se pide al entrar a la pantalla (no hay caché en esta fase) y con
/// pull-to-refresh. Si ya había datos y la recarga falla, los datos anteriores
/// se conservan y el aviso se pinta encima.
class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    Future<void>.microtask(refresh);

    return const DashboardState(isLoading: true);
  }

  /// `GET /dashboard` — también es el `onRefresh` del pull-to-refresh.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final dashboard = await ref
          .read(dashboardRepositoryProvider)
          .fetchDashboard();

      state = DashboardState(dashboard: dashboard);
    } on ApiException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    } on DashboardContractError catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    }
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(
      DashboardController.new,
    );

/// Estado del listado de apartados y créditos por vencer.
class ExpiringLayawaysState {
  const ExpiringLayawaysState({
    this.days = dashboardDefaultDays,
    this.items = const <ExpiringLayaway>[],
    this.isLoading = false,
    this.errorMessage,
  });

  /// Ventana aplicada (1-30); el título la reusa («Próximos 3 días»).
  final int days;

  final List<ExpiringLayaway> items;
  final bool isLoading;
  final String? errorMessage;

  bool get isEmpty => !isLoading && errorMessage == null && items.isEmpty;

  ExpiringLayawaysState copyWith({
    int? days,
    List<ExpiringLayaway>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExpiringLayawaysState(
      days: days ?? this.days,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controlador del listado `GET /dashboard/expiring-layaways`.
///
/// Los días restantes y el vencimiento llegan calculados por el servidor: el
/// cliente solo pinta. El `403` sin permiso se muestra con el mensaje del
/// servidor (la tarjeta del inicio no se dibuja en ese caso).
class ExpiringLayawaysController extends Notifier<ExpiringLayawaysState> {
  @override
  ExpiringLayawaysState build() {
    Future<void>.microtask(refresh);

    return const ExpiringLayawaysState(isLoading: true);
  }

  Future<void> refresh() => _load(days: state.days);

  /// Cambia la ventana (`1-30`) y vuelve a pedir el listado.
  Future<void> setDays(int days) async {
    if (days < dashboardMinDays || days > dashboardMaxDays) {
      return;
    }

    state = state.copyWith(days: days);
    await _load(days: days);
  }

  Future<void> _load({required int days}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await ref
          .read(dashboardRepositoryProvider)
          .fetchExpiringLayaways(days: days);

      state = ExpiringLayawaysState(
        // `days` del payload es la ventana realmente aplicada.
        days: result.days == 0 ? days : result.days,
        items: result.items,
      );
    } on ApiException catch (error) {
      // `422` con `days` inválido: se muestra el mensaje del servidor y el
      // filtro vuelve a la ventana por defecto (§3b.3).
      state = ExpiringLayawaysState(
        days: error.isValidation ? dashboardDefaultDays : days,
        items: state.items,
        errorMessage: error.message,
      );
    } on DashboardContractError catch (error) {
      state = ExpiringLayawaysState(
        days: days,
        items: state.items,
        errorMessage: error.message,
      );
    }
  }
}

final expiringLayawaysControllerProvider =
    NotifierProvider<ExpiringLayawaysController, ExpiringLayawaysState>(
      ExpiringLayawaysController.new,
    );

/// Estado del listado de pedidos por entregar.
class UpcomingDeliveriesState {
  const UpcomingDeliveriesState({
    this.days = dashboardDefaultDays,
    this.items = const <UpcomingDelivery>[],
    this.isLoading = false,
    this.errorMessage,
  });

  /// Ventana aplicada (1-30).
  final int days;

  final List<UpcomingDelivery> items;
  final bool isLoading;
  final String? errorMessage;

  bool get isEmpty => !isLoading && errorMessage == null && items.isEmpty;

  UpcomingDeliveriesState copyWith({
    int? days,
    List<UpcomingDelivery>? items,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UpcomingDeliveriesState(
      days: days ?? this.days,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Controlador del listado `GET /dashboard/upcoming-deliveries`.
///
/// `days_remaining`, `is_today` e `is_overdue` vienen del servidor (zona horaria
/// del negocio) y `delivery_date` es un día en medianoche UTC: la app **no**
/// recalcula ni convierte nada.
class UpcomingDeliveriesController extends Notifier<UpcomingDeliveriesState> {
  @override
  UpcomingDeliveriesState build() {
    Future<void>.microtask(refresh);

    return const UpcomingDeliveriesState(isLoading: true);
  }

  Future<void> refresh() => _load(days: state.days);

  /// Cambia la ventana (`1-30`) y vuelve a pedir el listado.
  Future<void> setDays(int days) async {
    if (days < dashboardMinDays || days > dashboardMaxDays) {
      return;
    }

    state = state.copyWith(days: days);
    await _load(days: days);
  }

  Future<void> _load({required int days}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final result = await ref
          .read(dashboardRepositoryProvider)
          .fetchUpcomingDeliveries(days: days);

      state = UpcomingDeliveriesState(
        days: result.days == 0 ? days : result.days,
        items: result.items,
      );
    } on ApiException catch (error) {
      // `422` con `days` inválido: mensaje del servidor y ventana por defecto.
      state = UpcomingDeliveriesState(
        days: error.isValidation ? dashboardDefaultDays : days,
        items: state.items,
        errorMessage: error.message,
      );
    } on DashboardContractError catch (error) {
      state = UpcomingDeliveriesState(
        days: days,
        items: state.items,
        errorMessage: error.message,
      );
    }
  }
}

final upcomingDeliveriesControllerProvider =
    NotifierProvider<UpcomingDeliveriesController, UpcomingDeliveriesState>(
      UpcomingDeliveriesController.new,
    );
