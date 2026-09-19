import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/transaction_summary.dart';
import 'sales_labels.dart';

/// Fila del historial de ventas: folio, estatus, cliente, total y saldo.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  final TransactionSummary transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: surfaces.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    transaction.folio,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.moneyList.copyWith(
                      fontSize: 16,
                      color: surfaces.textPrimary,
                    ),
                  ),
                ),
                StatusBadge.transaction(transaction.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              transaction.customerLabel,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.bodyStrong.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              <String>[
                AppFormatters.dateTime(transaction.createdAt),
                SalesLabels.lines(transaction.itemsCount),
                SalesLabels.channel(transaction.channel),
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    Money.format(transaction.total),
                    style: EzyTextStyles.moneyMedium.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                ),
                if (transaction.hasPendingBalance)
                  _PendingBadge(amount: transaction.remainingDue),
              ],
            ),
            if (transaction.layawayExpirationDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Footnote(
                  icon: Icons.event_available_outlined,
                  text: _layawayText(transaction),
                  tone: (transaction.layawayDaysLeft ?? 0) <= 3
                      ? EzySeverity.warn
                      : EzySeverity.neutral,
                ),
              ),
            if (transaction.deliveryDate != null && !transaction.isLayaway)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Footnote(
                  icon: Icons.local_shipping_outlined,
                  text:
                      'Entrega ${AppFormatters.dateTime(transaction.deliveryDate)}',
                  tone: EzySeverity.info,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Días restantes del apartado (avisa cuando está por vencer).
  static String _layawayText(TransactionSummary transaction) {
    final expires = AppFormatters.date(transaction.layawayExpirationDate);
    final days = transaction.layawayDaysLeft;

    if (days == null) {
      return 'Apartado: vence $expires';
    }

    if (days < 0) {
      return 'Apartado vencido ($expires)';
    }

    if (days == 0) {
      return 'Apartado: vence hoy ($expires)';
    }

    return 'Apartado: vence en $days día${days == 1 ? '' : 's'} ($expires)';
  }
}

/// Saldo pendiente de la venta (naranja, como en la web).
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, EzySeverity.warn);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.warn),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(EzySeverity.warn)),
      ),
      child: Text(
        'Saldo ${Money.format(amount)}',
        style: EzyTextStyles.badge.copyWith(color: color, letterSpacing: 0.4),
      ),
    );
  }
}

/// Nota al pie de la tarjeta (apartado, entrega).
class _Footnote extends StatelessWidget {
  const _Footnote({
    required this.icon,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final EzySeverity tone;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, tone);

    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
