import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_amount.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/dashboard_repository.dart';
import '../../data/models/mobile_dashboard.dart';
import '../dashboard_labels.dart';

/// Tarjetas de alerta del inicio (§4.2): apartados por vencer, pedidos por
/// entregar, saldo por cobrar y stock crítico.
///
/// Cada tarjeta se dibuja **solo** si su bloque vino con datos: un bloque en
/// `null` significa «este usuario no tiene el permiso» y no se pinta nada (ni
/// una tarjeta en cero).
class DashboardAlertsGrid extends StatelessWidget {
  const DashboardAlertsGrid({
    super.key,
    required this.dashboard,
    this.onExpiringLayaways,
    this.onUpcomingDeliveries,
    this.onInventory,
  });

  final MobileDashboard dashboard;

  /// Abre el listado de apartados por vencer con la misma ventana (3 días).
  final VoidCallback? onExpiringLayaways;

  /// Abre el listado de pedidos por entregar con la misma ventana (3 días).
  final VoidCallback? onUpcomingDeliveries;

  /// Abre el catálogo (pestaña Vender) para revisar el stock.
  final VoidCallback? onInventory;

  @override
  Widget build(BuildContext context) {
    final layaways = dashboard.layaways;
    final orders = dashboard.orders;
    final receivables = dashboard.receivables;
    final inventory = dashboard.inventory;

    final cards = <Widget>[
      if (layaways != null)
        _AlertCard(
          icon: Icons.event_available_outlined,
          value: _CountValue(
            count: layaways.expiringCount,
            tone: layaways.expiringCount > 0 ? EzySeverity.warn : null,
          ),
          title: DashboardLabels.expiringLayawaysTitle,
          hint: DashboardLabels.windowHint(dashboardDefaultDays),
          onTap: onExpiringLayaways,
        ),
      if (orders != null)
        _AlertCard(
          icon: Icons.local_shipping_outlined,
          value: _CountValue(
            count: orders.upcomingDeliveriesCount,
            tone: orders.upcomingDeliveriesCount > 0 ? EzySeverity.info : null,
          ),
          title: DashboardLabels.upcomingDeliveriesTitle,
          hint: DashboardLabels.deliveriesHint(dashboardDefaultDays),
          onTap: onUpcomingDeliveries,
        ),
      if (receivables != null)
        _AlertCard(
          icon: Icons.account_balance_wallet_outlined,
          value: EzyAmount(
            value: receivables.totalCustomerDebt,
            size: EzyAmountSize.large,
            color: receivables.totalCustomerDebt > 0
                ? StatusPalette.text(context, EzySeverity.warn)
                : null,
          ),
          title: DashboardLabels.receivablesTitle,
          hint: DashboardLabels.receivablesHint,
        ),
      if (inventory != null)
        _AlertCard(
          icon: Icons.inventory_2_outlined,
          value: _CountValue(
            count: inventory.lowStockCount,
            tone: inventory.lowStockCount > 0 ? EzySeverity.warn : null,
          ),
          title: DashboardLabels.lowStockTitle,
          hint: DashboardLabels.lowStockHint(
            inventory.lowStockCount,
            inventory.outOfStockCount,
          ),
          onTap: onInventory,
        ),
    ];

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < cards.length; i += 2) ...<Widget>[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: cards[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (i + 2 < cards.length) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Tarjeta pequeña de alerta: icono, dato grande, título y pista.
class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.value,
    required this.title,
    required this.hint,
    this.onTap,
  });

  final IconData icon;
  final Widget value;
  final String title;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaces.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 18, color: surfaces.textSecondary),
                const Spacer(),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: surfaces.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            value,
            const SizedBox(height: 8),
            Text(
              title,
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contador de una tarjeta de alerta: número grande, teñido cuando hay algo
/// pendiente.
class _CountValue extends StatelessWidget {
  const _CountValue({required this.count, this.tone});

  final int count;
  final EzySeverity? tone;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = tone == null
        ? surfaces.textPrimary
        : StatusPalette.text(context, tone!);

    return Text(
      '$count',
      style: EzyTextStyles.moneyMedium.copyWith(color: color),
    );
  }
}

/// Inventario: KPIs de stock, valor y la lista corta para pedir al proveedor.
class DashboardInventoryCard extends StatelessWidget {
  const DashboardInventoryCard({
    super.key,
    required this.inventory,
    this.onTap,
  });

  final InventorySummary inventory;

  /// Abre el catálogo (pestaña Vender).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final products = inventory.lowStockProducts;

