import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../sales/application/sales_controller.dart';
import '../../sales/presentation/widgets/sales_labels.dart';
import '../application/account_providers.dart';
import '../data/models/notification_counters.dart';
import 'account_labels.dart';
import 'widgets/notification_category_tile.dart';
import 'widgets/notification_empty_state.dart';

/// Notificaciones de la campana (`GET /notifications`, contrato §11b.2).
///
/// Cada categoría navega a su listado cuando la app tiene una pantalla
/// equivalente (ventas y pedidos por entregar). Las novedades de la versión y
/// los pedidos de la tienda en línea se gestionan en la web: se explican y no
/// se finge una pantalla que no existe.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);
    final hasSalesPermission = ref
        .watch(permissionsProvider)
        .can('transactions.access');

    final counters = state.counters;
    final categories = counters.visibleCategories;
    final hasError = state.errorMessage != null;
    final totalVisible = counters.visibleTotal;
    final showEmpty = totalVisible == 0 && !hasError;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _Header(total: hasError ? 0 : totalVisible),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: <Widget>[
                    if (hasError) ...<Widget>[
                      NoticeBanner(
                        title: AccountLabels.notificationsSyncFailed,
                        message: state.errorMessage!,
                        icon: Icons.error_outline,
                        tone: EzySeverity.danger,
                        actionLabel: AccountLabels.notificationsRetry,
                        onAction: controller.refresh,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.hasCachedValue) ...<Widget>[
                      const NoticeBanner(
                        message: AccountLabels.notificationsCached,
                        icon: Icons.wifi_off_outlined,
                        tone: EzySeverity.info,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (state.isLoading && counters.isEmpty)
                      const _LoadingState()
                    else if (showEmpty)
                      const NotificationEmptyState()
                    else
                      SectionCard(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: <Widget>[
                            for (int i = 0; i < categories.length; i++)
                              NotificationCategoryTile(
                                icon: _iconFor(categories[i]),
                                title: categories[i].label,
                                subtitle: _subtitleFor(categories[i]),
                                count: counters.countFor(categories[i]),
                                showDivider: i < categories.length - 1,
                                onTap:
                                    _canOpen(
                                      categories[i],
                                      counters,
                                      hasSalesPermission,
                                    )
                                    ? () => _openCategory(
                                        context,
                                        ref,
                                        categories[i],
                                      )
                                    : null,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// La fila navega solo si hay elementos y el usuario puede ver ventas.
  bool _canOpen(
    NotificationCategory category,
    NotificationCounters counters,
    bool hasSalesPermission,
  ) {
    if (!hasSalesPermission || counters.countFor(category) <= 0) {
      return false;
    }

    return category == NotificationCategory.expiringDebts ||
        category == NotificationCategory.upcomingDeliveries;
  }

  IconData _iconFor(NotificationCategory category) => switch (category) {
    NotificationCategory.expiringDebts => Icons.schedule_outlined,
    NotificationCategory.upcomingDeliveries => Icons.local_shipping_outlined,
    NotificationCategory.unreadUpdates => Icons.campaign_outlined,
    NotificationCategory.pendingOrders => Icons.shopping_bag_outlined,
  };

  /// Descripción del contador o la explicación de la categoría de solo lectura.
  String _subtitleFor(NotificationCategory category) => switch (category) {
    NotificationCategory.expiringDebts => category.description,
    NotificationCategory.upcomingDeliveries => category.description,
    NotificationCategory.unreadUpdates =>
      AccountLabels.notificationsReleaseNotes,
    NotificationCategory.pendingOrders =>
      AccountLabels.notificationsOnlineStore,
  };

  /// Lleva al listado correspondiente con el filtro que sí admite el servidor.
  void _openCategory(
    BuildContext context,
    WidgetRef ref,
    NotificationCategory category,
  ) {
    if (!ref.read(permissionsProvider).can('transactions.access')) {
      return;
    }

    switch (category) {
      case NotificationCategory.expiringDebts:
        // El contador agrupa apartados y créditos: el listado los acepta juntos
        // en una sola llamada (`?status[]=apartado&status[]=pendiente`, §8).
        ref
            .read(transactionsControllerProvider.notifier)
            .setStatuses(SalesLabels.expiringDebtStatuses);
      case NotificationCategory.upcomingDeliveries:
        ref
            .read(transactionsControllerProvider.notifier)
            .setStatus(SalesLabels.toDeliver);
      case NotificationCategory.unreadUpdates:
      case NotificationCategory.pendingOrders:
        return;
    }

    context.go(AppTab.sales.path);
  }
}

/// Cabecera limpia sin `AppBar`: botón de regreso, título con subtítulo y la
/// pastilla del total pendiente.
class _Header extends StatelessWidget {
  const _Header({required this.total});

  /// Total de avisos visibles; `0` no pinta la pastilla.
  final int total;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: <Widget>[
          Tooltip(
            message: AccountLabels.back,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: surfaces.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: surfaces.border),
                ),
                child: Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: surfaces.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AccountLabels.notificationsTitle,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: surfaces.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AccountLabels.notificationsSubtitle,
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (total > 0) ...<Widget>[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: EzyColors.danger,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$total pendientes',
                style: EzyTextStyles.badge.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  color: EzyColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Spinner de marca mientras llegan los contadores por primera vez.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: EzyColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            AccountLabels.notificationsLoading,
            style: EzyTextStyles.caption.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
