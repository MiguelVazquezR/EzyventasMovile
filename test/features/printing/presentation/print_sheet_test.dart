import 'dart:typed_data';

import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_selectable_tile.dart';
import 'package:ezyventas_app/features/printing/application/printing_providers.dart';
import 'package:ezyventas_app/features/printing/data/models/print_document.dart';
import 'package:ezyventas_app/features/printing/data/models/print_payloads.dart';
import 'package:ezyventas_app/features/printing/data/models/print_template.dart';
import 'package:ezyventas_app/features/printing/data/printing_repository.dart';
import 'package:ezyventas_app/features/printing/presentation/print_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio falso: devuelve plantillas y documentos sin tocar la red.
class _FakePrintingRepository extends PrintingRepository {
  _FakePrintingRepository({this.templates = const <PrintTemplate>[]})
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final List<PrintTemplate> templates;

  int? lastPrintedTemplateId;
  PrintDataSourceType? lastPrintedSource;

  /// El servidor no arma el ticket de WhatsApp (p. ej. una orden sin venta).
  bool whatsAppTicketIsEmpty = true;

  /// `message` del servidor cuando el origen no tiene ticket de WhatsApp
  /// (`422 no_whatsapp_ticket`, el caso real de un producto o un cliente).
  String? whatsAppTicketError;

  @override
  Future<List<PrintTemplate>> fetchTemplates({
    PrintTemplateType? type,
    PrintContextType? context,
    bool forceRefresh = false,
  }) async {
    if (type == null) {
      return templates;
    }

    return templates
        .where((template) => template.type == type.wire)
        .toList(growable: false);
  }

  @override
  Future<BluetoothPayload> bluetoothPayload({
    required int templateId,
    required PrintDataSourceType source,
    required int sourceId,
    bool openDrawer = false,
  }) async {
    lastPrintedTemplateId = templateId;
    lastPrintedSource = source;

    return BluetoothPayload(
      commands: Uint8List.fromList(<int>[0x1B, 0x40, 0x0A]),
      paperWidth: '80mm',
    );
  }

  @override
  Future<TicketHtml> ticketHtml({
    required int templateId,
    required PrintDataSourceType source,
    required int sourceId,
  }) async => const TicketHtml(
    html: '<html><body>Ticket</body></html>',
    paperWidth: '80mm',
    templateName: 'Ticket de venta',
  );

  @override
  Future<WhatsAppTicketResult> whatsappTicket({
    required PrintDataSourceType source,
    required int sourceId,
  }) async {
    final error = whatsAppTicketError;

    if (error != null) {
      throw ApiException(
        message: error,
        statusCode: 422,
        code: 'no_whatsapp_ticket',
      );
    }

    return whatsAppTicketIsEmpty
        ? const WhatsAppTicketResult(
            ticket: null,
            customerPhone: null,
            customerId: null,
          )
        : const WhatsAppTicketResult(
            ticket: <String, dynamic>{
              'kind': 'sale',
              'title': 'TICKET DE VENTA',
              'businessName': 'Refaccionaria López',
              'date': '18/09/2026 - 14:35',
              'folio': 'V-014',
              'customer': 'Ana Ramírez',
              'items': <Map<String, dynamic>>[],
              'total': '\$270.00 MXN',
              'finalMessage': '¡Gracias por tu compra!',
            },
            customerPhone: '4771112233',
            customerId: 8,
          );
  }
}

PrintTemplate _template({
  required int id,
  required String name,
  String context = 'general',
  bool isDefault = false,
  String type = 'ticket_venta',
}) => PrintTemplate(
  id: id,
  name: name,
  type: type,
  contextType: context,
  paperWidth: '80mm',
  isDefault: isDefault,
  config: const <String, dynamic>{},
);

