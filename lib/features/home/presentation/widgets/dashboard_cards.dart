import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/status_catalog.dart';
import '../../../../core/widgets/ezy_amount.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/dashboard_repository.dart';
import '../../data/models/mobile_dashboard.dart';
import '../dashboard_labels.dart';

/// Panel translúcido del inicio: radio amplio, borde de 1 px y un brillo
/// superior tenue. Sin sombras: la separación la hace el borde (design system
/// «Tesla UI»), y el brillo solo existe cuando la tarjeta tiene un estado que
/// contar ([glow]).
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.glow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Color del estado: tiñe el borde y el arranque del degradado.
  final Color? glow;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final tint = glow;
    final border = tint == null
        ? surfaces.borderStrong
        : tint.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              tint == null
                  ? surfaces.textPrimary.withValues(alpha: 0.03)
                  : tint.withValues(alpha: 0.14),
              surfaces.panel,
            ],
            stops: const <double>[0, 0.6],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Chip de dato del hero: icono pequeño y texto de apoyo en una píldora.
class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: surfaces.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.secondary.copyWith(color: surfaces.textBody),
            ),
          ),
        ],
      ),
    );
  }
}

/// Variación de hoy contra ayer: flecha y porcentaje con el color del signo.
///
/// Solo se dibuja cuando ayer tuvo venta: sin divisor no hay porcentaje que
/// calcular, y un `+100 %` inventado mentiría.
class _VariationBadge extends StatelessWidget {
  const _VariationBadge({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final isUp = percent >= 0;
    final severity = isUp ? EzySeverity.success : EzySeverity.danger;
    final color = StatusPalette.text(context, severity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: StatusPalette.soft(severity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(severity)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isUp ? Icons.trending_up : Icons.trending_down,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              DashboardLabels.vsYesterday(
                '${percent.abs().toStringAsFixed(1)}%',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.badge.copyWith(
                color: color,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ojo de privacidad: tapa los montos del hero sin tocar la pantalla.
class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.hidden, required this.onPressed});

  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return IconButton(
      onPressed: onPressed,
      tooltip: hidden ? DashboardLabels.showAmount : DashboardLabels.hideAmount,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      iconSize: 18,
      icon: Icon(
        hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: surfaces.textMuted,
      ),
    );
  }
}

/// Venta de hoy: el hero del inicio.
///
/// El monto del servidor en la escala mayor del design system y, debajo, los
/// datos que lo explican: cuántas ventas, el ticket promedio y el cierre de
/// ayer. El ojo oculta **solo los importes** (nunca el conteo): el inicio se
/// mira de pie, con clientes delante.
class DashboardTodaySalesCard extends StatefulWidget {
  const DashboardTodaySalesCard({super.key, required this.sales, this.onTap});

  final SalesSummary sales;

  /// Abre la pestaña Ventas.
  final VoidCallback? onTap;

  @override
  State<DashboardTodaySalesCard> createState() =>
      _DashboardTodaySalesCardState();
}

class _DashboardTodaySalesCardState extends State<DashboardTodaySalesCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final sales = widget.sales;
    final yesterday = sales.yesterdayTotal;
    final variation = yesterday <= 0
        ? null
        : (sales.todayTotal - yesterday) / yesterday * 100;
    final masked = _hidden;

    return _GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(20),
      glow: EzyColors.primary,
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  DashboardLabels.todaySalesTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.microLabel.copyWith(
                    color: EzyColors.primary,
                  ),
                ),
              ),
              if (variation != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 128),
                  child: _VariationBadge(percent: variation),
                ),
              _PrivacyToggle(
                hidden: _hidden,
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (masked)
            Text(
              DashboardLabels.maskAmount,
              style: EzyTextStyles.moneyLarge.copyWith(
                color: surfaces.textPrimary,
              ),
            )
          else
            EzyAmount(
              value: sales.todayTotal,
              size: EzyAmountSize.hero,
              withCurrency: true,
            ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              _StatChip(
                icon: Icons.receipt_long_outlined,
                text: DashboardLabels.salesCount(sales.todayCount),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatChip(
                  icon: Icons.confirmation_number_outlined,
                  text: DashboardLabels.averageTicket(
                    masked
                        ? DashboardLabels.maskAmount
                        : Money.format(sales.averageTicket),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: surfaces.border),
          SectionRow(
            label: DashboardLabels.yesterday,
            value: masked
                ? DashboardLabels.maskAmount
                : Money.format(yesterday),
          ),
        ],
      ),
    );
  }
}

