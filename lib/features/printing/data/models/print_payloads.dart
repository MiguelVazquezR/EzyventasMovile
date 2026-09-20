import 'dart:convert';
import 'dart:typed_data';

import '../../../../core/utils/json_reader.dart';

/// Respuesta de `POST /print/bluetooth-payload`.
///
/// `commands_base64` son los comandos ESC/POS **ya codificados por el servidor**
/// (misma plantilla que usa la web): la app solo los decodifica y los envía en
/// bloques a la impresora.
class BluetoothPayload {
  const BluetoothPayload({required this.commands, required this.paperWidth});

  factory BluetoothPayload.fromJson(Map<String, dynamic> json) =>
      BluetoothPayload(
        commands: decodeBase64(JsonReader.string(json['commands_base64'])),
        paperWidth: JsonReader.stringOr(json['paperWidth'], '80mm'),
      );

  final Uint8List commands;
  final String paperWidth;

  bool get isEmpty => commands.isEmpty;

  int get byteCount => commands.length;

  /// Base64 → bytes. Un Base64 inválido deja la impresión sin contenido (y la
  /// UI lo avisa) en lugar de romper la pantalla.
  static Uint8List decodeBase64(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return Uint8List(0);
    }

    try {
      return base64Decode(raw.trim());
    } on FormatException {
      return Uint8List(0);
    }
  }
}

/// Respuesta de `POST /print/payload` (etiquetas / TSPL).
///
/// `operations` son las operaciones que entiende el plugin de escritorio de la
/// web; en Android la única aprovechable tal cual es `EscribirTexto`, que trae
/// el comando **TSPL completo** de la etiqueta. Las imágenes
/// (`DescargarImagenDeInternetEImprimir`) no se pueden enviar sin un rasterizador
/// en el teléfono: se reportan como no soportadas.
class LabelPayload {
  const LabelPayload({
    required this.operations,
    required this.paperWidth,
    required this.feedLines,
  });

  factory LabelPayload.fromJson(Map<String, dynamic> json) => LabelPayload(
    operations: JsonReader.toMapList(json['operations']),
    paperWidth: JsonReader.stringOr(json['paperWidth'], '80mm'),
    feedLines: JsonReader.integerOr(json['feedLines'], 0),
  );

  static const String textOperation = 'EscribirTexto';

  final List<Map<String, dynamic>> operations;
  final String paperWidth;
  final int feedLines;

  /// Comando TSPL listo para la impresora de etiquetas.
  String? get tsplText {
    for (final operation in operations) {
      if (JsonReader.string(operation['nombre']) != textOperation) {
        continue;
      }

      final arguments = operation['argumentos'];

      if (arguments is List && arguments.isNotEmpty) {
        final text = JsonReader.string(arguments.first);

        if (text != null && text.trim().isNotEmpty) {
          return text;
        }
      }
    }

    return null;
  }

  /// La plantilla incluye imágenes o códigos que la app no puede rasterizar.
  bool get hasUnsupportedOperations => operations.any(
    (operation) =>
        JsonReader.string(operation['nombre']) != textOperation &&
        JsonReader.string(operation['nombre']) != 'AbrirCajon',
  );

  bool get isEmpty => tsplText == null;
}

/// Respuesta de `POST /print/ticket-html` (respaldo sin impresora).
class TicketHtml {
  const TicketHtml({
    required this.html,
    required this.paperWidth,
    required this.templateName,
  });

  factory TicketHtml.fromJson(Map<String, dynamic> json) => TicketHtml(
    html: JsonReader.stringOr(json['html'], ''),
    paperWidth: JsonReader.stringOr(json['paperWidth'], '80mm'),
    templateName: JsonReader.string(json['template_name']),
  );

  final String html;
  final String paperWidth;
  final String? templateName;

  bool get isEmpty => html.trim().isEmpty;
}

/// Respuesta de `POST /print/whatsapp-ticket`.
///
/// `ticket` trae el texto ya formateado por el servidor (montos incluidos) y
/// `customer_phone` el teléfono del cliente; si es `null`, WhatsApp se abre sin
/// destinatario para elegir el contacto.
class WhatsAppTicketResult {
  const WhatsAppTicketResult({
    required this.ticket,
    required this.customerPhone,
    required this.customerId,
  });

  factory WhatsAppTicketResult.fromJson(Map<String, dynamic> json) =>
      WhatsAppTicketResult(
        ticket: json['ticket'] == null
            ? null
            : JsonReader.toMap(json['ticket']),
        customerPhone: JsonReader.string(json['customer_phone']),
        customerId: JsonReader.integer(json['customer_id']),
      );

  /// Mapa del ticket (`kind`: `sale`, `abono`, `order`, `order_payment`).
  final Map<String, dynamic>? ticket;
  final String? customerPhone;
  final int? customerId;

  /// El servidor no pudo armar el ticket (p. ej. una orden de servicio sin
  /// venta vinculada: responde `200` con `ticket: null`).
  bool get isEmpty => ticket == null || ticket!.isEmpty;

  bool get hasPhone => (customerPhone ?? '').trim().isNotEmpty;
}
