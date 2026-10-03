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
/// Se pinta como el comprobante que se entrega al cliente: cabecera centrada,
/// separadores punteados, el abono en cifras grandes y el estado del adeudo en
/// un badge («Liquidada» / «Con saldo»). Los montos llegan formateados: se
/// muestran tal cual, nunca se reformatean.
///
/// La impresión (plantilla del negocio, 58 mm u 80 mm) y el WhatsApp viven en
/// [PrintActionsPanel]: esta vista solo los viste, igual que el resultado de
/// venta del POS.
class AbonoTicketView extends StatelessWidget {
  const AbonoTicketView({
    super.key,
    required this.receipt,
    required this.onDone,
    this.showDoneButton = true,
  });

  final AbonoReceipt receipt;

  /// Se llama al confirmar el comprobante («Listo»).
  final VoidCallback onDone;

  /// La hoja que aloja el ticket puede preferir su propio pie fijo; en ese caso
  /// solo se pinta el comprobante y sus dos acciones.
  final bool showDoneButton;

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
    final liquidated = ticket.liquidated;
    // El abono es el protagonista del comprobante: en verde cuando liquidó la
    // cuenta y en el tono alto cuando todavía queda saldo.
    final amountColor = liquidated
        ? StatusPalette.text(context, EzySeverity.success)
        : surfaces.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: 'Ticket de abono',
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (ticket.businessName.isNotEmpty) ...<Widget>[
                Text(
                  ticket.businessName.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: EzyTextStyles.cardTitle.copyWith(
                    color: surfaces.textPrimary,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                ticket.folio,
                textAlign: TextAlign.center,
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
              if (ticket.date != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  ticket.date!,
                  textAlign: TextAlign.center,
                  style: EzyTextStyles.caption.copyWith(
                    color: surfaces.textMuted,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const _DashedDivider(),
              const SizedBox(height: 18),
              Text(
                'ABONADO',
                textAlign: TextAlign.center,
                style: EzyTextStyles.microLabel.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              // El monto llega formateado por el servidor y con su moneda: solo
              // se encoge si el importe es muy largo (`$12,345.67 MXN`).
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  ticket.abonado ?? ticket.totalLabel ?? '',
                  style: EzyTextStyles.moneyLarge.copyWith(color: amountColor),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: StatusBadge(
                  label: liquidated ? 'Liquidada' : 'Con saldo',
                  severity: liquidated
                      ? EzySeverity.success
                      : EzySeverity.warn,
                  // Punto pulsante solo mientras quede adeudo: el comprobante de
                  // una cuenta liquidada ya está cerrado.
                  showDot: !liquidated,
                ),
              ),
              const SizedBox(height: 18),
              const _DashedDivider(),
              const SizedBox(height: 10),
              SectionRow(label: 'Cliente', value: ticket.customer),
              if (ticket.totalLabel != null)
                SectionRow(
                  label: ticket.isOrderPayment
                      ? 'Total del pedido'
                      : 'Total de la venta',
                  value: ticket.totalLabel!,
                ),
              if (ticket.previousDue != null)
                SectionRow(label: 'Saldo anterior', value: ticket.previousDue!),
              if (ticket.remainingDue != null)
                SectionRow(
                  label: 'Saldo pendiente',
                  value: ticket.remainingDue!,
                  // El saldo pendiente solo se destaca si la cuenta sigue viva.
                  emphasized: !liquidated,
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
                const SizedBox(height: 14),
                const _DashedDivider(),
                const SizedBox(height: 12),
                Text(
                  ticket.finalMessage!,
                  textAlign: TextAlign.center,
                  style: EzyTextStyles.secondary.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // La misma tarjeta de acciones que el resultado de venta del POS.
        SectionCard(
          title: 'Acciones de ticket',
          child: PrintActionsPanel(
            document: _printDocument(receipt),
            whatsAppTicket: ticket.toJson(),
            whatsAppPhone: receipt.customerPhone,
          ),
        ),
        if (showDoneButton) ...<Widget>[
          const SizedBox(height: 16),
          EzyButton(label: 'Listo', onPressed: onDone),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Separador punteado del comprobante: el mismo trazo del ticket térmico.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashedLinePainter(color: surfaces.borderStrong),
      ),
    );
  }
}

/// Trazo discontinuo de 1 px: guiones de 4 px con 4 px de separación.
class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  static const double _dash = 4;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += _dash + _gap) {
      final end = x + _dash > size.width ? size.width : x + _dash;
      canvas.drawLine(Offset(x, 0), Offset(end, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
