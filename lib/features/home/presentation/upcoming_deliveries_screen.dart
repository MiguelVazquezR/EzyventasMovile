import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/dashboard_controller.dart';
import '../data/models/upcoming_delivery.dart';
import 'dashboard_labels.dart';
import 'widgets/dashboard_controls.dart';

/// Pedidos por entregar (`GET /dashboard/upcoming-deliveries`, §3b.4).
///
/// `delivery_date` es un **día en medianoche UTC**: para pintarlo se usa su
/// parte `YYYY-MM-DD` y nunca se convierte a hora local. El «entrega hoy» y el
/// «vencida hace N días» los calcula el servidor.
class UpcomingDeliveriesScreen extends ConsumerWidget {
  const UpcomingDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(upcomingDeliveriesControllerProvider);
    final controller = ref.read(upcomingDeliveriesControllerProvider.notifier);
    final error = state.errorMessage;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            DashboardScreenHeader(
              title: DashboardLabels.upcomingDeliveriesListTitle,
              subtitle: DashboardLabels.windowTitle(state.days),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                  children: <Widget>[
                    if (error != null) ...<Widget>[
                      ErrorNotice(message: error, onRetry: controller.refresh),
                      const SizedBox(height: 12),
                    ],
                    DashboardWindowFilter(
                      days: state.days,
                      onChanged: controller.setDays,
                    ),
                    const SizedBox(height: 16),
                    if (state.isLoading && state.items.isEmpty)
                      const _LoadingState()
                    else if (state.isEmpty)
                      const EmptyState(
                        title: DashboardLabels.upcomingDeliveriesEmptyTitle,
                        message: DashboardLabels.upcomingDeliveriesListEmpty,
                        icon: Icons.local_shipping_outlined,
                        compact: true,
                      )
                    else
                      for (int i = 0; i < state.items.length; i++) ...<Widget>[
                        _DeliveryCard(item: state.items[i]),
                        if (i < state.items.length - 1)
                          const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de un pedido por entregar: entrega, cliente, dirección y saldos.
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({required this.item});

  final UpcomingDelivery item;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final address = item.shippingAddress;
    final notes = item.notes;
    final phone = item.customerPhone;

    return SectionCard(
      inner: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusBadge(label: _statusLabel, severity: _severity),
              const Spacer(),
              Text(
                item.folio,
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.customerName,
            style: EzyTextStyles.bodyStrong.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${DashboardLabels.deliveryDate} '
            '${AppFormatters.date(item.deliveryDay)}'
            '${phone == null || phone.isEmpty ? '' : ' · $phone'}',
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          if (address != null && address.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '${DashboardLabels.shippingAddress}: $address',
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '${DashboardLabels.notes}: $notes',
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: surfaces.border),
          const SizedBox(height: 8),
          SectionRow(
            label: DashboardLabels.totalAmount,
            value: Money.format(item.totalAmount),
          ),
          SectionRow(
            label: DashboardLabels.paidAmount,
            value: Money.format(item.totalPaid),
          ),
          SectionRow(
            label: DashboardLabels.pendingAmount,
            value: Money.format(item.pendingAmount),
            emphasized: true,
          ),
        ],
      ),
    );
  }

  String get _statusLabel {
    if (item.isOverdue) {
      return DashboardLabels.deliveryOverdueBy(item.daysRemaining);
    }

    if (item.isToday) {
      return DashboardLabels.deliveryToday;
    }

    return DashboardLabels.deliveryInDays(item.daysRemaining);
  }

  EzySeverity get _severity {
    if (item.isOverdue) {
      return EzySeverity.danger;
    }

    return item.isToday ? EzySeverity.warn : EzySeverity.info;
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
