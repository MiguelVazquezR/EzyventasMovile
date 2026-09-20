import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../application/sales_controller.dart';
import '../../data/models/transaction_detail.dart';
import 'sales_labels.dart';
import 'transaction_actions.dart';
import 'transaction_payments_card.dart';
import 'transaction_print_bar.dart';

/// Detalle completo de una venta: ítems, pagos, totales y acciones.
Future<void> showTransactionDetailSheet(
  BuildContext context, {
  required int transactionId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        _TransactionDetailSheet(transactionId: transactionId),
  );
}

class _TransactionDetailSheet extends ConsumerStatefulWidget {
  const _TransactionDetailSheet({required this.transactionId});

  final int transactionId;

  @override
  ConsumerState<_TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<_TransactionDetailSheet> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(transactionDetailControllerProvider.notifier)
          .load(widget.transactionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionDetailControllerProvider);
    final controller = ref.read(transactionDetailControllerProvider.notifier);
    final detail = state.belongsTo(widget.transactionId) ? state.detail : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          if (detail == null)
            ..._loadingChildren(state.errorMessage, controller)
          else ...<Widget>[
            _DetailHeader(
              detail: detail,
              onRefresh: controller.refresh,
              onClose: () => Navigator.of(context).pop(),
            ),
            if (state.notice != null) ...<Widget>[
              const SizedBox(height: 12),
              NoticeBanner(
                message: state.notice!,
                tone: EzySeverity.success,
                icon: Icons.check_circle_outline,
                actionLabel: 'Ocultar',
                onAction: controller.consumeNotice,
              ),
            ],
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              NoticeBanner(
                message: state.errorMessage!,
                actionLabel: 'Ocultar',
                onAction: controller.consumeError,
              ),
            ],
            const SizedBox(height: 16),
            TransactionActionBar(detail: detail),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Ticket',
              child: TransactionPrintBar(detail: detail),
            ),
            const SizedBox(height: 16),
            _ClientCard(detail: detail),
            const SizedBox(height: 12),
            TransactionItemsCard(items: detail.items),
            const SizedBox(height: 12),
            TransactionAmountsCard(detail: detail),
            const SizedBox(height: 12),
            TransactionPaymentsCard(detail: detail),
            if (detail.invoice != null) ...<Widget>[
              const SizedBox(height: 12),
              SectionCard(
                title: 'Factura',
                child: Column(
                  children: <Widget>[
                    SectionRow(label: 'Folio', value: detail.invoice!.folio),
                    SectionRow(label: 'Estatus', value: detail.invoice!.status),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _InfoCard(detail: detail),
            const SizedBox(height: 12),
            const NoticeBanner(
              message:
                  'El ticket de esta venta se podrá imprimir o enviar por '
                  'WhatsApp cuando se habilite la impresión.',
              tone: EzySeverity.info,
            ),
          ],
        ],
      ),
    );
  }

  /// Estado de carga: spinner y, si falló, el `message` del servidor.
  List<Widget> _loadingChildren(
    String? errorMessage,
    TransactionDetailController controller,
  ) {
    return <Widget>[
      const SizedBox(height: 48),
      const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      if (errorMessage != null) ...<Widget>[
        const SizedBox(height: 20),
        ErrorNotice(message: errorMessage, onRetry: controller.refresh),
      ],
    ];
  }
}

/// Cabecera del detalle: folio, estatus, fecha y canal.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.detail,
    required this.onRefresh,
    required this.onClose,
  });

  final TransactionDetail detail;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    detail.folio,
                    style: EzyTextStyles.moneyLarge.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusBadge.transaction(
                    detail.status,
                    showDot: !detail.isCancelled,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: onRefresh,
              icon: Icon(Icons.refresh, size: 20, color: surfaces.textMuted),
            ),
            IconButton(
              tooltip: 'Cerrar',
              onPressed: onClose,
              icon: Icon(Icons.close, size: 20, color: surfaces.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${AppFormatters.dateTime(detail.createdAt)} · '
          '${SalesLabels.channel(detail.channel)}',
          style: EzyTextStyles.secondary.copyWith(
            color: surfaces.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Cliente de la venta con su saldo y límite de crédito.
class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context) {
    final customer = detail.customer;
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Cliente',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            detail.customerLabel,
            style: EzyTextStyles.bodyStrong.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          if (customer == null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Venta de público general.',
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 8),
            SectionRow(
              label: customer.hasBalanceInFavor
                  ? 'Saldo a favor'
                  : (customer.hasDebt ? 'Deuda' : 'Saldo'),
              value: Money.format(customer.balance.abs()),
              valueStyle: EzyTextStyles.moneyList.copyWith(
                color: customer.hasDebt
                    ? StatusPalette.text(context, EzySeverity.warn)
                    : surfaces.textPrimary,
              ),
            ),
            SectionRow(
              label: 'Límite de crédito',
              value: Money.format(customer.creditLimit),
            ),
          ],
        ],
      ),
    );
  }
}

/// Líneas de la venta con su precio, descuento e importe.
class TransactionItemsCard extends StatelessWidget {
  const TransactionItemsCard({super.key, required this.items});

