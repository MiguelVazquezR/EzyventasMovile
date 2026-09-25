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
/// El servidor rasteriza las imágenes de la etiqueta y las inserta en el mismo
/// texto TSPL como `BITMAP …`, además de rellenar el código de barras cuando la
/// plantilla no resuelve un valor. Todo eso viaja dentro de la operación
/// `EscribirTexto`, que es el comando completo que se manda a la impresora.
///
/// Los campos `unsupported_operations` (lo que el servidor **no** pudo
/// resolver) y `warnings` (ajustes que hizo) existen para que la app avise en
/// lugar de imprimir en silencio.
class LabelPayload {
  const LabelPayload({
    required this.operations,
    required this.paperWidth,
    required this.feedLines,
    this.unsupportedOperations = const <String>[],
    this.warnings = const <String>[],
  });

  factory LabelPayload.fromJson(Map<String, dynamic> json) => LabelPayload(
    operations: JsonReader.toMapList(json['operations']),
    paperWidth: JsonReader.stringOr(json['paperWidth'], '80mm'),
    feedLines: JsonReader.integerOr(json['feedLines'], 0),
    unsupportedOperations: JsonReader.stringList(
      json['unsupported_operations'],
    ),
    warnings: JsonReader.stringList(json['warnings']),
  );

  static const String textOperation = 'EscribirTexto';

  /// Pulso del cajón: no imprime nada, así que no cuenta como no soportada.
  static const String drawerOperation = 'AbrirCajon';

  final List<Map<String, dynamic>> operations;
  final String paperWidth;
  final int feedLines;

  /// Lo que el servidor **no** pudo resolver (p. ej. `Image: https://…`): la
  /// etiqueta sale sin ese elemento.
  final List<String> unsupportedOperations;

  /// Ajustes que hizo el servidor (p. ej.
  /// `Barcode: la plantilla no resolvió un valor, se usó «P-42».`).
  final List<String> warnings;

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

  /// Operaciones que la plantilla trae y el teléfono no puede emitir.
  List<String> get unresolvedOperations => operations
      .map((operation) => JsonReader.stringOr(operation['nombre'], ''))
      .where(
        (name) =>
            name.isNotEmpty &&
            name != textOperation &&
            name != drawerOperation,
      )
      .toList(growable: false);

  /// `true` si el servidor reportó algo o si la plantilla trae operaciones que
  /// este cliente no sabe emitir.
  bool get hasUnsupportedOperations =>
      unsupportedOperations.isNotEmpty ||
      warnings.isNotEmpty ||
      unresolvedOperations.isNotEmpty;

  /// Aviso en español con lo que reportó el servidor (`null` si todo salió
  /// bien).
  String? get warningNotice {
    if (!hasUnsupportedOperations) {
      return null;
    }

    final parts = <String>[
      if (unsupportedOperations.isNotEmpty)
        'El servidor no pudo incluir: ${unsupportedOperations.join('; ')}.',
      ...warnings,
      if (unresolvedOperations.isNotEmpty)
        'La plantilla trae ${unresolvedOperations.join(', ')}, que el teléfono '
            'no imprime.',
    ];

    return '${parts.join(' ')} Revisa la etiqueta: puede salir incompleta.';
  }

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
