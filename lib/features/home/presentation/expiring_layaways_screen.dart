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
import '../data/models/expiring_layaway.dart';
import 'dashboard_labels.dart';
import 'widgets/dashboard_controls.dart';

/// Apartados y créditos por vencer (`GET /dashboard/expiring-layaways`, §3b.3).
///
/// Los días restantes y el vencimiento llegan calculados por el servidor: la
/// pantalla solo los pinta (las vencidas en rojo).
class ExpiringLayawaysScreen extends ConsumerWidget {
  const ExpiringLayawaysScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(expiringLayawaysControllerProvider);
    final controller = ref.read(expiringLayawaysControllerProvider.notifier);
    final error = state.errorMessage;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            DashboardScreenHeader(
              title: DashboardLabels.expiringLayawaysListTitle,
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
                        title: DashboardLabels.expiringLayawaysEmptyTitle,
                        message: DashboardLabels.expiringLayawaysListEmpty,
                        icon: Icons.event_busy_outlined,
                        compact: true,
                      )
                    else
                      for (int i = 0; i < state.items.length; i++) ...<Widget>[
                        _LayawayCard(item: state.items[i]),
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

/// Fila de un apartado o crédito: estado, cliente, fecha y saldos.
class _LayawayCard extends StatelessWidget {
  const _LayawayCard({required this.item});

  final ExpiringLayaway item;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
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
            '$_typeLabel · ${DashboardLabels.expiresOn} '
            '${AppFormatters.date(item.expirationDate)}'
            '${phone == null || phone.isEmpty ? '' : ' · $phone'}',
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
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

  /// `type` es la etiqueta de la UI; `status` es el valor del enum.
  String get _typeLabel => item.type == 'credito'
      ? DashboardLabels.layawayTypeCredito
      : DashboardLabels.layawayTypeApartado;

  String get _statusLabel {
    if (item.isOverdue) {
      return DashboardLabels.overdueBy(item.daysRemaining);
    }

    if (item.isDueToday) {
      return DashboardLabels.dueToday;
    }

    return DashboardLabels.dueInDays(item.daysRemaining);
  }

  EzySeverity get _severity {
    if (item.isOverdue) {
      return EzySeverity.danger;
    }

    return item.isDueToday ? EzySeverity.warn : EzySeverity.info;
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
