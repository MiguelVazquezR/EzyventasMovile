import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/section_card.dart';
import 'package:ezyventas_app/features/printing/presentation/widgets/whatsapp_ticket_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket como lo devuelve el servidor y lo arma [WhatsAppMessageBuilder].
const String _message =
    '» *TICKET DE VENTA* «\nRefaccionaria López\nFolio: V-014\nTotal: \$120.00';

/// Monta la previsualización como la abre la hoja de impresión.
Future<void> _pumpSheet(
  WidgetTester tester, {
  String message = _message,
  String? phone,
  String? title,
  String? subtitle,
}) async {
  // Pantalla alta: la hoja (0.85 del alto) deja ver el mensaje y sus botones.
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: EzyTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showWhatsAppMessageSheet(
                context,
                message: message,
                phone: phone,
                title: title,
                subtitle: subtitle,
              ),
              child: const Text('Enviar ticket'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Enviar ticket'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('con teléfono dice a quién se le abrirá WhatsApp', (
    tester,
  ) async {
    await _pumpSheet(tester, phone: '4771234567');

    expect(
      find.widgetWithText(EzySheetHeader, 'Enviar por WhatsApp'),
      findsOneWidget,
    );
    expect(
      find.textContaining('mensaje listo para 4771234567'),
      findsOneWidget,
    );
    expect(find.textContaining('» *TICKET DE VENTA* «'), findsOneWidget);
    expect(find.widgetWithText(EzyButton, 'Abrir WhatsApp'), findsOneWidget);
    expect(find.widgetWithText(EzyButton, 'Copiar mensaje'), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsOneWidget);
  });

  testWidgets('sin teléfono avisa que se elegirá el contacto', (tester) async {
    await _pumpSheet(tester);

    expect(find.textContaining('El cliente no tiene teléfono'), findsOneWidget);
    expect(find.textContaining('elijas el contacto'), findsOneWidget);
  });

  testWidgets('el documento y el título propio se muestran en la cabecera', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      phone: '4771234567',
      title: 'Enviar el corte por WhatsApp',
      subtitle: 'Corte de caja · Turno del 18/09',
    );

    expect(
      find.widgetWithText(EzySheetHeader, 'Enviar el corte por WhatsApp'),
      findsOneWidget,
    );
    expect(find.text('Corte de caja · Turno del 18/09'), findsOneWidget);
  });

  testWidgets('el mensaje va en una card del design system y se copia', (
    tester,
  ) async {
    final calls = <MethodCall>[];

    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pumpSheet(tester, phone: '4771234567');

    // El texto completo, seleccionable, dentro de la card `MENSAJE`.
    expect(find.widgetWithText(SectionCard, _message), findsOneWidget);
    expect(find.text('MENSAJE'), findsOneWidget);

    await tester.tap(find.text('Copiar mensaje'));
    await tester.pump();

    expect(calls.map((call) => call.method), contains('Clipboard.setData'));
    expect(find.text('Mensaje copiado.'), findsOneWidget);
  });
}
