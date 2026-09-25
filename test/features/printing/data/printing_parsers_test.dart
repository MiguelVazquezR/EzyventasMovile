import 'dart:convert';

import 'package:ezyventas_app/features/printing/data/models/print_document.dart';
import 'package:ezyventas_app/features/printing/data/models/print_payloads.dart';
import 'package:ezyventas_app/features/printing/data/models/print_template.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plantillas reales de `GET /print/templates` (contrato §10).
List<Map<String, dynamic>> templatesFixture() => <Map<String, dynamic>>[
  <String, dynamic>{
    'id': 7,
    'name': 'Ticket de venta 80 mm',
    'type': 'ticket_venta',
    'context_type': 'pos',
    'paper_width': '80mm',
    'is_default': true,
    'config': <String, dynamic>{'paperWidth': '80mm', 'feedLines': 3},
  },
  <String, dynamic>{
    'id': 9,
    'name': 'Etiqueta producto pequeña',
    'type': 'etiqueta',
    'context_type': 'product',
    'paper_width': '58mm',
    'is_default': false,
    'config': <String, dynamic>{'paperWidth': '58mm'},
  },
];

void main() {
  group('PrintTemplate', () {
    test('lee la plantilla del servidor y su ancho de papel', () {
      final template = PrintTemplate.fromJson(templatesFixture().first);

      expect(template.id, 7);
      expect(template.name, 'Ticket de venta 80 mm');
      expect(template.templateType, PrintTemplateType.saleTicket);
      expect(template.contextType, 'pos');
      expect(template.paperWidth, '80mm');
      expect(template.isDefault, isTrue);
      expect(template.charactersPerLine, 48);
      expect(template.isLabel, isFalse);
      expect(template.detailLabel, 'Ticket de venta · 80mm · predeterminada');
    });

    test('la etiqueta de 58 mm usa 32 caracteres', () {
      final label = PrintTemplate.fromJson(templatesFixture().last);

      expect(label.isLabel, isTrue);
      expect(label.templateType, PrintTemplateType.label);
      expect(label.charactersPerLine, 32);
      expect(label.isDefault, isFalse);
      expect(label.detailLabel, 'Etiqueta · 58mm');
    });

    test('tolera un tipo desconocido sin romper la lista', () {
      final template = PrintTemplate.fromJson(<String, dynamic>{
        'id': 15,
        'name': 'Reporte',
        'type': 'reporte_x',
        'context_type': 'general',
        'is_default': 1,
      });

      expect(template.templateType, isNull);
      expect(template.paperWidth, '80mm');
      expect(template.isDefault, isTrue);
      expect(template.detailLabel, '80mm · predeterminada');
    });
  });

  group('BluetoothPayload', () {
    test('decodifica los comandos ESC/POS en Base64', () {
      final payload = BluetoothPayload.fromJson(<String, dynamic>{
        'commands_base64': 'G0AaG0E=',
        'paperWidth': '80mm',
      });

      expect(payload.commands, <int>[0x1B, 0x40, 0x1A, 0x1B, 0x41]);
      expect(payload.paperWidth, '80mm');
      expect(payload.isEmpty, isFalse);
      expect(payload.byteCount, 5);
    });

    test('sin comandos (o Base64 inválido) deja el payload vacío', () {
      expect(BluetoothPayload.fromJson(<String, dynamic>{}).isEmpty, isTrue);
      expect(
        BluetoothPayload.fromJson(<String, dynamic>{
          'commands_base64': 'no-es-base64!!',
        }).isEmpty,
        isTrue,
      );
    });
  });

  group('LabelPayload', () {
    test('extrae el comando TSPL completo de la operación de texto', () {
      final payload = LabelPayload.fromJson(<String, dynamic>{
        'operations': <Map<String, dynamic>>[
          <String, dynamic>{
            'nombre': 'EscribirTexto',
            'argumentos': <String>[
              'SIZE 50 mm,30 mm\nGAP 2 mm,0 mm\nCLS\nTEXT 10,10,"3",0,1,1,'
                  '"Filtro"\nPRINT 1,1\n',
            ],
          },
        ],
        'paperWidth': '58mm',
        'feedLines': 2,
      });

      expect(payload.tsplText, contains('SIZE 50 mm,30 mm'));
      expect(payload.tsplText, endsWith('PRINT 1,1\n'));
      expect(payload.hasUnsupportedOperations, isFalse);
      expect(payload.feedLines, 2);
      expect(payload.isEmpty, isFalse);
    });

    test('reporta las operaciones que el teléfono no puede rasterizar', () {
      final payload = LabelPayload.fromJson(<String, dynamic>{
        'operations': <Map<String, dynamic>>[
          <String, dynamic>{
            'nombre': 'DescargarImagenDeInternetEImprimir',
            'argumentos': <Object>['https://ejemplo.test/logo.png', 120],
          },
          <String, dynamic>{
            'nombre': 'EscribirTexto',
            'argumentos': <String>['SIZE 50 mm,30 mm\nPRINT 1,1\n'],
          },
        ],
      });

      expect(payload.hasUnsupportedOperations, isTrue);
      expect(payload.tsplText, isNotNull);
    });

    test('avisa de lo que el servidor no pudo resolver y de lo que ajustó', () {
      final payload = LabelPayload.fromJson(<String, dynamic>{
        'operations': <Map<String, dynamic>>[
          <String, dynamic>{
            'nombre': 'EscribirTexto',
            'argumentos': <String>[
              'SIZE 50 mm,30 mm\nBITMAP 10,10,4,8,0,FF\n'
                  'BARCODE 10,60,"128",40,1,0,2,2,"P-42"\nPRINT 1,1\n',
            ],
          },
        ],
        'unsupported_operations': <String>[
          'Image: https://ejemplo.test/logo.png',
        ],
        'warnings': <String>[
          'Barcode: la plantilla no resolvió un valor, se usó «P-42».',
        ],
      });

      expect(payload.hasUnsupportedOperations, isTrue);
      expect(
        payload.warningNotice,
        contains('Image: https://ejemplo.test/logo.png'),
      );
      expect(payload.warningNotice, contains('se usó «P-42»'));
      // El texto TSPL ya trae el BITMAP y el código de barras relleno.
      expect(payload.tsplText, contains('BITMAP'));
      expect(payload.tsplText, contains('BARCODE'));
    });

    test('sin avisos del servidor no hay nada que reportar', () {
      final payload = LabelPayload.fromJson(<String, dynamic>{
        'operations': <Map<String, dynamic>>[
          <String, dynamic>{
            'nombre': 'EscribirTexto',
            'argumentos': <String>[
              'SIZE 50 mm,30 mm\nBITMAP 10,10,4,8,0,FF\nPRINT 1,1\n',
            ],
          },
        ],
        'unsupported_operations': <String>[],
        'warnings': <String>[],
      });

      expect(payload.hasUnsupportedOperations, isFalse);
      expect(payload.warningNotice, isNull);
      expect(payload.unresolvedOperations, isEmpty);
    });

    test('sin operación de texto no hay nada que imprimir', () {
      final payload = LabelPayload.fromJson(<String, dynamic>{
        'operations': <Map<String, dynamic>>[],
      });

      expect(payload.tsplText, isNull);
      expect(payload.isEmpty, isTrue);
    });
  });

  group('TicketHtml', () {
    test('lee el respaldo HTML del ticket', () {
      final html = TicketHtml.fromJson(<String, dynamic>{
        'html': '<html><body>Ticket</body></html>',
        'paperWidth': '80mm',
        'template_name': 'Ticket de venta 80 mm',
      });

      expect(html.html, contains('<html>'));
      expect(html.paperWidth, '80mm');
      expect(html.templateName, 'Ticket de venta 80 mm');
      expect(html.isEmpty, isFalse);
    });
  });

  group('WhatsAppTicketResult', () {
    test('lee el ticket de venta con teléfono del cliente', () {
      final result = WhatsAppTicketResult.fromJson(<String, dynamic>{
        'ticket': <String, dynamic>{
          'kind': 'sale',
          'businessName': 'Refaccionaria López',
          'folio': 'V-014',
          'total': '\$270.00 MXN',
        },
        'customer_phone': '4771112233',
        'customer_id': 8,
      });

      expect(result.isEmpty, isFalse);
      expect(result.hasPhone, isTrue);
      expect(result.customerPhone, '4771112233');
      expect(result.customerId, 8);
      expect(result.ticket!['folio'], 'V-014');
    });

    test('sin venta vinculada responde 200 con ticket nulo', () {
      final result = WhatsAppTicketResult.fromJson(<String, dynamic>{
        'ticket': null,
        'customer_phone': null,
        'customer_id': null,
      });

      expect(result.isEmpty, isTrue);
      expect(result.hasPhone, isFalse);
    });
  });


  group('PrintDocument', () {
    test('la venta del POS usa el origen y los contextos del cobro', () {
      final document = PrintDocument.posCheckout(
        transactionId: 987,
        templateIds: <int>[7],
        subtitle: 'V-014',
      );

      expect(document.isValid, isTrue);
      expect(document.source, PrintDataSourceType.pos);
      expect(document.contexts, <PrintContextType>[
        PrintContextType.pos,
        PrintContextType.general,
      ]);
      expect(document.templateType, PrintTemplateType.saleTicket);
    });

    test('la venta del historial acepta transaction y general', () {
      final document = PrintDocument.sale(transactionId: 987);

      expect(document.contexts, <PrintContextType>[
        PrintContextType.transaction,
        PrintContextType.general,
      ]);
    });

    test('filtra las plantillas por tipo, contexto y los ids del cobro', () {
      final templates = <PrintTemplate>[
        ...templatesFixture().map(PrintTemplate.fromJson),
        PrintTemplate.fromJson(<String, dynamic>{
          'id': 13,
          'name': 'Ticket general',
          'type': 'ticket_venta',
          'context_type': 'general',
          'paper_width': '80mm',
          'is_default': true,
        }),
      ];

      final document = PrintDocument.posCheckout(
        transactionId: 987,
        templateIds: <int>[7],
      );

      // Con los ids que manda el cobro solo queda la plantilla asociada.
      expect(document.selectTemplates(templates).map((t) => t.id), <int>[7]);

      // Sin ids: la de `pos` y la `general` aplican a la venta.
      final withoutIds = PrintDocument.posCheckout(transactionId: 987);

      expect(withoutIds.selectTemplates(templates).map((t) => t.id), <int>[
        7,
        13,
      ]);

      // La venta del historial sí acepta la `general`, no la de `pos`.
      final history = PrintDocument.sale(transactionId: 987);

      expect(history.selectTemplates(templates).map((t) => t.id), <int>[13]);
    });

    test('la orden de servicio solo usa plantillas de su contexto', () {
      final templates = <PrintTemplate>[
        ...templatesFixture().map(PrintTemplate.fromJson),
        PrintTemplate.fromJson(<String, dynamic>{
          'id': 11,
          'name': 'Ticket de orden de servicio',
          'type': 'ticket_venta',
          'context_type': 'service_order',
          'paper_width': '80mm',
          'is_default': true,
        }),
        PrintTemplate.fromJson(<String, dynamic>{
          'id': 12,
          'name': 'Etiqueta de orden',
          'type': 'etiqueta',
          'context_type': 'service_order',
          'paper_width': '80mm',
          'is_default': false,
        }),
      ];

      final document = PrintDocument.serviceOrder(
        serviceOrderId: 55,
        folio: 'OS-0007',
      );

      expect(document.selectTemplates(templates).map((t) => t.id), <int>[11]);
      expect(document.selectLabelTemplates(templates).map((t) => t.id), <int>[
        12,
      ]);
    });

    test('la etiqueta de producto se pide con el tipo etiqueta', () {
      final document = PrintDocument.productLabel(
        productId: 12,
        name: 'Filtro',
      );

      expect(document.templateType, PrintTemplateType.label);
      expect(document.source, PrintDataSourceType.product);
      expect(document.labelContexts, <PrintContextType>[
        PrintContextType.product,
        PrintContextType.general,
      ]);
    });

    test('un documento sin id no es imprimible', () {
      expect(
        PrintDocument.customerAccount(customerId: 0, name: '—').isValid,
        isFalse,
      );
    });
  });

  test('el Base64 real de una venta se decodifica a los mismos bytes', () {
    const raw = <int>[0x1B, 0x40, 0x1B, 0x74, 0x02, 0x0A, 0x1D, 0x56];

    expect(BluetoothPayload.decodeBase64(base64Encode(raw)), raw);
  });
}

