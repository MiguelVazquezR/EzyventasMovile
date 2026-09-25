import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../cash/application/cash_register_controller.dart';
import '../data/models/cash_cut_receipt.dart';
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
    this.isFetchingCut = false,
    this.errorMessage,
    this.notice,
    this.warningMessage,
  });

  /// Obtención del documento (o envío a la impresora) en curso.
  final bool isSubmitting;
  final bool isFetchingHtml;
  final bool isFetchingWhatsApp;
  final bool isFetchingCut;

  /// `message` del servidor o aviso local de la impresora.
  final String? errorMessage;

  /// Confirmación con el `message` del servidor.
  final String? notice;

  /// El documento se imprimió, pero el servidor (o la plantilla) reportó algo:
  /// `unsupported_operations`, `warnings` o una operación que el teléfono no
  /// puede emitir. Se muestra como aviso, nunca como éxito.
  final String? warningMessage;

  bool get isBusy =>
      isSubmitting || isFetchingHtml || isFetchingWhatsApp || isFetchingCut;

  PrintJobState copyWith({
    bool? isSubmitting,
    bool? isFetchingHtml,
    bool? isFetchingWhatsApp,
    bool? isFetchingCut,
    String? errorMessage,
    String? notice,
    String? warningMessage,
    bool clearError = false,
    bool clearNotice = false,
    bool clearWarning = false,
  }) {
    return PrintJobState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isFetchingHtml: isFetchingHtml ?? this.isFetchingHtml,
      isFetchingWhatsApp: isFetchingWhatsApp ?? this.isFetchingWhatsApp,
      isFetchingCut: isFetchingCut ?? this.isFetchingCut,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      warningMessage: clearWarning
          ? null
          : (warningMessage ?? this.warningMessage),
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

      if (printed) {
        state = state.copyWith(
          isSubmitting: false,
          clearError: true,
          clearWarning: true,
        );
      } else {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: _printerError(),
        );
      }

      return printed;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  /// Imprime una **etiqueta** (TSPL) con `POST /print/payload`.
  ///
  /// El servidor devuelve la operación `EscribirTexto` con el comando TSPL
  /// completo (imágenes ya rasterizadas como `BITMAP` y código de barras
  /// relleno) y reporta en `unsupported_operations` / `warnings` lo que no pudo
  /// resolver: se envía tal cual en UTF-8 y se avisa si viene algo.
  Future<bool> printLabel({
    required PrintDocument document,
    required int templateId,
    double offsetX = 0,
    double offsetY = 0,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearWarning: true,
    );

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

      if (printed) {
        state = state.copyWith(
          isSubmitting: false,
          clearError: true,
          warningMessage: payload.warningNotice,
        );
      } else {
        state = state.copyWith(
          isSubmitting: false,
          errorMessage: _printerError(),
        );
      }

      return printed;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  /// Imprime el **corte de caja**: pide el comprobante al servidor y manda sus
  /// `operations` tal cual (§6.3). Devuelve `false` si no se pudo traer o
  /// imprimir.
  Future<bool> printCashCut({required int sessionId, int? templateId}) async {
    final receipt = await loadCashCutReceipt(
      sessionId: sessionId,
      templateId: templateId,
    );

    if (receipt == null) {
      return false;
    }

    return printCashCutReceipt(receipt);
  }

  /// `GET /cash-register-sessions/{id}/receipt` — el corte listo para
  /// (re)imprimir. `null` si el servidor no lo devolvió.
  Future<CashCutReceipt?> loadCashCutReceipt({
    required int sessionId,
    int? templateId,
  }) async {
    state = state.copyWith(
      isFetchingCut: true,
      clearError: true,
      clearWarning: true,
    );

    try {
      final receipt = await ref
          .read(cashRegisterRepositoryProvider)
          .fetchCutReceipt(sessionId, templateId: templateId);

      state = state.copyWith(isFetchingCut: false);

      return receipt;
    } on ApiException catch (error) {
      state = state.copyWith(isFetchingCut: false, errorMessage: error.message);

      return null;
    }
  }

  /// Imprime el **corte de caja** con el comprobante del servidor.
  ///
  /// La app ya **no** arma el corte (contrato §6.3): manda las `operations` que
  /// devuelve `GET /cash-register-sessions/{id}/receipt`, tal cual. Sirve igual
  /// para el turno recién cerrado que para reimprimir el corte de un turno
  /// cerrado hace días.
  ///
  /// Si la plantilla del **negocio** trae una imagen, el teléfono no puede
  /// rasterizarla (el servidor solo la resuelve en
  /// `POST /print/bluetooth-payload`), así que con `template.id` se pide ese
  /// respaldo y, si falla, se imprime lo que sí se pudo resolver con el aviso
  /// correspondiente.
  Future<bool> printCashCutReceipt(CashCutReceipt receipt) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearWarning: true,
    );

    final encoded = receipt.encoded;

    if (encoded.isEmpty) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'El servidor no devolvió el contenido del corte.',
      );

      return false;
    }

    var bytes = encoded.bytes;
    var warning = receipt.warningNotice;

    final templateId = receipt.template.id;

    if (encoded.ignored.isNotEmpty && templateId != null) {
      final rasterized = await _rasterizedCut(receipt, templateId);

      if (rasterized != null) {
        bytes = rasterized;
        warning = receipt.warningNotice;
      }
    }

    final printed = await ref
        .read(printerControllerProvider.notifier)
        .printBytes(bytes);

    if (printed) {
      state = state.copyWith(
        isSubmitting: false,
        clearError: true,
        warningMessage: warning,
      );
    } else {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _printerError(),
      );
    }

    return printed;
  }

  /// El mismo corte por `POST /print/bluetooth-payload` (el servidor rasteriza
  /// las imágenes de la plantilla). `null` si no se pudo.
  Future<Uint8List?> _rasterizedCut(CashCutReceipt receipt, int templateId) async {
    try {
      final payload = await _repository.bluetoothPayload(
        templateId: templateId,
        source: PrintDataSourceType.cashRegisterSession,
        sourceId: receipt.session.id,
      );

      return payload.isEmpty ? null : payload.commands;
    } on ApiException {
      return null;
    }
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

  void consumeWarning() => state = state.copyWith(clearWarning: true);
}