/// Pantalla alta para que la hoja de impresión (que es larga) pinte todos sus
/// botones sin desplazarse.
Future<void> _useTallScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 4200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Pinta la hoja de impresión de una venta del historial.
Future<void> _pumpPrintSheet(
  WidgetTester tester,
  _FakePrintingRepository repository, {
  bool allowLabels = false,
}) async {
  await _useTallScreen(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [printingRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPrintSheet(
                  context,
                  document: PrintDocument.sale(
                    transactionId: 21,
                    subtitle: 'V-014',
                  ),
                  allowLabels: allowLabels,
                ),
                child: const Text('Abrir impresión'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Abrir impresión'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra las plantillas que aplican a la venta', (tester) async {
    await _pumpPrintSheet(
      tester,
      _FakePrintingRepository(
        templates: <PrintTemplate>[
          _template(id: 3, name: 'Ticket de venta', isDefault: true),
          _template(id: 7, name: 'Ticket de venta A2'),
          _template(
            id: 1,
            name: 'Ticket orden de servicio',
            context: 'service_order',
          ),
        ],
      ),
    );

    expect(find.text('Ticket de venta'), findsOneWidget);
    expect(find.text('Ticket de venta A2'), findsOneWidget);
    // La plantilla de órdenes no aplica a una venta.
    expect(find.text('Ticket orden de servicio'), findsNothing);
    expect(find.text('Imprimir ticket'), findsOneWidget);
    expect(find.text('Enviar por WhatsApp'), findsOneWidget);
  });

  testWidgets('sin plantillas para el documento lo explica', (tester) async {
    await _pumpPrintSheet(tester, _FakePrintingRepository());

    expect(
      find.textContaining('El negocio no tiene una plantilla de'),
      findsOneWidget,
    );
  });

  testWidgets('sin Bluetooth el botón de imprimir queda deshabilitado', (
    tester,
  ) async {
    await _pumpPrintSheet(
      tester,
      _FakePrintingRepository(
        templates: <PrintTemplate>[
          _template(id: 3, name: 'Ticket de venta', isDefault: true),
        ],
      ),
    );

    // En el entorno de pruebas no hay plugin de Bluetooth: la hoja lo avisa.
    expect(find.textContaining('Bluetooth'), findsWidgets);

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Imprimir ticket'),
        matching: find.byType(FilledButton),
      ),
    );

    expect(button.onPressed, isNull);
  });

  testWidgets('WhatsApp avisa cuando el servidor no devuelve el ticket', (
    tester,
  ) async {
    await _pumpPrintSheet(
      tester,
      _FakePrintingRepository(
        templates: <PrintTemplate>[
          _template(id: 3, name: 'Ticket de venta', isDefault: true),
        ],
      ),
    );

    await tester.tap(find.text('Enviar por WhatsApp'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('El servidor no generó el ticket de WhatsApp'),
      findsOneWidget,
    );
  });

  testWidgets('WhatsApp muestra el error del servidor cuando no hay ticket', (
    tester,
  ) async {
    await _pumpPrintSheet(
      tester,
      _FakePrintingRepository(
        templates: <PrintTemplate>[
          _template(id: 3, name: 'Ticket de venta', isDefault: true),
        ],
      )..whatsAppTicketError = 'Este documento no tiene ticket de WhatsApp.',
    );

    await tester.tap(find.text('Enviar por WhatsApp'));
    await tester.pumpAndSettle();

    // El `message` del `422` se muestra tal cual (no se inventa texto).
    expect(
      find.textContaining('Este documento no tiene ticket de WhatsApp.'),
      findsOneWidget,
    );
  });

  testWidgets('WhatsApp abre la previsualización con el ticket del servidor', (
    tester,
  ) async {
    final repository = _FakePrintingRepository(
      templates: <PrintTemplate>[
        _template(id: 3, name: 'Ticket de venta', isDefault: true),
      ],
    )..whatsAppTicketIsEmpty = false;

    await _pumpPrintSheet(tester, repository);

    await tester.tap(find.text('Enviar por WhatsApp'));
    await tester.pumpAndSettle();

    expect(find.textContaining('» *TICKET DE VENTA* «'), findsOneWidget);
    expect(find.text('Abrir WhatsApp'), findsOneWidget);
    expect(find.text('Copiar mensaje'), findsOneWidget);
  });

  testWidgets('la cabecera une el documento con su folio y cierra la hoja', (
    tester,
  ) async {
    await _pumpPrintSheet(
      tester,
      _FakePrintingRepository(
        templates: <PrintTemplate>[
          _template(id: 3, name: 'Ticket de venta', isDefault: true),
        ],
      ),
    );

    // Cabecera de hoja del design system: el título de siempre y el subtítulo
    // con el documento y el folio que devolvió el servidor.
    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Imprimir y compartir');
    expect(header.subtitle, 'Ticket de venta · V-014');

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Imprimir y compartir'), findsNothing);
  });

  testWidgets('la plantilla se elige con la fila del design system', (
    tester,
  ) async {
    await _pumpPrintSheet(
      tester,
      _FakePrintingRepository(
        templates: <PrintTemplate>[
          _template(id: 3, name: 'Ticket de venta', isDefault: true),
          _template(id: 7, name: 'Ticket de venta A2'),
        ],
      ),
    );

    final tiles = find.byType(EzySelectableTile);
    expect(tiles, findsNWidgets(2));
    expect(tester.widget<EzySelectableTile>(tiles.at(0)).isSelected, isTrue);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.tap(find.text('Ticket de venta A2'));
    await tester.pumpAndSettle();

    expect(tester.widget<EzySelectableTile>(tiles.at(0)).isSelected, isFalse);
    expect(tester.widget<EzySelectableTile>(tiles.at(1)).isSelected, isTrue);
  });
}

