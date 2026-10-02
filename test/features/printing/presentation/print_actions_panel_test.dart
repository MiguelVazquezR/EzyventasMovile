import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/printing/data/models/print_document.dart';
import 'package:ezyventas_app/features/printing/presentation/widgets/print_actions_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pinta el panel de acciones con el documento de una venta recién cobrada.
Future<void> _pumpPanel(
  WidgetTester tester, {
  bool requirePrinterConnection = false,
  PrintDocument? document,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PrintActionsPanel(
              document:
                  document ??
                  PrintDocument.posCheckout(
                    transactionId: 21,
                    templateIds: const <int>[3],
                    subtitle: 'V-014',
                  ),
              requirePrinterConnection: requirePrinterConnection,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// `true` cuando el botón de imprimir se puede tocar: el design system lo pinta
/// sobre un `FilledButton`, así que su estado se lee de `onPressed`.
bool _printEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find
        .ancestor(
          of: find.text('Imprimir ticket'),
          matching: find.byType(FilledButton),
        )
        .first,
  );

  return button.onPressed != null;
}

void main() {
  testWidgets('el cobro apaga la impresión si no hay impresora conectada', (
    tester,
  ) async {
    await _pumpPanel(tester, requirePrinterConnection: true);

    // En el entorno de pruebas no hay plugin de Bluetooth: el panel lo anuncia
    // y, al exigir impresora, el botón queda apagado.
    expect(find.text('Impresora Bluetooth desconectada'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(_printEnabled(tester), isFalse);

    // WhatsApp no depende de la impresora.
    expect(find.text('Enviar por WhatsApp'), findsOneWidget);
  });

  testWidgets(
    'fuera del cobro el botón abre la hoja aunque no haya impresora',
    (tester) async {
      await _pumpPanel(tester);

      // El resto de pantallas sigue ofreciendo la hoja de impresión (elegir o
      // conectar la impresora) sin impresora lista.
      expect(_printEnabled(tester), isTrue);
    },
  );

  testWidgets('un documento sin fuente no se puede imprimir', (tester) async {
    await _pumpPanel(
      tester,
      document: PrintDocument.posCheckout(transactionId: 0),
    );

    expect(_printEnabled(tester), isFalse);
  });
}
