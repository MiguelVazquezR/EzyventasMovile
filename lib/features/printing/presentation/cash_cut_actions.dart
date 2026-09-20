import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cash/data/models/closed_cash_session.dart';
import '../../auth/application/auth_controller.dart';
import '../application/printing_providers.dart';
import '../data/models/cash_cut_document.dart';
import '../data/whatsapp_message_builder.dart';
import 'widgets/whatsapp_ticket_sheet.dart';

/// Arma el documento del corte con los datos del negocio y de la sucursal.
///
/// Los montos vienen del `summary` del cierre (los calcula el servidor); aquí
/// solo se añade la cabecera del negocio, que la API no devuelve en el corte.
CashCutDocument buildCashCutDocument(
  WidgetRef ref, {
  required CloseCashSessionResult result,
}) {
  final context = ref.read(authControllerProvider).context;

  return CashCutDocument.fromCloseResult(
    result: result,
    businessName: context?.businessName ?? 'EzyVentas',
    branchName:
        context?.currentBranch?.name ?? context?.user.branch?.name ?? '—',
  );
}

/// Imprime el corte en la impresora térmica emparejada.
///
/// La API no acepta `cash_register_session` como `data_source_type`, así que el
/// ticket se genera en el teléfono con el encoder ESC/POS local (contrato §6.3).
Future<void> printCashCut(
  BuildContext context,
  WidgetRef ref, {
  required CloseCashSessionResult result,
}) async {
  final cut = buildCashCutDocument(ref, result: result);
  final printed = await ref.read(printJobProvider.notifier).printCashCut(cut);

  if (!context.mounted) {
    return;
  }

  final message = printed
      ? 'Corte enviado a la impresora.'
      : (ref.read(printJobProvider).errorMessage ??
            'No se pudo imprimir el corte.');

  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

/// Abre el corte en WhatsApp.
///
/// Sin endpoint de WhatsApp para el corte: se arma el mismo texto con
/// [WhatsAppMessageBuilder] y se abre `wa.me` para elegir el contacto.
Future<void> sendCashCutByWhatsApp(
  BuildContext context,
  WidgetRef ref, {
  required CloseCashSessionResult result,
}) {
  final cut = buildCashCutDocument(ref, result: result);

  return showWhatsAppMessageSheet(
    context,
    message: WhatsAppMessageBuilder.cashCut(cut),
    title: 'Enviar el corte por WhatsApp',
  );
}
