import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../sales/data/models/transaction_detail.dart';
import '../../data/models/service_order_detail.dart';

/// Panel financiero de la orden: subtotal, descuento, total, pagado y saldo.
///
/// La comisión del técnico y la utilidad solo se muestran con
/// `services.orders.see_financial_info` (§8.5).
class ServiceOrderAmountsCard extends StatelessWidget {
  const ServiceOrderAmountsCard({
    super.key,
    required this.detail,
    required this.canSeeFinancialInfo,
  });

  final ServiceOrderDetail detail;
  final bool canSeeFinancialInfo;

  @override
  Widget build(BuildContext context) {
    final pending = detail.pendingAmount;

    return SectionCard(
      title: 'Resumen de la orden',
      child: Column(
        children: <Widget>[
          SectionRow(label: 'Subtotal', value: Money.format(detail.subtotal)),
          if (detail.discountAmount > 0)
            SectionRow(
              label: detail.discountType == 'percentage'
                  ? 'Descuento (${Money.formatQuantity(detail.discountValue)} %)'
                  : 'Descuento',
              value: '- ${Money.format(detail.discountAmount)}',
              valueStyle: EzyTextStyles.moneyList.copyWith(
                color: StatusPalette.text(context, EzySeverity.danger),
              ),
            ),
          const Divider(height: 20),
          SectionRow(
            label: 'Total de la orden',
            value: Money.format(detail.finalTotal),
            emphasized: true,
          ),
          SectionRow(label: 'Pagado', value: Money.format(detail.totalPaid)),
          if (pending > 0.01)
            SectionRow(
              label: 'Saldo pendiente',
              value: Money.format(pending),
              emphasized: true,
              valueStyle: EzyTextStyles.moneyMedium.copyWith(
                color: StatusPalette.text(context, EzySeverity.warn),
              ),
            ),
          if (canSeeFinancialInfo && detail.hasTechnician) ...<Widget>[
            const Divider(height: 20),
            SectionRow(
              label: 'Refacciones',
              value: Money.format(detail.partsCost),
            ),
            SectionRow(
              label: 'Comisión del técnico',
              value: Money.format(detail.technicianCommission),
            ),
            SectionRow(
              label: 'Utilidad neta',
              value: Money.format(detail.netProfit),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ventas y anticipos de la orden (`transaction` + `payments`).
class ServiceOrderPaymentsCard extends StatelessWidget {
  const ServiceOrderPaymentsCard({super.key, required this.detail});

  final ServiceOrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final transaction = detail.transaction;

    if (transaction == null) {
      return const SectionCard(
        title: 'Anticipos y pagos',
        child: NoticeBanner(
          message:
              'Esta orden no tiene venta vinculada: al cobrar se creará '
              'automáticamente.',
          tone: EzySeverity.info,
        ),
      );
    }

    return SectionCard(
      title: 'Anticipos y pagos',
      trailing: StatusBadge.transaction(transaction.status),
      child: Column(
        children: <Widget>[
          SectionRow(label: 'Venta', value: transaction.folio),
          SectionRow(
            label: 'Total de la venta',
            value: Money.format(transaction.total),
          ),
          SectionRow(
            label: 'Pagado',
            value: Money.format(transaction.totalPaid),
          ),
          if (transaction.remainingDue > 0.01)
            SectionRow(
              label: 'Saldo',
              value: Money.format(transaction.remainingDue),
            ),
          if (transaction.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Aún no hay anticipos registrados.',
                style: EzyTextStyles.body.copyWith(color: surfaces.textMuted),
              ),
            )
          else
            for (final payment in transaction.payments) ...<Widget>[
              const Divider(height: 24),
              _PaymentRow(payment: payment),
            ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final TransactionPayment payment;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                payment.methodLabel,
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ),
            Text(
              Money.format(payment.amount),
              style: EzyTextStyles.moneyList.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          <String>[
            AppFormatters.dateTime(payment.paymentDate),
            if (payment.bankAccount != null) payment.bankAccount!.label,
          ].join(' · '),
          style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
        ),
      ],
    );
  }
}
