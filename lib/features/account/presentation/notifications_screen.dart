import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../../sales/application/sales_controller.dart';
import '../../sales/presentation/widgets/sales_labels.dart';
import '../application/account_providers.dart';
import '../data/models/notification_counters.dart';
import 'account_labels.dart';
import 'widgets/account_scaffold.dart';

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

    return AccountScaffold(
      title: AccountLabels.notificationsTitle,
      onRefresh: controller.refresh,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          if (state.errorMessage != null) ...<Widget>[
            ErrorNotice(message: state.errorMessage!, onRetry: controller.refresh),
            const SizedBox(height: 12),
          ],
          if (state.hasCachedValue) ...<Widget>[
            const NoticeBanner(
              message: AccountLabels.notificationsCached,
              tone: EzySeverity.info,
            ),
            const SizedBox(height: 12),
          ],
          if (state.isLoading && state.counters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.counters.isEmpty)
            const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: AccountLabels.notificationsEmpty,
            )
          else
            for (final category in state.counters.visibleCategories)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CategoryCard(
                  category: category,
                  count: state.countFor(category),
                  onTap: () => _openCategory(context, ref, category),
                ),
              ),
        ],
      ),
    );
  }

  /// Lleva al listado correspondiente con el filtro que sí admite el servidor.
  void _openCategory(
    BuildContext context,
    WidgetRef ref,
    NotificationCategory category,
  ) {
    final permissions = ref.read(permissionsProvider);

    if (!permissions.can('transactions.access')) {
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


/// Tarjeta de una categoría de avisos.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.onTap,
  });

  final NotificationCategory category;
  final int count;

  /// `null` cuando no hay pantalla equivalente en la app: la fila se explica.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final hasItems = count > 0;
    final severity = hasItems ? EzySeverity.info : EzySeverity.neutral;
    final color = hasItems
        ? StatusPalette.text(context, severity)
        : surfaces.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: surfaces.border),
      ),
      child: InkWell(
        onTap: hasItems ? onTap : null,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: StatusPalette.soft(severity),
                  shape: BoxShape.circle,
                  border: Border.all(color: StatusPalette.border(severity)),
                ),
                child: Text(
                  '$count',
                  style: EzyTextStyles.moneyList.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      category.label,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        color: surfaces.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _description,
                      style: EzyTextStyles.caption.copyWith(
                        color: surfaces.textSecondary,
                      ),
                    ),
                    if (onTap == null && hasItems) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        _futureAction ?? '',
                        style: EzyTextStyles.caption.copyWith(
                          color: surfaces.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null && hasItems)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: surfaces.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String get _description => onTap == null && count > 0
      ? (_futureAction ?? category.description)
      : category.description;

  /// Explicación de por qué la categoría no abre una pantalla en la app.
  String? get _futureAction => switch (category) {
    NotificationCategory.unreadUpdates =>
      AccountLabels.notificationsReleaseNotes,
    NotificationCategory.pendingOrders =>
      AccountLabels.notificationsOnlineStore,
    _ => AccountLabels.notificationsOpenSales,
  };
}
