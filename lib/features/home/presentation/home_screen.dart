import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/status_badge.dart';
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
/// caja viaja siempre, así que la barra de caja nunca falta: flota sobre la lista
/// pegada al borde inferior, para tenerla a mano sin recorrer la pantalla.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Hueco que se reserva al final de la lista para que la barra flotante no
  /// tape la última tarjeta (alto de la barra más su margen).
  static const double _cashBarGap = 264;

  /// Alto del desvanecido que se pinta bajo la barra de caja: el contenido que
  /// pasa por detrás se disuelve en el fondo de la pantalla en lugar de leerse
  /// tras la tarjeta (la barra en sí es opaca, pero el hueco de sus lados no).
  static const double _cashBarFade = _cashBarGap + 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final accessContext = ref.watch(authControllerProvider).context;
    final permissions = ref.watch(permissionsProvider);
    final surfaces = context.surfaces;

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
              // El chip no es adorno: dice que lo que se ve es el último
              // `GET /dashboard`, no un cálculo del teléfono.
              actions: <Widget>[
                if (generatedAt != null)
                  const Tooltip(
                    message: DashboardLabels.liveHint,
                    child: StatusBadge(
                      label: DashboardLabels.live,
                      severity: EzySeverity.success,
                      showDot: true,
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ListView(
                      // El inicio puede ser más corto que la pantalla: sin física
                      // propia el pull-to-refresh no tendría sobretirón que leer.
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        dashboard == null ? 32 : _cashBarGap,
                      ),
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
                          ErrorNotice(
                            message: error,
                            onRetry: controller.refresh,
                          ),
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
                  if (dashboard != null)
                    // Desvanecido: sin él, lo que queda bajo el hueco que rodea
                    // la tarjeta se leía entero hasta el borde de la pantalla.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: _cashBarFade,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                surfaces.background.withValues(alpha: 0),
                                surfaces.background,
                              ],
                              stops: const <double>[0, 0.55],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (dashboard != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: DashboardCashBar(
                        state: dashboard.cashRegister,
                        onTap: _tabAction(
                          context,
                          permissions,
                          AppTab.cashRegister,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjetas del inicio, en el orden del rediseño: primero lo que se mira al
/// llegar (venta de hoy y accesos rápidos), después lo que reclama acción
/// (alertas) y al final el detalle (inventario y órdenes de servicio).
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
      DashboardTodaySalesCard(
        sales: sales,
        onTap: _tabAction(context, permissions, AppTab.sales),
      ),
      const SizedBox(height: 16),
      DashboardWeeklyTrendCard(sales: sales),
      const SizedBox(height: 16),
    ],
    DashboardQuickActions(
      onSell: _tabAction(context, permissions, AppTab.sell),
      onLayaways: () => context.push(expiringLayawaysPath),
      onDeliveries: () => context.push(upcomingDeliveriesPath),
    ),
    const SizedBox(height: 16),
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

/// Primera carga: el inicio todavía no tiene ningún bloque que dibujar.
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
