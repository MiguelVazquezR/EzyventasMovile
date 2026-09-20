import '../../../../core/utils/json_reader.dart';

/// Tipo de plantilla (`type` de `GET /print/templates`, contrato §10).
enum PrintTemplateType {
  saleTicket('ticket_venta'),
  label('etiqueta'),
  quote('cotizacion'),
  serviceReceipt('recibo_servicio');

  const PrintTemplateType(this.wire);

  /// Valor que viaja en la API.
  final String wire;

  static PrintTemplateType? fromWire(String? value) {
    for (final type in PrintTemplateType.values) {
      if (type.wire == value) {
        return type;
      }
    }

    return null;
  }

  /// Nombre legible del tipo (el valor `label` ya ocupa ese identificador).
  String get displayName => switch (this) {
    PrintTemplateType.saleTicket => 'Ticket de venta',
    PrintTemplateType.label => 'Etiqueta',
    PrintTemplateType.quote => 'Cotización',
    PrintTemplateType.serviceReceipt => 'Recibo de servicio',
  };
}

/// Contexto de la plantilla (`context` de `GET /print/templates`).
enum PrintContextType {
  pos('pos'),
  transaction('transaction'),
  serviceOrder('service_order'),
  product('product'),
  customer('customer'),
  quote('quote'),
  general('general');

  const PrintContextType(this.wire);

  final String wire;

  String get label => switch (this) {
    PrintContextType.pos => 'Punto de venta',
    PrintContextType.transaction => 'Venta',
    PrintContextType.serviceOrder => 'Orden de servicio',
    PrintContextType.product => 'Producto',
    PrintContextType.customer => 'Cliente',
    PrintContextType.quote => 'Cotización',
    PrintContextType.general => 'General',
  };
}

/// Plantilla de impresión del negocio.
///
/// La app **no** renderiza plantillas: solo elige cuál usar y envía su `id` al
/// servidor, que devuelve el documento codificado (ESC/POS, TSPL o HTML).
class PrintTemplate {
  const PrintTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.contextType,
    required this.paperWidth,
    required this.isDefault,
    required this.config,
  });

  factory PrintTemplate.fromJson(Map<String, dynamic> json) => PrintTemplate(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    type: JsonReader.string(json['type']),
    contextType: JsonReader.string(json['context_type']),
    paperWidth: JsonReader.stringOr(json['paper_width'], '80mm'),
    isDefault: JsonReader.boolean(json['is_default']),
    config: JsonReader.toMap(json['config']),
  );

  final int id;
  final String name;

  /// `ticket_venta` | `etiqueta` | `cotizacion` | `recibo_servicio`.
  final String? type;

  /// `pos` | `transaction` | `service_order` | `product` | `customer` | ...
  final String? contextType;

  /// `58mm` | `80mm`.
  final String paperWidth;
  final bool isDefault;
  final Map<String, dynamic> config;

  PrintTemplateType? get templateType => PrintTemplateType.fromWire(type);

  bool get isLabel => type == PrintTemplateType.label.wire;

  /// Ancho útil del papel en caracteres (48 en 80 mm, 32 en 58 mm).
  int get charactersPerLine => paperWidth.startsWith('58') ? 32 : 48;

  /// `TICKET DE VENTA 80 mm · predeterminada`
  String get detailLabel {
    final parts = <String>[
      if (templateType != null) templateType!.displayName,
      paperWidth,
      if (isDefault) 'predeterminada',
    ];

    return parts.join(' · ');
  }
}
