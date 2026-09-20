import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../printing/data/models/print_document.dart';
import '../../../printing/presentation/widgets/print_actions_panel.dart';
import '../../data/models/sales_mutation_results.dart';

/// Ticket de abono tal como lo devolvió el servidor (`print.payload`).
///
/// Los montos llegan formateados: se muestran tal cual. Desde aquí se imprime
/// el ticket de la venta o se envía el abono por WhatsApp.
class AbonoTicketView extends StatelessWidget {
  const AbonoTicketView({super.key, required this.receipt, required this.onDone});

  final AbonoReceipt receipt;
  final VoidCallback onDone;

  /// El abono a una venta se imprime desde la venta; el abono general, desde la
  /// ficha del cliente (mismo criterio que la web en `PrintModal`).
  static PrintDocument _printDocument(AbonoReceipt receipt) {
    final transactionId = receipt.transactionId;

    if (transactionId != null && transactionId > 0) {
      return PrintDocument.sale(
        transactionId: transactionId,
        title: 'Ticket de la venta abonada',
        subtitle: receipt.ticket.folio,
      );
    }

    return PrintDocument.customerAccount(
      customerId: receipt.customerId ?? 0,
      name: receipt.ticket.customer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final ticket = receipt.ticket;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: 'Ticket de abono',
          trailing: StatusBadge(
            label: ticket.liquidated ? 'Liquidada' : 'Con saldo',
            severity: ticket.liquidated
                ? EzySeverity.success
                : EzySeverity.warn,
            showDot: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (ticket.businessName.isNotEmpty)
                Text(
                  ticket.businessName,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    color: surfaces.textPrimary,
                  ),
                ),
              Text(
                ticket.folio,
                style: EzyTextStyles.moneyLarge.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
              if (ticket.date != null)
                Text(
                  ticket.date!,
                  style: EzyTextStyles.secondary.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              const SizedBox(height: 12),
              SectionRow(label: 'Cliente', value: ticket.customer),
              if (ticket.totalLabel != null)
                SectionRow(
                  label: 'Total de la venta',
                  value: ticket.totalLabel!,
                ),
              if (ticket.previousDue != null)
                SectionRow(label: 'Saldo anterior', value: ticket.previousDue!),
              if (ticket.abonado != null)
                SectionRow(
                  label: 'Abonado',
                  value: ticket.abonado!,
                  emphasized: true,
                  valueStyle: EzyTextStyles.moneyMedium.copyWith(
                    color: StatusPalette.text(context, EzySeverity.success),
                  ),
                ),
              if (ticket.remainingDue != null)
                SectionRow(
                  label: 'Saldo pendiente',
                  value: ticket.remainingDue!,
                ),
              if (ticket.estado != null)
                SectionRow(label: 'Estado', value: ticket.estado!),
              if (ticket.expirationDate != null)
                SectionRow(
                  label: 'Vigencia del apartado',
                  value: ticket.expirationDate!,
                ),
              if (ticket.paymentMethod != null)
                SectionRow(
                  label: 'Métodos de pago',
                  value: ticket.paymentMethod!,
                ),
              if (ticket.finalMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  ticket.finalMessage!,
                  style: EzyTextStyles.secondary.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Ticket',
          child: PrintActionsPanel(
            document: _printDocument(receipt),
            whatsAppTicket: receipt.ticket.toJson(),
            whatsAppPhone: receipt.customerPhone,
          ),
        ),
        const SizedBox(height: 16),
        EzyButton(label: 'Listo', onPressed: onDone),
      ],
    );
  }
}