/// Tendencia semanal: 7 barras, lunes a domingo, con el día de hoy destacado.
///
/// El orden del payload es fijo (lunes → domingo), así que el día de hoy es el
/// índice del reloj del teléfono. Tocar una barra trae su monto a la cabecera
/// —sin salir del inicio— y volver a tocarla lo quita.
class DashboardWeeklyTrendCard extends StatefulWidget {
  const DashboardWeeklyTrendCard({super.key, required this.sales});

  final SalesSummary sales;

  @override
  State<DashboardWeeklyTrendCard> createState() =>
      _DashboardWeeklyTrendCardState();
}

class _DashboardWeeklyTrendCardState extends State<DashboardWeeklyTrendCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final days = widget.sales.weeklyTrend;
    final today = DateTime.now().weekday - 1;
    var max = 0.0;
    for (final day in days) {
      if (day.total > max) {
        max = day.total;
      }
    }

    final index = _selected;
    final selected = index != null && index < days.length ? days[index] : null;

    return SectionCard(
      title: DashboardLabels.weeklyTrendTitle,
      trailing: selected == null
          ? null
          : Text(
              Money.format(selected.total),
              style: EzyTextStyles.moneyBar.copyWith(color: EzyColors.primary),
            ),
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
            height: 108,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < days.length; i++)
                  Expanded(
                    child: _TrendColumn(
                      day: days[i],
                      maxTotal: max,
                      isToday: i == today,
                      isSelected: i == index,
                      onTap: () =>
                          setState(() => _selected = index == i ? null : i),
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

/// Barra de un día de la tendencia. La seleccionada engorda y se pinta con el
/// naranja de marca, igual que el día de hoy.
class _TrendColumn extends StatelessWidget {
  const _TrendColumn({
    required this.day,
    required this.maxTotal,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final WeeklyTrendDay day;
  final double maxTotal;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final highlighted = isToday || isSelected;
    final ratio = maxTotal <= 0 ? 0.0 : (day.total / maxTotal).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Container(
              width: isSelected ? 14 : 9,
              height: 6 + (70 * ratio),
              decoration: BoxDecoration(
                gradient: highlighted
                    ? const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: <Color>[
                          EzyColors.primary600,
                          EzyColors.primary300,
                        ],
                      )
                    : null,
                color: highlighted ? null : surfaces.borderStrong,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              day.day,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.badge.copyWith(
                letterSpacing: 0,
                color: highlighted ? EzyColors.primary : surfaces.textSecondary,
                fontWeight: isSelected ? FontWeight.w900 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accesos rápidos: los tres destinos que el mostrador toca todo el día.
///
/// Un acceso sin acción (`null`) se dibuja apagado en lugar de desaparecer: la
/// fila mantiene su ritmo y el hueco no se lee como un error de carga.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    super.key,
    this.onSell,
    this.onLayaways,
    this.onDeliveries,
  });

  /// Vender: el punto de venta (pestaña Vender).
  final VoidCallback? onSell;

  /// Apartados por vencer.
  final VoidCallback? onLayaways;

  /// Pedidos por entregar.
  final VoidCallback? onDeliveries;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _QuickAction(
              icon: Icons.point_of_sale_outlined,
              label: DashboardLabels.quickSell,
              onTap: onSell,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAction(
              icon: Icons.bookmark_added_outlined,
              label: DashboardLabels.quickLayaways,
              onTap: onLayaways,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickAction(
              icon: Icons.local_shipping_outlined,
              label: DashboardLabels.quickDeliveries,
              onTap: onDeliveries,
            ),
          ),
        ],
      ),
    );
  }
}

/// Acceso rápido: círculo con el icono y la etiqueta debajo.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isEnabled = onTap != null;
    final tint = isEnabled ? EzyColors.primary : surfaces.textMuted;

    return _GlassPanel(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isEnabled
                  ? EzyColors.primary.withValues(alpha: 0.14)
                  : surfaces.panelInner,
              shape: BoxShape.circle,
              border: Border.all(
                color: isEnabled
                    ? EzyColors.primary.withValues(alpha: 0.3)
                    : surfaces.border,
              ),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: EzyTextStyles.caption.copyWith(
              color: isEnabled ? surfaces.textPrimary : surfaces.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
          badge: layaways.expiringCount > 0
              ? DashboardLabels.badgeExpiring
              : null,
          severity: layaways.expiringCount > 0 ? EzySeverity.warn : null,
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
          badge: orders.upcomingDeliveriesCount > 0
              ? DashboardLabels.badgeOnRoute
              : null,
          severity: orders.upcomingDeliveriesCount > 0
              ? EzySeverity.info
              : null,
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
          badge: receivables.totalCustomerDebt > 0
              ? DashboardLabels.badgePending
              : null,
          severity: receivables.totalCustomerDebt > 0 ? EzySeverity.warn : null,
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
          badge: inventory.outOfStockCount > 0
              ? DashboardLabels.badgeCritical
              : DashboardLabels.badgePending,
          severity: inventory.outOfStockCount > 0
              ? EzySeverity.danger
              : EzySeverity.warn,
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
                // Un número impar de tarjetas deja la última media fila: el
                // hueco se rellena para que la fila ocupe el ancho completo.
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

/// Tarjeta de alerta: chip de icono, dato, título y pista.
///
/// El `badge` y el `glow` (borde y brillo del color del estado) aparecen solo
/// cuando hay algo que atender: la tarjeta en cero se queda neutra.
class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.value,
    required this.title,
    required this.hint,
    this.badge,
    this.severity,
    this.onTap,
  });

  final IconData icon;
  final Widget value;
  final String title;
  final String hint;

  /// Badge del estado («Por vencer», «En ruta», …).
  final String? badge;

  /// Severidad que tiñe el borde, el chip de icono y el badge.
  final EzySeverity? severity;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final tone = severity;
    final badgeLabel = badge;

    return _GlassPanel(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      glow: tone == null ? null : StatusPalette.base(tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // `Wrap` en lugar de `Row`: en pantallas angostas el badge no cabe a la
          // derecha del icono y baja a una segunda línea en lugar de desbordar.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tone == null
                      ? surfaces.panelInner
                      : StatusPalette.soft(tone),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tone == null
                        ? surfaces.border
                        : StatusPalette.border(tone),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: tone == null
                      ? surfaces.textSecondary
                      : StatusPalette.text(context, tone),
                ),
              ),
              if (badgeLabel != null)
                StatusBadge(
                  label: badgeLabel,
                  severity: tone ?? EzySeverity.neutral,
                ),
            ],
          ),
          const SizedBox(height: 12),
          value,
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.caption.copyWith(
              color: surfaces.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
        ],
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

