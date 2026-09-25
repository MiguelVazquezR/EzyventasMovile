import 'print_template.dart';

/// Origen de datos aceptado por los endpoints de impresión (contrato §10).
///
/// El servidor limita cada origen a la suscripción del usuario: un documento de
/// otro negocio responde `404`.
enum PrintDataSourceType {
  pos('pos'),
  transaction('transaction'),
  serviceOrder('service_order'),
  product('product'),
  customer('customer'),
  order('order'),

  /// Turno de caja (el corte de §6.3): el servidor lo imprime como ticket.
  cashRegisterSession('cash_register_session'),
  general('general');

  const PrintDataSourceType(this.wire);

  final String wire;

  /// Venta del POS, pedido y orden de servicio usan `ticket_venta`.
  bool get isLabelSource => this == PrintDataSourceType.product;
}

/// Documento concreto que se va a imprimir o enviar por WhatsApp.
///
/// Solo lleva el origen (`data_source_type` + `data_source_id`) y el contexto
/// con el que se buscan las plantillas: el contenido lo arma el servidor.
class PrintDocument {
  const PrintDocument({
    required this.source,
    required this.id,
    required this.contexts,
    this.templateType = PrintTemplateType.saleTicket,
    this.templateIds = const <int>[],
    this.labelContexts = const <PrintContextType>[PrintContextType.product],
    this.title = '',
    this.subtitle = '',
  });

  /// Venta o pedido del historial (`transaction`, contexto `transaction`+`general`).
  factory PrintDocument.sale({
    required int transactionId,
    List<int> templateIds = const <int>[],
    String title = 'Ticket de venta',
    String subtitle = '',
  }) => PrintDocument(
    source: PrintDataSourceType.transaction,
    id: transactionId,
    contexts: const <PrintContextType>[
      PrintContextType.transaction,
      PrintContextType.general,
    ],
    templateIds: templateIds,
    title: title,
    subtitle: subtitle,
  );

  /// Venta del POS: el cobro ya dice qué plantillas aplican (`pos` + `general`).
  factory PrintDocument.posCheckout({
    required int transactionId,
    List<int> templateIds = const <int>[],
    String subtitle = '',
  }) => PrintDocument(
    source: PrintDataSourceType.pos,
    id: transactionId,
    contexts: const <PrintContextType>[
      PrintContextType.pos,
      PrintContextType.general,
    ],
    templateIds: templateIds,
    title: 'Ticket de venta',
    subtitle: subtitle,
  );

  /// Orden de servicio (`service_order`).
  factory PrintDocument.serviceOrder({
    required int serviceOrderId,
    required String folio,
    List<int> templateIds = const <int>[],
  }) => PrintDocument(
    source: PrintDataSourceType.serviceOrder,
    id: serviceOrderId,
    contexts: const <PrintContextType>[PrintContextType.serviceOrder],
    templateIds: templateIds,
    labelContexts: const <PrintContextType>[PrintContextType.serviceOrder],
    title: 'Orden de servicio',
    subtitle: folio,
  );

  /// Etiqueta de un producto (`product` + plantilla `etiqueta`, TSPL).
  factory PrintDocument.productLabel({
    required int productId,
    required String name,
  }) => PrintDocument(
    source: PrintDataSourceType.product,
    id: productId,
    contexts: const <PrintContextType>[PrintContextType.product],
    templateType: PrintTemplateType.label,
    labelContexts: const <PrintContextType>[
      PrintContextType.product,
      PrintContextType.general,
    ],
    title: 'Etiqueta de producto',
    subtitle: name,
  );

  /// Corte de caja de un turno (`cash_register_session`).
  ///
  /// Es el respaldo para una plantilla de corte del **negocio** que traiga una
  /// imagen: `POST /print/bluetooth-payload` la rasteriza en el servidor, algo
  /// que el teléfono no puede hacer con las operaciones del comprobante.
  factory PrintDocument.cashCut({
    required int sessionId,
    required int templateId,
    String subtitle = '',
  }) => PrintDocument(
    source: PrintDataSourceType.cashRegisterSession,
    id: sessionId,
    contexts: const <PrintContextType>[
      PrintContextType.cashRegister,
      PrintContextType.general,
    ],
    templateIds: <int>[templateId],
    labelContexts: const <PrintContextType>[PrintContextType.cashRegister],
    title: 'Corte de caja',
    subtitle: subtitle,
  );

  /// Ficha / estado de cuenta del cliente (`customer` + `general`): es el
  /// documento que la web imprime para un abono general a la cuenta.
  factory PrintDocument.customerAccount({
    required int customerId,
    required String name,
  }) => PrintDocument(
    source: PrintDataSourceType.customer,
    id: customerId,
    contexts: const <PrintContextType>[
      PrintContextType.customer,
      PrintContextType.general,
    ],
    title: 'Estado de cuenta del cliente',
    subtitle: name,
  );

  final PrintDataSourceType source;
  final int id;

  /// Contextos de plantilla que aplican al documento.
  ///
  /// Es el mismo conjunto que usa la web (`TransactionController`:
  /// `transaction` + `general`; `PointOfSaleController`: `pos` + `general`;
  /// `ServiceOrderController`: `service_order`; `ProductController`: `product` +
  /// `general`). La API solo filtra por **un** `context`, así que la app pide
  /// todas las plantillas del tipo y filtra aquí.
  final List<PrintContextType> contexts;

  final PrintTemplateType templateType;

  /// Plantillas que el servidor ya asoció al documento (p. ej. `print.template_ids`
  /// del cobro). Vacío = todas las del tipo y contextos.
  final List<int> templateIds;

  /// Contextos de las plantillas de **etiqueta** (producto u orden de servicio).
  final List<PrintContextType> labelContexts;

  final String title;
  final String subtitle;

  bool get isValid => id > 0 && source.wire.isNotEmpty;

  /// Plantillas que aplican al ticket del documento.
  List<PrintTemplate> selectTemplates(List<PrintTemplate> templates) =>
      _select(templates, templateType, contexts);

  /// Plantillas de etiqueta que aplican al documento.
  List<PrintTemplate> selectLabelTemplates(List<PrintTemplate> templates) =>
      _select(templates, PrintTemplateType.label, labelContexts);

  /// Filtra por tipo, contexto y (si el servidor los mandó) por id.
  List<PrintTemplate> _select(
    List<PrintTemplate> templates,
    PrintTemplateType type,
    List<PrintContextType> allowedContexts,
  ) {
    final matching = templates
        .where((template) => template.type == type.wire)
        .where(
          (template) =>
              template.contextType == null ||
              allowedContexts.any(
                (context) => context.wire == template.contextType,
              ),
        )
        .toList(growable: false);

    if (templateIds.isEmpty) {
      return matching;
    }

    return matching
        .where((template) => templateIds.contains(template.id))
        .toList(growable: false);
  }
}
