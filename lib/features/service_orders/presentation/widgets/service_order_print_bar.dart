import 'package:flutter/material.dart';

import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../printing/data/models/print_document.dart';
import '../../../printing/presentation/widgets/print_actions_panel.dart';
import '../../data/models/service_order_detail.dart';

/// Impresión de la orden y WhatsApp de su venta vinculada.
///
/// La orden sí se puede imprimir (`data_source_type: service_order`), pero
/// `POST /print/whatsapp-ticket` solo arma el ticket de una **transacción**
/// (venta o pedido): si la orden todavía no tiene venta, el envío por WhatsApp
/// se oculta y se explica cómo generarla ("Cobrar ahora").
class ServiceOrderPrintBar extends StatelessWidget {
  const ServiceOrderPrintBar({super.key, required this.detail});

  final ServiceOrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final transaction = detail.transaction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PrintActionsPanel(
          document: PrintDocument.serviceOrder(
            serviceOrderId: detail.id,
            folio: detail.folio,
          ),
          allowLabels: true,
          buttonLabel: 'Imprimir orden',
          whatsAppDocument: transaction == null
              ? null
              : PrintDocument.sale(
                  transactionId: transaction.id,
                  title: 'Venta de la orden',
                  subtitle: transaction.folio,
                ),
          showWhatsApp: transaction != null,
        ),
        if (transaction == null) ...<Widget>[
          const SizedBox(height: 12),
          const NoticeBanner(
            message:
                'La orden no tiene venta vinculada: el ticket de WhatsApp se '
                'genera con “Cobrar ahora”.',
            tone: EzySeverity.info,
            icon: Icons.info_outline,
          ),
        ],
      ],
    );
  }
}