/// Inventario: KPIs de stock, valor del almacén y la lista corta para pedir al
/// proveedor.
class DashboardInventoryCard extends StatelessWidget {
  const DashboardInventoryCard({
    super.key,
    required this.inventory,
    this.onTap,
  });

  final InventorySummary inventory;

  /// Abre el catálogo (pestaña Vender) con el buscador listo.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final products = inventory.lowStockProducts;

    return SectionCard(
      title: DashboardLabels.inventoryTitle,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              DashboardLabels.inventoryItems(inventory.totalItems),
              style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
            ),
            const SizedBox(height: 14),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: _StockKpi(
                      severity: EzySeverity.success,
                      value: '${inventory.healthyStockCount}',
                      label: DashboardLabels.inventoryHealthy,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StockKpi(
                      severity: EzySeverity.warn,
                      value: '${inventory.lowStockCount}',
                      label: DashboardLabels.inventoryLow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StockKpi(
                      severity: EzySeverity.danger,
                      value: '${inventory.outOfStockCount}',
                      label: DashboardLabels.inventoryOut,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SectionRow(
              label: DashboardLabels.inventoryCost,
              value: Money.format(inventory.totalCost),
            ),
            SectionRow(
              label: DashboardLabels.inventorySaleValue,
              value: Money.format(inventory.totalSaleValue),
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: surfaces.border),
            const SizedBox(height: 12),
            Text(
              DashboardLabels.inventoryLowList.toUpperCase(),
              style: EzyTextStyles.microLabel.copyWith(
                color: surfaces.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            if (products.isEmpty)
              Text(
                DashboardLabels.inventoryEmpty,
                style: EzyTextStyles.body.copyWith(
                  color: surfaces.textSecondary,
                ),
              )
            else
              for (int i = 0; i < products.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: 10),
                _LowStockRow(product: products[i]),
              ],
          ],
        ),
      ),
    );
  }
}

/// KPI de stock: número y etiqueta con el color de su severidad.
class _StockKpi extends StatelessWidget {
  const _StockKpi({
    required this.severity,
    required this.value,
    required this.label,
  });

