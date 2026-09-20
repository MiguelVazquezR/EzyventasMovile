import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/storage/local_cache.dart';
import '../data/account_repository.dart';
import '../data/models/notification_counters.dart';
import '../data/models/support_content.dart';

/// Repositorio de la cuenta (sucursal, notificaciones, soporte, perfil y
/// suscripción).
final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(api: ref.watch(apiClientProvider)),
);

/// Estado de los contadores de la campana.
class NotificationsState {
  const NotificationsState({
    this.counters = const NotificationCounters.empty(),
    this.isLoading = false,
    this.errorMessage,
    this.hasCachedValue = false,
  });

  final NotificationCounters counters;
  final bool isLoading;

  /// `message` del servidor cuando la consulta falla.
  final String? errorMessage;

  /// `true` si lo que se muestra viene de la caché local (§9b.5).
  final bool hasCachedValue;

  /// Hay algún aviso que mostrar en la campana.
  bool get hasItems => counters.total > 0;

  /// Cuántos avisos hay en una categoría.
  int countFor(NotificationCategory category) =>
      counters.countFor(category);

  NotificationsState copyWith({
    NotificationCounters? counters,
    bool? isLoading,
    String? errorMessage,
    bool? hasCachedValue,
    bool clearError = false,
  }) {
    return NotificationsState(
      counters: counters ?? this.counters,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasCachedValue: hasCachedValue ?? this.hasCachedValue,
    );
  }
}

/// Contadores de notificaciones (`GET /notifications`).
///
/// Sin conexión conserva el último valor cacheado y lo marca
/// (`hasCachedValue`); si nunca se ha cargado, la campana no muestra badge
/// (§9b.5).
class NotificationsController extends Notifier<NotificationsState> {
  @override
  NotificationsState build() {
    Future<void>.microtask(refresh);

    return const NotificationsState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final counters = await ref
          .read(accountRepositoryProvider)
          .fetchNotifications();

      state = state.copyWith(
        counters: counters,
        isLoading: false,
        hasCachedValue: false,
        clearError: true,
      );

      await ref.read(localCacheProvider).saveNotifications(counters.toJson());
    } on ApiException catch (error) {
      final cached = await ref.read(localCacheProvider).readNotifications();

      state = state.copyWith(
        counters: cached == null
            ? state.counters
            : NotificationCounters.fromJson(cached),
        isLoading: false,
        hasCachedValue: cached != null,
        errorMessage: error.message,
      );
    }
  }

  /// Limpia la caché (al cerrar sesión).
  Future<void> clear() async {
    await ref.read(localCacheProvider).clear();
    state = const NotificationsState();
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );

/// Total de avisos para el badge de la cabecera.
final notificationsTotalProvider = Provider<int>(
  (ref) => ref.watch(notificationsControllerProvider).counters.total,
);

/// Contenido del Centro de soporte (`GET /support`).
final supportProvider = FutureProvider<SupportContent>(
  (ref) => ref.watch(accountRepositoryProvider).fetchSupport(),
);
