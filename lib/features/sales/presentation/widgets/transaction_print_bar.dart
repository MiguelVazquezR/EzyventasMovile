import 'package:flutter/material.dart';

import '../../../printing/data/models/print_document.dart';
import '../../../printing/presentation/widgets/print_actions_panel.dart';
import '../../data/models/transaction_detail.dart';

/// Impresión y WhatsApp del ticket de la venta (o del pedido).
///
/// La venta ya está registrada: el servidor arma el documento con la plantilla
/// del negocio, así que aquí solo se elige y se envía.
class TransactionPrintBar extends StatelessWidget {
  const TransactionPrintBar({super.key, required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context) {
    return PrintActionsPanel(
      document: PrintDocument.sale(
        transactionId: detail.id,
        title: detail.isOrder ? 'Ticket del pedido' : 'Ticket de venta',
        subtitle: detail.folio,
      ),
      buttonLabel: detail.isOrder ? 'Imprimir pedido' : 'Imprimir ticket',
    );
  }
}
