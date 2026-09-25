import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../application/printer_controller.dart';
import '../../data/models/print_document.dart';
import '../../data/whatsapp_message_builder.dart';
import '../print_sheet.dart';
import 'whatsapp_ticket_sheet.dart';

/// Botones de impresión y WhatsApp de un documento ya registrado.
///
/// La impresión abre la hoja de impresión (plantilla + impresora + respaldo) y
/// WhatsApp pide el ticket al servidor y abre `wa.me`.
class PrintActionsPanel extends ConsumerWidget {
  const PrintActionsPanel({
    super.key,
    required this.document,
    this.allowLabels = false,
    this.showPrinterStatus = true,
    this.buttonLabel = 'Imprimir ticket',
    this.whatsAppTicket,
    this.whatsAppPhone,
    this.whatsAppDocument,
    this.showWhatsApp = true,
  });

  final PrintDocument document;

  /// Ofrece además la impresión de etiqueta (TSPL).
  final bool allowLabels;

  /// Muestra el estado de la impresora encima de los botones.
  final bool showPrinterStatus;

  final String buttonLabel;

  /// Ticket ya devuelto por el servidor (p. ej. el de un abono): se envía tal
  /// cual, sin volver a pedirlo, para que el mensaje sea el mismo que registró
  /// la operación.
  final Map<String, dynamic>? whatsAppTicket;
  final String? whatsAppPhone;

  /// Documento del que se pide el ticket de WhatsApp cuando no es el mismo que
  /// se imprime (p. ej. la venta vinculada de una orden de servicio).
  final PrintDocument? whatsAppDocument;

  /// Oculta el envío por WhatsApp (documentos que el servidor no soporta).
  final bool showWhatsApp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final printer = ref.watch(printerControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showPrinterStatus) ...<Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: printer.isConnected
                      ? EzyColors.bluetooth.withValues(alpha: 0.16)
                      : surfaces.panelInner,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: printer.isConnected
                        ? EzyColors.bluetooth.withValues(alpha: 0.6)
                        : surfaces.border,
                  ),
                ),
                child: Icon(
                  printer.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled_outlined,
                  size: 15,
                  color: printer.isConnected
                      ? EzyColors.bluetooth
                      : surfaces.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  printer.statusLabel,
                  style: EzyTextStyles.caption.copyWith(
                    color: surfaces.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        EzyButton(
          label: buttonLabel,
          icon: Icons.print_outlined,
          onPressed: document.isValid
              ? () => showPrintSheet(
                  context,
                  document: document,
                  allowLabels: allowLabels,
                )
              : null,
        ),
        const SizedBox(height: 8),
        if (showWhatsApp)
          EzyButton(
            label: 'Enviar por WhatsApp',
            icon: Icons.chat_outlined,
            // Verde de WhatsApp: la acción se identifica con el canal.
            variant: EzyButtonVariant.whatsApp,
            onPressed: _sendByWhatsApp(context, ref),
          ),
      ],
    );
  }

  /// Envía el ticket ya devuelto por el servidor o lo pide de nuevo si no se
  /// conoce (ventas, pedidos, órdenes con venta vinculada).
  VoidCallback _sendByWhatsApp(BuildContext context, WidgetRef ref) {
    final ticket = whatsAppTicket;
    final target = whatsAppDocument ?? document;

    if (ticket == null || ticket.isEmpty) {
      return () => showPrintSheet(
        context,
        document: target,
        allowLabels: allowLabels,
        initialAction: PrintSheetAction.whatsApp,
      );
    }

    return () => showWhatsAppMessageSheet(
      context,
      message: WhatsAppMessageBuilder.build(ticket),
      phone: whatsAppPhone,
      subtitle: target.subtitle.isEmpty ? null : target.subtitle,
    );
  }
}