    return SectionCard(
      title: DashboardLabels.inventoryTitle,
      trailing: Text(
        DashboardLabels.inventoryItems(inventory.totalItems),
        style: EzyTextStyles.secondary.copyWith(
          color: surfaces.textSecondary,
        ),
      ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionRow(
              label: DashboardLabels.inventoryHealthy,
              value: '${inventory.healthyStockCount}',
            ),
            SectionRow(
              label: DashboardLabels.inventoryLow,
              value: '${inventory.lowStockCount}',
              valueStyle: EzyTextStyles.moneyList.copyWith(
                color: inventory.lowStockCount > 0
                    ? StatusPalette.text(context, EzySeverity.warn)
                    : surfaces.textPrimary,
              ),
            ),
            SectionRow(
              label: DashboardLabels.inventoryOut,
              value: '${inventory.outOfStockCount}',
              valueStyle: EzyTextStyles.moneyList.copyWith(
                color: inventory.outOfStockCount > 0
                    ? StatusPalette.text(context, EzySeverity.danger)
                    : surfaces.textPrimary,
              ),
            ),
            Divider(height: 1, thickness: 1, color: surfaces.border),
            SectionRow(
              label: DashboardLabels.inventoryCost,
              value: Money.format(inventory.totalCost),
            ),
            SectionRow(
              label: DashboardLabels.inventorySaleValue,
              value: Money.format(inventory.totalSaleValue),
            ),
            if (products.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Divider(height: 1, thickness: 1, color: surfaces.border),
              const SizedBox(height: 12),
              Text(
                DashboardLabels.inventoryLowList.toUpperCase(),
                style: EzyTextStyles.microLabel.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              for (final product in products) _LowStockRow(product: product),
            ] else ...<Widget>[
              const SizedBox(height: 12),
              Text(
                DashboardLabels.inventoryEmpty,
                style: EzyTextStyles.secondary.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de bajo stock: nombre, código y `actual de mínimo`.
class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.product});

  final LowStockProduct product;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final sku = product.sku;
    final tone = product.isOutOfStock
        ? EzySeverity.danger
        : EzySeverity.warn;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  product.name,
                  style: EzyTextStyles.body.copyWith(
                    color: surfaces.textBody,
                  ),
                ),
                if (sku != null && sku.isNotEmpty)
                  Text(
                    sku,
                    style: EzyTextStyles.secondary.copyWith(
                      color: surfaces.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            DashboardLabels.stockOf(
              Money.formatQuantity(product.currentStock),
              Money.formatQuantity(product.minStock),
            ),
            style: EzyTextStyles.moneyList.copyWith(
              color: StatusPalette.text(context, tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// Órdenes de servicio por estatus (`services.orders.access`).
///
/// El payload promete las **6** llaves del enum con `0` cuando no hay ninguna,
/// así que se pintan todas: un `0` es información, no una ausencia.
class DashboardServiceOrdersCard extends StatelessWidget {
  const DashboardServiceOrdersCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  final ServiceOrdersSummary summary;

  /// Abre la pestaña Órdenes.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: DashboardLabels.serviceOrdersTitle,
      trailing: onTap == null
          ? null
          : Icon(
              Icons.chevron_right,
              size: 18,
              color: surfaces.textMuted,
            ),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              DashboardLabels.serviceOrdersTotal(summary.total),
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            for (final status in ServiceOrdersSummary.statusKeys)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: <Widget>[
                    StatusBadge.serviceOrder(status),
                    const Spacer(),
                    Text(
                      '${summary.countFor(status)}',
                      style: EzyTextStyles.moneyList.copyWith(
                        color: surfaces.textPrimary,
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

/// Barra de caja: estado del turno del usuario (viaja **siempre**).
///
/// Sin turno abierto no rompe nada: ofrece «Abrir caja» y explica por qué hace
/// falta antes de cobrar.
class DashboardCashBar extends StatelessWidget {
  const DashboardCashBar({super.key, required this.state, this.onTap});

  final CashRegisterState state;

  /// Abre la pestaña Caja (ahí se abre el turno).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final session = state.session;
    final isOpen = state.hasOpenSession && session != null;

    return SectionCard(
      title: DashboardLabels.cashTitle,
      trailing: StatusBadge(
        label: isOpen
            ? DashboardLabels.cashOpenStatus
            : DashboardLabels.cashClosedStatus,
        severity: isOpen ? EzySeverity.success : EzySeverity.neutral,
        showDot: isOpen,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isOpen) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        session.cashRegisterName,
                        style: EzyTextStyles.bodyStrong.copyWith(
                          color: surfaces.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DashboardLabels.cashOpenedAt(AppFormatters.time(session.openedAt))}'
                        '${session.opener == null ? '' : ' · ${session.opener!.name}'}',
                        style: EzyTextStyles.secondary.copyWith(
                          color: surfaces.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: EzyAmount(
                    value: session.totals.cash,
                    label: DashboardLabels.cashCash,
                    size: EzyAmountSize.list,
                  ),
                ),
                Expanded(
                  child: EzyAmount(
                    value: session.totals.card,
                    label: DashboardLabels.cashCard,
                    size: EzyAmountSize.list,
                  ),
                ),
                Expanded(
                  child: EzyAmount(
                    value: session.totals.transfer,
                    label: DashboardLabels.cashTransfer,
                    size: EzyAmountSize.list,
                  ),
                ),
              ],
            ),
          ] else ...<Widget>[
            Text(
              DashboardLabels.cashEmptyHint,
              style: EzyTextStyles.body.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          EzyButton(
            label: isOpen
                ? DashboardLabels.cashViewAction
                : DashboardLabels.cashOpenAction,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
