import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/transaction_summary.dart';
import 'sales_labels.dart';

/// Tarjeta del historial de ventas (Tesla UI / EzyColors).
///
/// Superficie plana de radio 16, borde de 1 px y densidad alta: folio y estatus
/// arriba, cliente, metadatos (fecha · líneas · canal), separador de 1 px y la
/// fila de cierre con el total y el saldo pendiente. El naranja de marca no se
/// usa aquí: el color lo pone la paleta semántica del estatus (§7), y una venta
/// anulada tacha sus importes en peligro (§13).
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  final TransactionSummary transaction;
  final VoidCallback onTap;

  /// Radio de la tarjeta: 16 px, la medida de tarjeta del design system (§3).
  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final cancelled = transaction.isCancelled;
    final footnote = _footnoteFor(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: surfaces.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    transaction.folio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.moneyList.copyWith(
                      fontSize: 14,
                      color: cancelled
                          ? surfaces.textSecondary
                          : surfaces.textPrimary,
                      decoration: cancelled ? TextDecoration.lineThrough : null,
                      decorationColor: surfaces.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge.transaction(transaction.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              transaction.customerLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.bodyStrong.copyWith(
                fontSize: 12,
                color: surfaces.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            _MetadataRow(transaction: transaction),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: surfaces.border),
            const SizedBox(height: 12),
            _TotalRow(transaction: transaction),
            if (footnote != null) ...<Widget>[
              const SizedBox(height: 10),
              footnote,
            ],
          ],
        ),
      ),
    );
  }

  /// Nota al pie según el estado: el apartado avisa de su vencimiento y el
  /// pedido, de su fecha de entrega.
  Widget? _footnoteFor(BuildContext context) {
    if (transaction.isLayaway) {
      final overdue = (transaction.layawayDaysLeft ?? 0) < 0;
      final soon = (transaction.layawayDaysLeft ?? 99) <= 3;

      return _Footnote(
        icon: Icons.event_available_outlined,
        text: _layawayText(transaction),
        tone: overdue
            ? EzySeverity.danger
            : soon
            ? EzySeverity.warn
            : EzySeverity.neutral,
      );
    }

    if (transaction.status == 'en_ruta') {
      return const _Footnote(
        icon: Icons.local_shipping_outlined,
        text: 'En ruta de entrega',
        tone: EzySeverity.info,
      );
    }

    if (transaction.deliveryDate != null) {
      return _Footnote(
        icon: Icons.local_shipping_outlined,
        text: 'Entrega ${AppFormatters.dateTime(transaction.deliveryDate)}',
        tone: EzySeverity.info,
      );
    }

    return null;
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


/// Fecha, número de líneas y canal de la venta, en una sola línea de 11 px.
class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.transaction});

  final TransactionSummary transaction;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final style = EzyTextStyles.secondary.copyWith(
      fontSize: 11,
      color: surfaces.textSecondary,
    );

    return Row(
      children: <Widget>[
        Flexible(
          child: Text(
            <String>[
              AppFormatters.dateTime(transaction.createdAt),
              SalesLabels.lines(transaction.itemsCount),
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: 6),
        Text('·', style: style.copyWith(color: surfaces.textMuted)),
        const SizedBox(width: 6),
        Icon(
          SalesLabels.channelIcon(transaction.channel),
          size: 13,
          color: surfaces.textMuted,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            SalesLabels.channel(transaction.channel),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// Renglón de cierre: etiqueta de total (o el saldo pendiente) y el importe.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.transaction});

  final TransactionSummary transaction;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final cancelled = transaction.isCancelled;
    final danger = StatusPalette.text(context, EzySeverity.danger);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (transaction.hasPendingBalance)
          _PendingBadge(amount: transaction.remainingDue)
        else
          Text(
            'Total',
            style: EzyTextStyles.microLabel.copyWith(color: surfaces.textMuted),
          ),
        const Spacer(),
        Text(
          Money.format(transaction.total),
          style: EzyTextStyles.moneyList.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: cancelled ? danger : surfaces.textPrimary,
            decoration: cancelled ? TextDecoration.lineThrough : null,
            decorationColor: danger,
          ),
        ),
      ],
    );
  }
}

/// Saldo pendiente de la venta, con el tono de aviso de la paleta semántica.
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
        'Saldo: ${Money.format(amount)}',
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
