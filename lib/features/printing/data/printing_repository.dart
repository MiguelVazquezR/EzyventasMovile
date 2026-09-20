import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import 'models/print_document.dart';
import 'models/print_payloads.dart';
import 'models/print_template.dart';

/// Filtro de `GET /print/templates` (record: igualdad estructural gratis para
/// las familias de Riverpod).
typedef PrintTemplateFilter = ({
  PrintTemplateType? type,
  PrintContextType? context,
});

/// Plantillas, ESC/POS, TSPL, HTML y WhatsApp (contrato §10).
///
/// La app **no** renderiza plantillas: pide el documento ya codificado
/// (ESC/POS en Base64, operaciones TSPL o HTML) o el ticket de texto de
/// WhatsApp. Todos los orígenes quedan limitados por el servidor a la
/// suscripción del usuario.
class PrintingRepository {
  PrintingRepository({required this.api});

  static const String _templateTextOperation = 'EscribirTexto';

  final ApiClient api;

  /// Caché en memoria de las plantillas por filtro: cambiar de plantilla o
  /// reimprimir no vuelve a pedir la lista (§10, "la app guarda esta lista").
  final Map<String, List<PrintTemplate>> _templatesCache =
      <String, List<PrintTemplate>>{};

  /// Plantillas del negocio (opcionalmente por `type` y `context`).
  Future<List<PrintTemplate>> fetchTemplates({
    PrintTemplateType? type,
    PrintContextType? context,
    bool forceRefresh = false,
  }) async {
    final key = '${type?.wire}|${context?.wire}';

    final cached = _templatesCache[key];

    if (!forceRefresh && cached != null) {
      return cached;
    }

    final data = await api.getJsonList(
      ApiEndpoints.printTemplates,
      query: <String, dynamic>{
        'type': type?.wire,
        'context': context?.wire,
      },
    );

    final templates = data
        .map(PrintTemplate.fromJson)
        .toList(growable: false);

    _templatesCache[key] = templates;

    return templates;
  }

  /// Todas las plantillas del negocio (todos los tipos y contextos).
  Future<List<PrintTemplate>> fetchAllTemplates({
    bool forceRefresh = false,
  }) => fetchTemplates(forceRefresh: forceRefresh);

  /// `POST /print/bluetooth-payload` → comandos ESC/POS ya codificados.
  Future<BluetoothPayload> bluetoothPayload({
    required int templateId,
    required PrintDataSourceType source,
    required int sourceId,
    bool openDrawer = false,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.printBluetoothPayload,
      data: <String, dynamic>{
        'template_id': templateId,
        'data_source_type': source.wire,
        'data_source_id': sourceId,
        'open_drawer': openDrawer,
      },
    );

    return BluetoothPayload.fromJson(data);
  }

  /// `POST /print/payload` → operaciones TSPL de la etiqueta.
  Future<LabelPayload> labelPayload({
    required int templateId,
    required PrintDataSourceType source,
    required int sourceId,
    double offsetX = 0,
    double offsetY = 0,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.printPayload,
      data: <String, dynamic>{
        'template_id': templateId,
        'data_source_type': source.wire,
        'data_source_id': sourceId,
        'offset_x': offsetX,
        'offset_y': offsetY,
      },
    );

    return LabelPayload.fromJson(data);
  }

  /// `POST /print/ticket-html` → respaldo para compartir sin impresora.
  Future<TicketHtml> ticketHtml({
    required int templateId,
    required PrintDataSourceType source,
    required int sourceId,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.printTicketHtml,
      data: <String, dynamic>{
        'template_id': templateId,
        'data_source_type': source.wire,
        'data_source_id': sourceId,
      },
    );

    return TicketHtml.fromJson(data);
  }

  /// `POST /print/whatsapp-ticket` → ticket ya formateado + teléfono destino.
  ///
  /// El servidor construye el ticket solo para **transacciones** (venta, pedido
  /// o apartado). Para otros orígenes responde `200` con `ticket: null`.
  Future<WhatsAppTicketResult> whatsappTicket({
    required PrintDataSourceType source,
    required int sourceId,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.printWhatsappTicket,
      data: <String, dynamic>{
        'data_source_type': source.wire,
        'data_source_id': sourceId,
      },
    );

    return WhatsAppTicketResult.fromJson(data);
  }

  /// Operación cuyo argumento trae el comando TSPL completo de la etiqueta.
  static bool isTextOperation(Map<String, dynamic> operation) =>
      '${operation['nombre']}' == _templateTextOperation;

  /// Limpia la caché (al cambiar de sucursal o de permisos).
  void invalidateTemplates() => _templatesCache.clear();
}