  final EzySeverity severity;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: StatusPalette.soft(severity),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StatusPalette.border(severity)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            style: EzyTextStyles.moneyMedium.copyWith(
              color: StatusPalette.text(context, severity),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de bajo stock: artículo y, a la derecha, «2 de 5» (actual / mínimo).
class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.product});

  final LowStockProduct product;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final severity = product.isOutOfStock
        ? EzySeverity.danger
        : EzySeverity.warn;
    final sku = product.sku;

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (sku != null && sku.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  sku,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.secondary.copyWith(
                    color: surfaces.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          DashboardLabels.stockOf(
            Money.formatQuantity(product.currentStock),
            Money.formatQuantity(product.minStock),
          ),
          style: EzyTextStyles.moneyList.copyWith(
            color: StatusPalette.text(context, severity),
          ),
        ),
      ],
    );
  }
}

/// Órdenes de servicio por estatus.
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
          : Icon(Icons.chevron_right, size: 18, color: surfaces.textMuted),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            DashboardLabels.serviceOrdersTotal(summary.total),
            style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final status in ServiceOrdersSummary.statusKeys)
            _ServiceStatusRow(
              status: status,
              count: summary.countFor(status),
              total: summary.total,
            ),
        ],
      ),
    );
  }
}

/// Fila de estatus de una orden: badge del estatus, conteo y su parte del total.
class _ServiceStatusRow extends StatelessWidget {
  const _ServiceStatusRow({
    required this.status,
    required this.count,
    required this.total,
  });

  /// Llave del enum que envía el servidor (`pendiente`, `en_progreso`, …).
  final String status;

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final severity = StatusCatalog.serviceOrderSeverity(status);
    final factor = total <= 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    final hasOrders = count > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StatusBadge.serviceOrder(status),
              const Spacer(),
              Text(
                '$count',
                style: EzyTextStyles.moneyList.copyWith(
                  color: hasOrders ? surfaces.textPrimary : surfaces.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: factor.toDouble(),
              minHeight: 4,
              backgroundColor: surfaces.panelInner,
              valueColor: AlwaysStoppedAnimation<Color>(
                StatusPalette.base(severity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra de caja flotante: el estado del turno del usuario (viaja **siempre**).
///
/// Es el último bloque del inicio y vive sobre la lista, en el borde inferior: el
/// turno se consulta de un vistazo y «Ver caja» siempre está bajo el pulgar. Sin
/// turno abierto no rompe nada: ofrece «Abrir caja» y explica por qué hace falta
/// antes de cobrar.
class DashboardCashBar extends StatelessWidget {
  const DashboardCashBar({super.key, required this.state, this.onTap});

  final CashRegisterState state;

  /// Abre la pestaña Caja (ahí se abre el turno).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    // Sin `has_open_session` no hay turno, aunque el payload traiga una sesión:
    // el flag del servidor manda.
    final session = state.hasOpenSession ? state.session : null;
    final isOpen = session != null;
    final tone = isOpen ? EzySeverity.success : EzySeverity.warn;

    return _GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(16),
      glow: StatusPalette.base(tone),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                DashboardLabels.cashTitle.toUpperCase(),
                style: EzyTextStyles.microLabel.copyWith(
                  color: surfaces.textBody,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: StatusBadge(
                  label: isOpen
                      ? DashboardLabels.cashOpenStatus
                      : DashboardLabels.cashClosedStatus,
                  severity: tone,
                  showDot: isOpen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (session != null) ...<Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        session.cashRegisterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.bodyStrong.copyWith(
                          color: surfaces.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DashboardLabels.cashOpenedAt(
                          AppFormatters.time(session.openedAt),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.secondary.copyWith(
                          color: surfaces.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                EzyAmount(
                  value: session.totals.total,
                  label: DashboardLabels.cashTotal,
                  size: EzyAmountSize.large,
                  alignment: CrossAxisAlignment.end,
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
          ] else
            Text(
              DashboardLabels.cashEmptyHint,
              style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
            ),
          const SizedBox(height: 14),
          EzyButton(
            label: isOpen
                ? DashboardLabels.cashViewAction
                : DashboardLabels.cashOpenAction,
            onPressed: onTap,
            icon: isOpen ? Icons.point_of_sale_outlined : Icons.lock_open,
          ),
        ],
      ),
    );
  }
}
