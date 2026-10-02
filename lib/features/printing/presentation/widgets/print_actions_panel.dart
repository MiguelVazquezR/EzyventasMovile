import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../application/printer_controller.dart';
import '../../application/printing_providers.dart';
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
    this.requirePrinterConnection = false,
  });

  final PrintDocument document;

  /// Ofrece además la impresión de etiqueta (TSPL).
  final bool allowLabels;

  /// Muestra el estado de la impresora encima de los botones.
  final bool showPrinterStatus;

  final String buttonLabel;

  /// El botón de imprimir se apaga también cuando la impresora no está
  /// conectada (resultado del cobro: sin dispositivo listo no hay nada que
  /// enviar). Por defecto `false`: en el resto de pantallas el botón sigue
  /// abriendo la hoja de impresión para poder elegir o conectar la impresora.
  final bool requirePrinterConnection;

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
    final printer = ref.watch(printerControllerProvider);
    final job = ref.watch(printJobProvider);
    // Sin documento válido o con un trabajo en curso no hay nada que imprimir;
    // con el cobro recién registrado tampoco sin la impresora conectada.
    final canPrint =
        document.isValid &&
        !job.isBusy &&
        (!requirePrinterConnection || printer.isConnected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showPrinterStatus) ...<Widget>[
          _PrinterStatusPanel(printer: printer),
          const SizedBox(height: 12),
        ],
        // Mismos botones que el pie de la hoja de impresión: el naranja de
        // marca para imprimir y la variante de WhatsApp para el canal.
        EzyButton(
          label: buttonLabel,
          icon: Icons.print_outlined,
          onPressed: canPrint
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

/// Fila de estado de la impresora: círculo, etiqueta y badge de conexión.
class _PrinterStatusPanel extends StatelessWidget {
  const _PrinterStatusPanel({required this.printer});

  final PrinterState printer;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final connected = printer.isConnected;
    final accent = EzyColors.bluetooth;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connected
              ? accent.withValues(alpha: 0.45)
              : surfaces.borderStrong,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: connected
                  ? accent.withValues(alpha: 0.16)
                  : surfaces.panel,
              shape: BoxShape.circle,
              border: Border.all(
                color: connected
                    ? accent.withValues(alpha: 0.6)
                    : surfaces.border,
              ),
            ),
            child: Icon(
              connected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled_outlined,
              size: 15,
              color: connected ? accent : surfaces.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  connected
                      ? 'Impresora Bluetooth lista'
                      : 'Impresora Bluetooth desconectada',
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: connected
                        ? surfaces.textPrimary
                        : surfaces.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  printer.statusLabel,
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    color: surfaces.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PrinterStatusBadge(connected: connected),
        ],
      ),
    );
  }
}

/// Badge «Conectada» en azul Bluetooth (apagado cuando no hay impresora).
class _PrinterStatusBadge extends StatelessWidget {
  const _PrinterStatusBadge({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final accent = EzyColors.bluetooth;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: connected ? accent.withValues(alpha: 0.12) : surfaces.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: connected ? accent.withValues(alpha: 0.35) : surfaces.border,
        ),
      ),
      child: Text(
        connected ? 'Conectada' : 'Sin conexión',
        style: EzyTextStyles.badge.copyWith(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: connected ? accent : surfaces.textMuted,
        ),
      ),
    );
  }
}
