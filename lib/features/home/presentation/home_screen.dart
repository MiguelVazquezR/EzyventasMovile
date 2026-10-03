import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/ezy_amount.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/application/auth_controller.dart';
import '../application/dashboard_controller.dart';
import '../data/models/mobile_dashboard.dart';
import 'dashboard_labels.dart';
import 'widgets/dashboard_cards.dart';

/// Pestaña «Inicio»: la pantalla de inicio del negocio (§4.2 del contexto).
///
/// Todo se arma con **una sola llamada** (`GET /dashboard`). Cada tarjeta se
/// dibuja si su bloque tiene datos: un bloque en `null` significa que el usuario
/// no tiene el permiso y no se pinta nada (ni una tarjeta en cero). El turno de
/// caja viaja siempre, así que la barra de caja nunca falta.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final accessContext = ref.watch(authControllerProvider).context;
    final permissions = ref.watch(permissionsProvider);

    final dashboard = state.dashboard;
    final generatedAt = dashboard?.generatedAt;
    final error = state.errorMessage;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AppScreenHeader(
              title: DashboardLabels.title,
              subtitle: generatedAt == null
                  ? accessContext?.businessName
                  : DashboardLabels.updatedAt(AppFormatters.time(generatedAt)),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  // El inicio puede ser más corto que la pantalla: sin física
                  // propia el pull-to-refresh no tendría sobretirón que leer.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: <Widget>[
                    if (permissions.moduleKeys.isEmpty) ...<Widget>[
                      const NoticeBanner(
                        message:
                            'Tu suscripción no tiene módulos activos. '
                            'Contacta al administrador para renovar el plan.',
                        tone: EzySeverity.warn,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (error != null) ...<Widget>[
                      ErrorNotice(message: error, onRetry: controller.refresh),
                      const SizedBox(height: 12),
                    ],
                    if (state.isFirstLoad)
                      const _LoadingState()
                    else if (dashboard != null)
                      ..._summaryCards(
                        context,
                        permissions: permissions,
                        dashboard: dashboard,
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
}

/// Tarjetas del inicio, en el orden de §4.2.
List<Widget> _summaryCards(
  BuildContext context, {
  required PermissionsService permissions,
  required MobileDashboard dashboard,
}) {
  final sales = dashboard.sales;
  final inventory = dashboard.inventory;
  final serviceOrders = dashboard.serviceOrders;

  return <Widget>[
    if (sales != null) ...<Widget>[
      _SalesCard(
        sales: sales,
        onTap: _tabAction(context, permissions, AppTab.sales),
      ),
      const SizedBox(height: 16),
      _WeeklyTrendCard(sales: sales),
      const SizedBox(height: 16),
    ],
    DashboardAlertsGrid(
      dashboard: dashboard,
      onExpiringLayaways: () => context.push(expiringLayawaysPath),
      onUpcomingDeliveries: () => context.push(upcomingDeliveriesPath),
      onInventory: _tabAction(context, permissions, AppTab.sell),
    ),
    if (inventory != null) ...<Widget>[
      const SizedBox(height: 16),
      DashboardInventoryCard(
        inventory: inventory,
        onTap: _tabAction(context, permissions, AppTab.sell),
      ),
    ],
    if (serviceOrders != null) ...<Widget>[
      const SizedBox(height: 16),
      DashboardServiceOrdersCard(
        summary: serviceOrders,
        onTap: _tabAction(context, permissions, AppTab.serviceOrders),
      ),
    ],
    const SizedBox(height: 16),
    DashboardCashBar(
      state: dashboard.cashRegister,
      onTap: _tabAction(context, permissions, AppTab.cashRegister),
    ),
  ];
}

/// Acción que abre una pestaña del cascarón.
///
/// Si el usuario no tiene esa pestaña (permiso o módulo) se devuelve `null` y la
/// tarjeta se dibuja sin acceso, en lugar de ofrecer algo que el servidor va a
/// rechazar (§11.4).
VoidCallback? _tabAction(
  BuildContext context,
  PermissionsService permissions,
  AppTab tab,
) {
  if (!permissions.isTabVisible(tab)) {
    return null;
  }

  return () => context.go(tab.path);
}

/// Venta de hoy con su ticket promedio y el cierre de ayer.
class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.sales, this.onTap});

  final SalesSummary sales;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SectionCard(
        title: DashboardLabels.todaySalesTitle,
        trailing: Text(
          DashboardLabels.salesCount(sales.todayCount),
          style: EzyTextStyles.secondary.copyWith(
            color: surfaces.textSecondary,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            EzyAmount(
              value: sales.todayTotal,
              size: EzyAmountSize.hero,
              withCurrency: true,
            ),
            const SizedBox(height: 8),
            Text(
              DashboardLabels.averageTicket(Money.format(sales.averageTicket)),
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: surfaces.border),
            SectionRow(
              label: DashboardLabels.yesterday,
              value: Money.format(sales.yesterdayTotal),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tendencia semanal: 7 barras, lunes a domingo, con hoy destacado.
class _WeeklyTrendCard extends StatelessWidget {
  const _WeeklyTrendCard({required this.sales});

  final SalesSummary sales;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final days = sales.weeklyTrend;

    // El orden del payload es fijo (lunes → domingo), así que el día de hoy es
    // el índice del reloj del teléfono.
    final today = DateTime.now().weekday - 1;
    var max = 0.0;
    for (final day in days) {
      if (day.total > max) {
        max = day.total;
      }
    }

    return SectionCard(
      title: DashboardLabels.weeklyTrendTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            DashboardLabels.weeklyTrendSubtitle,
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 104,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < days.length; i++)
                  Expanded(
                    child: _TrendBar(
                      day: days[i],
                      maxTotal: max,
                      isToday: i == today,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de un día de la tendencia.
class _TrendBar extends StatelessWidget {
  const _TrendBar({
    required this.day,
    required this.maxTotal,
    required this.isToday,
  });

  final WeeklyTrendDay day;
  final double maxTotal;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final ratio = maxTotal <= 0 ? 0.0 : (day.total / maxTotal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          Container(
            height: 6 + (72 * ratio),
            decoration: BoxDecoration(
              color: isToday ? EzyColors.primary : surfaces.borderStrong,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            day.day,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.badge.copyWith(
              letterSpacing: 0,
              color: isToday ? EzyColors.primary : surfaces.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}
