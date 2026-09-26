import 'package:ezyventas_app/core/scanner/barcode_scanner_screen.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Código de barras de la corrida (EAN-13 de prueba).
const String scannedCode = '7501031311309';

const String instruction = 'Apunta al código de barras o al QR del producto.';

/// App mínima con un botón que abre el escáner y guarda lo que devuelve.
///
/// El escáner se abre con una vista previa inyectada: una prueba de widgets no
/// tiene cámara. El barrido del marco está animado en bucle, así que las pruebas
/// usan `pump()` con duración y **nunca** `pumpAndSettle()`.
Widget _wrap({required void Function(String?) onResult}) {
  return MaterialApp(
    theme: EzyTheme.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              final code = await Navigator.of(context).push<String>(
                MaterialPageRoute<String>(
                  builder: (routeContext) => BarcodeScannerScreen(
                    previewBuilder: (previewContext, onDetect) => Center(
                      child: TextButton(
                        onPressed: () => onDetect(scannedCode),
                        child: const Text('simular lectura'),
                      ),
                    ),
                  ),
                ),
              );
              onResult(code);
            },
            child: const Text('Abrir escáner'),
          ),
        ),
      ),
    ),
  );
}

/// Abre el escáner y deja la transición de ruta terminada.
Future<void> _openScanner(WidgetTester tester) async {
  await tester.tap(find.text('Abrir escáner'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('la barra, el marco y la instrucción del escáner (§12)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(onResult: (_) {}));
    await _openScanner(tester);

    expect(find.text('Escanear código'), findsOneWidget);
    expect(find.text(instruction), findsOneWidget);
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    // El marco de esquinas y el barrido son `CustomPaint`: el escáner sigue
    // montado y animando sin errores.
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el primer código leído cierra el escáner y lo devuelve', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(_wrap(onResult: (code) => result = code));
    await _openScanner(tester);

    await tester.tap(find.text('simular lectura'));
    // Con la lectura el escáner se cierra: el barrido animado desaparece con él,
    // así que aquí sí se puede esperar a que la ruta termine.
    await tester.pumpAndSettle();

    // Lectura correcta: cierre inmediato y el texto en la pantalla de origen.
    expect(result, scannedCode);
    expect(find.text('Escanear código'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cerrar sin leer no devuelve ningún código', (tester) async {
    var closed = false;
    String? result;

    await tester.pumpWidget(
      _wrap(
        onResult: (code) {
          result = code;
          closed = true;
        },
      ),
    );
    await _openScanner(tester);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
