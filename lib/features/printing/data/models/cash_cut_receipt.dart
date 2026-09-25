import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../cash/data/models/cash_session_summary.dart';
import '../print_operations_encoder.dart';

/// Plantilla con la que el servidor armó el corte.
///
/// `id` es `null` y [builtin] `true` cuando el negocio todavía no ha creado una
/// plantilla de contexto `cash_register` y el servidor usó la incorporada
/// (contrato §6.3). En ese caso no hay `template_id` que mandar a
/// `POST /print/bluetooth-payload`: el corte se imprime con las `operations`
/// que vienen en el comprobante.
class CashCutReceiptTemplate {
  const CashCutReceiptTemplate({
    required this.id,
    required this.name,
    required this.builtin,
  });

  factory CashCutReceiptTemplate.fromJson(Map<String, dynamic> json) =>
      CashCutReceiptTemplate(
        id: JsonReader.integer(json['id']),
        name: JsonReader.stringOr(json['name'], 'Corte de caja'),
        builtin: JsonReader.boolean(json['builtin']),
      );

  /// `null` con la plantilla incorporada del servidor.
  final int? id;

  final String name;

  /// Plantilla **incorporada** del servidor (el negocio no tiene una propia).
  final bool builtin;

  /// `Corte de caja` / `Corte de caja (incorporada)`.
  String get label => builtin ? '$name (incorporada)' : name;
}

/// Turno del que se imprimió el corte (`session` del comprobante).
///
/// Ojo: aquí `cash_register` viene como **texto** (el nombre de la terminal),
/// no como el objeto de §6.2.
class CashCutReceiptSession {
  const CashCutReceiptSession({
    required this.id,
    required this.status,
    required this.openedAt,
    required this.closedAt,
    required this.cashRegisterName,
  });

  factory CashCutReceiptSession.fromJson(Map<String, dynamic> json) =>
      CashCutReceiptSession(
        id: JsonReader.integerOr(json['id'], 0),
        status: JsonReader.stringOr(json['status'], ''),
        openedAt: AppFormatters.parse(json['opened_at']),
        closedAt: AppFormatters.parse(json['closed_at']),
        cashRegisterName: JsonReader.stringOr(json['cash_register'], '—'),
      );

  final int id;

  /// `abierta` | `cerrada`.
  final String status;

  final DateTime? openedAt;
  final DateTime? closedAt;
  final String cashRegisterName;

  bool get isClosed => status == 'cerrada';

  /// `18 sep 2026, 13:00 → 18 sep 2026, 20:05` (`En curso` sin cierre).
  String get turnLabel {
    final from = openedAt == null ? '—' : AppFormatters.dateTime(openedAt);
    final to = closedAt == null ? 'En curso' : AppFormatters.dateTime(closedAt);

    return '$from → $to';
  }
}
/// `GET /cash-register-sessions/{id}/receipt` — el corte **listo para
/// reimprimir**, también el de un turno cerrado hace días (contrato §6.3).
///
/// La app **no** arma el corte: recibe las `operations` ya codificadas por el
/// servidor (mismo formato que §10) y solo las manda a la impresora. Este objeto
/// es también la fuente del texto que se comparte por WhatsApp.
class CashCutReceipt {
  const CashCutReceipt({
    required this.session,
    required this.summary,
    required this.template,
    required this.operations,
    required this.unsupportedOperations,
    required this.warnings,
    required this.paperWidth,
    required this.feedLines,
  });

  factory CashCutReceipt.fromJson(Map<String, dynamic> json) {
    final summary = JsonReader.toMap(json['summary']);

    return CashCutReceipt(
      session: CashCutReceiptSession.fromJson(
        JsonReader.toMap(json['session']),
      ),
      summary: summary.isEmpty ? null : CashSessionSummary.fromJson(summary),
      template: CashCutReceiptTemplate.fromJson(
        JsonReader.toMap(json['template']),
      ),
      operations: JsonReader.toMapList(json['operations']),
      unsupportedOperations: JsonReader.stringList(
        json['unsupported_operations'],
      ),
      warnings: JsonReader.stringList(json['warnings']),
      paperWidth: JsonReader.stringOr(json['paperWidth'], '80mm'),
      feedLines: JsonReader.integerOr(json['feedLines'], 0),
    );
  }

  final CashCutReceiptSession session;

  /// Cifras del turno (§6.2), con los valores congelados del cierre.
  final CashSessionSummary? summary;

  final CashCutReceiptTemplate template;

  /// Operaciones que entiende el plugin de impresión (§10): en un ticket son
  /// `TextoSegunPaginaDeCodigos` con los bytes ESC/POS ya armados.
  final List<Map<String, dynamic>> operations;

  /// Lo que el servidor **no** pudo resolver (p. ej. una imagen de la
  /// plantilla). El corte llega igual, sin ese elemento.
  final List<String> unsupportedOperations;

  /// Ajustes que hizo el servidor (p. ej. el código de barras relleno).
  final List<String> warnings;

  final String paperWidth;
  final int feedLines;

  /// Las operaciones ya traducidas a bytes (y su texto legible). Es lo que se
  /// manda a la impresora tal cual.
  EncodedPrintOperations get encoded =>
      PrintOperationsEncoder.encode(operations);

  /// Texto del corte sin comandos (para previsualizar o compartir).
  String get text => encoded.text;

  /// Bytes ESC/POS del corte.
  ///
  /// Los mismos que armó el servidor: la app solo agrega la selección de tabla
  /// de códigos antes del texto.
  List<int> get bytes => encoded.bytes;

  /// `true` si el servidor reportó algo que el usuario debe saber.
  bool get hasWarnings =>
      unsupportedOperations.isNotEmpty ||
      warnings.isNotEmpty ||
      encoded.ignored.isNotEmpty;

  /// Aviso en español con lo que reportó el servidor o con lo que el teléfono
  /// no pudo emitir (`null` si todo salió bien).
  String? get warningNotice {
    if (!hasWarnings) {
      return null;
    }

    final parts = <String>[
      if (unsupportedOperations.isNotEmpty)
        'El servidor no pudo incluir: ${unsupportedOperations.join('; ')}.',
      ...warnings,
      if (encoded.ignored.isNotEmpty)
        'La plantilla trae ${encoded.ignored.join(', ')}, que el teléfono no '
            'imprime.',
    ];

    return '${parts.join(' ')} El corte salió con lo que sí se pudo resolver.';
  }

  /// `#41 · Caja 1` para la cabecera del aviso.
  String get label => '#${session.id} · ${session.cashRegisterName}';
}