  final List<TransactionItem> items;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Artículos',
      trailing: Text(
        items.isEmpty
            ? '—'
            : '${items.length} línea${items.length == 1 ? '' : 's'}',
        style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
      ),
      child: Column(
        children: <Widget>[
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == items.length - 1 ? 0 : 14,
              ),
              child: _ItemRow(item: items[index]),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final TransactionItem item;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                item.description,
                style: EzyTextStyles.body.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              Money.format(item.lineTotal),
              style: EzyTextStyles.moneyList.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${Money.formatQuantity(item.quantity)} × '
          '${Money.format(item.unitPrice)}',
          style: EzyTextStyles.secondary.copyWith(
            color: surfaces.textSecondary,
          ),
        ),
        if (item.hasDiscount)
          Text(
            item.isIncrease
                ? 'Aumento ${Money.format(item.discountAmount)} · '
                      '${item.discountReason ?? ''}'
                : 'Descuento ${Money.format(item.discountAmount)} · '
                      '${item.discountReason ?? ''}',
            style: EzyTextStyles.caption.copyWith(
              color: item.isIncrease
                  ? surfaces.textSecondary
                  : StatusPalette.text(context, EzySeverity.warn),
            ),
          ),
      ],
    );
  }
}

/// Totales y saldo pendiente de la venta.
class TransactionAmountsCard extends StatelessWidget {
  const TransactionAmountsCard({super.key, required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context) {
    final isPaid = detail.isPaid;

    return SectionCard(
      title: 'Totales',
      trailing: Text(
        isPaid ? 'Pagada' : 'Con saldo',
        style: EzyTextStyles.badge.copyWith(
          color: StatusPalette.text(
            context,
            isPaid ? EzySeverity.success : EzySeverity.warn,
          ),
          letterSpacing: 1.2,
        ),
      ),
      child: Column(
        children: <Widget>[
          SectionRow(
            label: 'Subtotal',
            value: Money.format(detail.subtotal),
          ),
          if (detail.totalDiscount != 0)
            SectionRow(
              label: 'Descuento',
              value: '-${Money.format(detail.totalDiscount)}',
            ),
          if (detail.shippingCost != 0)
            SectionRow(label: 'Envío', value: Money.format(detail.shippingCost)),
          if (detail.totalTax != 0)
            SectionRow(
              label: 'Impuesto',
              value: Money.format(detail.totalTax),
            ),
          const Divider(height: 20),
          SectionRow(
            label: 'Total',
            value: Money.format(detail.total),
            emphasized: true,
          ),
          SectionRow(
            label: 'Pagado',
            value: Money.format(detail.paidAmount),
          ),
          if (!isPaid)
            SectionRow(
              label: 'Saldo pendiente',
              value: Money.format(detail.pendingBalance),
              emphasized: true,
              valueStyle: EzyTextStyles.moneyMedium.copyWith(
                color: StatusPalette.text(context, EzySeverity.warn),
              ),
            ),
        ],
      ),
    );
  }
}

/// Información operativa de la venta (sucursal, cajero, fechas, notas).
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;

    return SectionCard(
      title: 'Información de la venta',
      child: Column(
        children: <Widget>[
          if (detail.branch != null)
            SectionRow(label: 'Sucursal', value: detail.branch!.name),
          if (summary.user != null)
            SectionRow(label: 'Registró', value: summary.user!.name),
          SectionRow(label: 'Canal', value: SalesLabels.channel(detail.channel)),
          if (detail.cashRegisterSessionId != null)
            SectionRow(
              label: 'Sesión de caja',
              value: '#${detail.cashRegisterSessionId}',
            ),
          if (summary.contactName != null)
            SectionRow(label: 'Contacto', value: summary.contactName!),
          if (summary.contactPhone != null)
            SectionRow(label: 'Teléfono', value: summary.contactPhone!),
          if (detail.deliveryDate != null)
            SectionRow(
              label: 'Fecha de entrega',
              value: AppFormatters.dateTime(detail.deliveryDate),
            ),
          if (detail.layawayExpirationDate != null) ...<Widget>[
            SectionRow(
              label: 'Vence el apartado',
              value: AppFormatters.date(detail.layawayExpirationDate),
            ),
            if ((detail.layawayDaysLeft ?? 0) < 0)
              SectionRow(
                label: 'Días restantes',
                value: 'Vencido (${detail.layawayDaysLeft} días)',
                valueStyle: EzyTextStyles.moneyList.copyWith(
                  color: StatusPalette.text(context, EzySeverity.warn),
                ),
              )
            else
              SectionRow(
                label: 'Días restantes',
                value: '${detail.layawayDaysLeft ?? 0}',
              ),
          ],
          if (detail.shippingAddress != null)
            SectionRow(label: 'Dirección de entrega', value: detail.shippingAddress!),
          if (detail.notes != null)
            SectionRow(label: 'Notas', value: detail.notes!),
          SectionRow(
            label: 'Facturada',
            value: summary.invoiced ? 'Sí' : 'No',
          ),
        ],
      ),
    );
  }
}
