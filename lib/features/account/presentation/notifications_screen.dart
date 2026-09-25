import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/ezy_list_tile.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
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
    final categories = state.counters.visibleCategories;

    return AccountScaffold(
      title: AccountLabels.notificationsTitle,
      onRefresh: controller.refresh,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          if (state.errorMessage != null) ...<Widget>[
            ErrorNotice(
              message: state.errorMessage!,
              onRetry: controller.refresh,
            ),
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
            SectionCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < categories.length; i++)
                    _CategoryRow(
                      category: categories[i],
                      count: state.countFor(categories[i]),
                      showDivider: i < categories.length - 1,
                      onTap: () => _openCategory(context, ref, categories[i]),
                    ),
                ],
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

/// Fila de una categoría de avisos, con el conteo del servidor como badge.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.count,
    required this.showDivider,
    required this.onTap,
  });

  final NotificationCategory category;
  final int count;
  final bool showDivider;

  /// `null` cuando no hay pantalla equivalente en la app: la fila se explica.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasItems = count > 0;

    return EzyListTile(
      icon: _icon,
      title: category.label,
      subtitle: _subtitle,
      badgeCount: count,
      showDivider: showDivider,
      onTap: hasItems ? onTap : null,
    );
  }

  IconData get _icon => switch (category) {
    NotificationCategory.expiringDebts => Icons.schedule_outlined,
    NotificationCategory.upcomingDeliveries => Icons.local_shipping_outlined,
    NotificationCategory.unreadUpdates => Icons.campaign_outlined,
    NotificationCategory.pendingOrders => Icons.shopping_bag_outlined,
  };

  /// Descripción del contador y, si no hay pantalla equivalente, la explicación.
  String get _subtitle => <String>[
    _description,
    if (onTap == null && count > 0) _futureAction ?? '',
  ].where((line) => line.isNotEmpty).join(' ');

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
