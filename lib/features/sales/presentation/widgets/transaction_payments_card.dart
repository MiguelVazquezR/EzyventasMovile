import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_dialog.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
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
    final canEdit =
        ref.watch(permissionsProvider).can('transactions.edit_payment') &&
        detail.canEditPayments;
    final count = detail.payments.length;

    return SectionCard(
      title: 'Pagos realizados',
      trailing: _CountTag(
        label: count == 0
            ? 'Sin registros'
            : '$count registro${count == 1 ? '' : 's'}',
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

/// Un pago de la venta (método, monto, fecha, cuenta y acciones).
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
    final applied = payment.status.trim().isEmpty
        ? 'Aplicado'
        : payment.status.trim();

    return Container(
      padding: const EdgeInsets.all(12),
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
              const SizedBox(width: 8),
              Text(
                payment.isRefund
                    ? '-${Money.format(payment.amount.abs())}'
                    : '+${Money.format(payment.amount)}',
                style: _mono(14, FontWeight.w800, color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              _AppliedTag(label: applied, severity: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppFormatters.dateTime(payment.paymentDate),
                  textAlign: TextAlign.right,
                  style: EzyTextStyles.secondary.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (payment.bankAccount != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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
                  fontStyle: FontStyle.italic,
                  color: surfaces.textMuted,
                ),
              ),
            ),
          if (canEdit) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                EzyIconButton(
                  icon: Icons.edit_outlined,
                  size: 36,
                  iconSize: 18,
                  tooltip: 'Editar pago',
                  onTap: () => showEditPaymentSheet(context, payment: payment),
                ),
                const SizedBox(width: 8),
                EzyIconButton(
                  icon: Icons.delete_outline,
                  size: 36,
                  iconSize: 18,
                  tooltip: 'Eliminar pago',
                  color: const Color(0xFFF80505),
                  onTap: () => _confirmDelete(context, ref),
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
    final confirmed = await showEzyConfirmDialog(
      context,
      title: 'Eliminar pago',
      message:
          '¿Estás seguro de que quieres eliminar este pago permanentemente?',
      confirmLabel: 'Eliminar pago',
      isDestructive: true,
    );

    if (confirmed) {
      await ref
          .read(transactionDetailControllerProvider.notifier)
          .deletePayment(payment.id);
    }
  }
}

/// Badge de estado del pago («APLICADO») con el tinte de su severidad.
class _AppliedTag extends StatelessWidget {
  const _AppliedTag({required this.label, required this.severity});

  final String label;
  final EzySeverity severity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: StatusPalette.soft(severity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(severity)),
      ),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.badge.copyWith(
          fontSize: 9.5,
          color: StatusPalette.text(context, severity),
        ),
      ),
    );
  }
}

/// Etiqueta del número de registros en la cabecera de la card.
class _CountTag extends StatelessWidget {
  const _CountTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: surfaces.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.badge.copyWith(
          fontSize: 9.5,
          color: surfaces.textMuted,
        ),
      ),
    );
  }
}

/// Monto en fuente monoespaciada con cifras tabulares.
TextStyle _mono(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: 'monospace',
  fontSize: size,
  fontWeight: weight,
  color: color,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);
