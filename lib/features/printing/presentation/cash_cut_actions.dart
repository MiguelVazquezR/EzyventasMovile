import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/printing_providers.dart';
import '../data/whatsapp_message_builder.dart';
import 'widgets/whatsapp_ticket_sheet.dart';

/// Imprime el **corte de caja** de un turno (abierto o cerrado hace días).
///
/// El documento lo arma el servidor: la app pide
/// `GET /cash-register-sessions/{id}/receipt` (§6.3) y manda sus `operations`
/// tal cual. Ya no hay render local del corte.
Future<void> printCashCut(
  BuildContext context,
  WidgetRef ref, {
  required int sessionId,
}) async {
  final controller = ref.read(printJobProvider.notifier);
  final printed = await controller.printCashCut(sessionId: sessionId);

  if (!context.mounted) {
    return;
  }

  final job = ref.read(printJobProvider);

  final message = printed
      ? (job.warningMessage ?? 'Corte enviado a la impresora.')
      : (job.errorMessage ?? 'No se pudo imprimir el corte.');

  _snack(context, message);
}

/// Abre el corte en WhatsApp.
///
/// No hay endpoint de WhatsApp para el corte: se comparte el texto del mismo
/// comprobante del servidor, sin armar nada en el teléfono.
Future<void> sendCashCutByWhatsApp(
  BuildContext context,
  WidgetRef ref, {
  required int sessionId,
}) async {
  final controller = ref.read(printJobProvider.notifier);
  final receipt = await controller.loadCashCutReceipt(sessionId: sessionId);

  if (!context.mounted) {
    return;
  }

  if (receipt == null) {
    _snack(
      context,
      ref.read(printJobProvider).errorMessage ?? 'No se pudo leer el corte.',
    );

    return;
  }

  await showWhatsAppMessageSheet(
    context,
    message: WhatsAppMessageBuilder.cashCutReceipt(receipt),
    title: 'Enviar el corte por WhatsApp',
  );
}

/// Aviso breve en pantalla (éxito, aviso del servidor o error).
void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

