import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../data/cash_cut_renderer.dart';
import '../data/models/cash_cut_document.dart';
import '../data/models/print_document.dart';
import '../data/models/print_payloads.dart';
import '../data/models/print_template.dart';
import '../data/printing_repository.dart';
import 'printer_controller.dart';

/// Repositorio de impresión (plantillas, ESC/POS, TSPL, HTML y WhatsApp).
final printingRepositoryProvider = Provider<PrintingRepository>(
  (ref) => PrintingRepository(api: ref.watch(apiClientProvider)),
);

/// Plantillas del negocio de un tipo (la lista se cachea en el repositorio).
///
/// Se pide **sin** `context` porque la API solo filtra por uno y la web usa
/// conjuntos (`pos`+`general`, `transaction`+`general`, ...): el filtro por
/// contexto lo hace `PrintDocument.selectTemplates`.
final printTemplatesProvider =
    FutureProvider.family<List<PrintTemplate>, PrintTemplateType>(
      (ref, type) =>
          ref.watch(printingRepositoryProvider).fetchTemplates(type: type),
    );

/// Resultado del último trabajo de impresión (bytes, HTML o WhatsApp).
class PrintJobState {
  const PrintJobState({
    this.isSubmitting = false,
    this.isFetchingHtml = false,
    this.isFetchingWhatsApp = false,
    this.errorMessage,
    this.notice,
  });

  /// Obtención del documento (o envío a la impresora) en curso.
  final bool isSubmitting;
  final bool isFetchingHtml;
  final bool isFetchingWhatsApp;

  /// `message` del servidor o aviso local de la impresora.
  final String? errorMessage;
  final String? notice;

  bool get isBusy => isSubmitting || isFetchingHtml || isFetchingWhatsApp;

  PrintJobState copyWith({
    bool? isSubmitting,
    bool? isFetchingHtml,
    bool? isFetchingWhatsApp,
    String? errorMessage,
    String? notice,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return PrintJobState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isFetchingHtml: isFetchingHtml ?? this.isFetchingHtml,
      isFetchingWhatsApp: isFetchingWhatsApp ?? this.isFetchingWhatsApp,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

/// Trabajos de impresión: pide el documento al servidor y lo manda a la
/// impresora, o lo deja listo para WhatsApp / copiar.
///
/// Toda la validación de negocio (plantilla de la suscripción, documento de la
/// sucursal, permisos) la hace el servidor; aquí solo se transportan bytes.
final printJobProvider = NotifierProvider<PrintJobController, PrintJobState>(
  PrintJobController.new,
);

class PrintJobController extends Notifier<PrintJobState> {
  PrintingRepository get _repository => ref.read(printingRepositoryProvider);

  @override
  PrintJobState build() => const PrintJobState();

  /// Imprime el documento con la plantilla elegida (`print/bluetooth-payload`).
  Future<bool> printDocument({
    required PrintDocument document,
    required int templateId,
    bool openDrawer = false,
  }) async {
    if (templateId <= 0 || !document.isValid) {
      state = state.copyWith(
        errorMessage: 'Selecciona la plantilla de impresión.',
      );

      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final payload = await _repository.bluetoothPayload(
        templateId: templateId,
        source: document.source,
        sourceId: document.id,
        openDrawer: openDrawer,
      );

      if (payload.isEmpty) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: 'El servidor no devolvió el contenido del ticket.',
        );

        return false;
      }

      final printed = await ref
          .read(printerControllerProvider.notifier)
          .printBytes(payload.commands);

      state = state.copyWith(
        isSubmitting: false,
        notice: printed ? null : _printerError(),
      );

      return printed;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  /// Imprime una **etiqueta** (TSPL) con `POST /print/payload`.
  ///
  /// El servidor devuelve la operación `EscribirTexto` con el comando TSPL
  /// completo; se envía tal cual en UTF-8 (las térmicas de etiquetas aceptan el
  /// comando en texto).
  Future<bool> printLabel({
    required PrintDocument document,
    required int templateId,
    double offsetX = 0,
    double offsetY = 0,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final payload = await _repository.labelPayload(
        templateId: templateId,
        source: document.source,
        sourceId: document.id,
        offsetX: offsetX,
        offsetY: offsetY,
      );

      final tspl = payload.tsplText;

      if (tspl == null) {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage:
              'La plantilla de etiqueta no tiene contenido imprimible para '
              'esta impresora.',
        );

        return false;
      }

      final printed = await ref
          .read(printerControllerProvider.notifier)
          .printBytes(Uint8List.fromList(utf8.encode(tspl)));

      // La plantilla puede traer imágenes u operaciones que el teléfono no sabe
      // convertir a comandos: se avisa en lugar de imprimir a medias.
      final notice = printed && payload.hasUnsupportedOperations
          ? 'La etiqueta se envió, pero la plantilla incluye imágenes que no se '
                'imprimen desde el teléfono.'
          : (printed ? null : _printerError());

      state = state.copyWith(isSubmitting: false, notice: notice);

      return printed;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  /// Imprime el **corte de caja** (documento local: la API no lo soporta).
  Future<bool> printCashCut(
    CashCutDocument cut, {
    int charactersPerLine = 48,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);

    final printed = await ref
        .read(printerControllerProvider.notifier)
        .printBytes(
          CashCutRenderer.escPos(cut, charactersPerLine: charactersPerLine),
        );

    state = state.copyWith(
      isSubmitting: false,
      notice: printed ? null : _printerError(),
    );

    return printed;
  }

  /// Descarga el HTML de respaldo (para compartir sin impresora Bluetooth).
  Future<TicketHtml?> loadHtml({
    required PrintDocument document,
    required int templateId,
  }) async {
    state = state.copyWith(isFetchingHtml: true, clearError: true);

    try {
      final html = await _repository.ticketHtml(
        templateId: templateId,
        source: document.source,
        sourceId: document.id,
      );

      state = state.copyWith(isFetchingHtml: false);

      return html;
    } on ApiException catch (error) {
      state = state.copyWith(isFetchingHtml: false, errorMessage: error.message);

      return null;
    }
  }

  /// Descarga el ticket de WhatsApp (texto ya formateado por el servidor).
  Future<WhatsAppTicketResult?> loadWhatsAppTicket({
    required PrintDocument document,
  }) async {
    state = state.copyWith(isFetchingWhatsApp: true, clearError: true);

    try {
      final result = await _repository.whatsappTicket(
        source: document.source,
        sourceId: document.id,
      );

      state = state.copyWith(isFetchingWhatsApp: false);

      return result;
    } on ApiException catch (error) {
      state = state.copyWith(
        isFetchingWhatsApp: false,
        errorMessage: error.message,
      );

      return null;
    }
  }

  /// Mensaje de la impresora si el envío falló (ya está en su propio estado).
  String _printerError() =>
      ref.read(printerControllerProvider).errorMessage ??
      'No se pudo imprimir el ticket.';

  void consumeError() => state = state.copyWith(clearError: true);

  void consumeNotice() => state = state.copyWith(clearNotice: true);
}

