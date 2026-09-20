import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/service_order_summary.dart';
import 'service_order_labels.dart';

/// Tarjeta del listado de órdenes: folio, estatus, cliente, equipo, promesa de
/// entrega y saldo pendiente.
class ServiceOrderTile extends StatelessWidget {
  const ServiceOrderTile({
    super.key,
    required this.serviceOrder,
    required this.onTap,
  });

  final ServiceOrderSummary serviceOrder;
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
                    serviceOrder.folio,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.moneyList.copyWith(
                      fontSize: 16,
                      color: surfaces.textPrimary,
                    ),
                  ),
                ),
                StatusBadge.serviceOrder(serviceOrder.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              serviceOrder.customerLabel,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.bodyStrong.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              serviceOrder.itemDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              <String>[
                ServiceOrderLabels.received(serviceOrder.receivedAt),
                if (serviceOrder.technicianName != null)
                  serviceOrder.technicianName!,
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    Money.format(serviceOrder.finalTotal),
                    style: EzyTextStyles.moneyMedium.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                ),
                if (serviceOrder.hasPendingAmount)
                  _PendingBadge(amount: serviceOrder.amountDue),
              ],
            ),
            if (serviceOrder.promisedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Footnote(
                  icon: Icons.event_available_outlined,
                  text: ServiceOrderLabels.promised(
                    serviceOrder.promisedAt,
                    serviceOrder.promiseDaysLeft,
                  ),
                  tone: serviceOrder.isPromiseLate
                      ? EzySeverity.danger
                      : EzySeverity.info,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Saldo pendiente de la orden (naranja, como en la web).
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

/// Nota al pie de la tarjeta (promesa de entrega).
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
