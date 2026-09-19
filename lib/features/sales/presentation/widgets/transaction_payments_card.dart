import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/sales_controller.dart';
import '../../data/models/transaction_detail.dart';
import 'edit_payment_sheet.dart';

/// Pagos realizados de la venta, con edición y borrado cuando el usuario tiene
/// `transactions.edit_payment` y la venta no está anulada.
class TransactionPaymentsCard extends ConsumerWidget {
  const TransactionPaymentsCard({super.key, required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final canEdit =
        ref.watch(permissionsProvider).can('transactions.edit_payment') &&
        detail.canEditPayments;

    return SectionCard(
      title: 'Pagos realizados',
      trailing: Text(
        detail.payments.isEmpty ? '—' : Money.format(detail.paidAmount),
        style: EzyTextStyles.moneyList.copyWith(color: surfaces.textPrimary),
      ),
      child: detail.payments.isEmpty
          ? const NoticeBanner(
              message: 'No se han registrado pagos en esta venta.',
              tone: EzySeverity.info,
            )
          : Column(
              children: <Widget>[
                for (final payment in detail.payments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TransactionPaymentRow(
                      payment: payment,
                      canEdit: canEdit,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Un pago de la venta (método, fecha, cuenta, monto y acciones).
class TransactionPaymentRow extends ConsumerWidget {
  const TransactionPaymentRow({
    super.key,
    required this.payment,
    required this.canEdit,
  });

  final TransactionPayment payment;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final tone = payment.isRefund ? EzySeverity.danger : EzySeverity.success;
    final color = StatusPalette.text(context, tone);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
      ),
      child: Column(
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
                payment.isRefund
                    ? '-${Money.format(payment.amount.abs())}'
                    : '+${Money.format(payment.amount)}',
                style: EzyTextStyles.moneyList.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.dateTime(payment.paymentDate),
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          if (payment.bankAccount != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                payment.bankAccount!.label,
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ),
          if (payment.notes != null && payment.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                payment.notes!,
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
            ),
          if (canEdit) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Editar pago',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      showEditPaymentSheet(context, payment: payment),
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: surfaces.textMuted,
                  ),
                ),
                IconButton(
                  tooltip: 'Eliminar pago',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context, ref),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: EzyColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Confirmación explícita antes de borrar (§12).
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar pago'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este pago permanentemente?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar pago'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref
          .read(transactionDetailControllerProvider.notifier)
          .deletePayment(payment.id);
    }
  }
}
