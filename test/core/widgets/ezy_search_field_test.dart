import 'package:ezyventas_app/core/theme/app_colors.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monta el buscador con el `trailing` indicado y devuelve lo que llega a
/// `onChanged`.
Future<List<String>> _pumpField(
  WidgetTester tester, {
  Widget? trailing,
  Color? borderColor,
  TextEditingController? controller,
}) async {
  final changes = <String>[];

  await tester.pumpWidget(
    MaterialApp(
      theme: EzyTheme.dark(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: EzySearchField(
            hint: 'Buscar por nombre o SKU…',
            controller: controller,
            borderColor: borderColor,
            trailing: trailing,
            onChanged: changes.add,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  return changes;
}

/// Borde de 1 px del campo (el `Container` que envuelve al `TextField`).
Border _border(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .ancestor(of: find.byType(TextField), matching: find.byType(Container))
        .first,
  );

  return (container.decoration! as BoxDecoration).border! as Border;
}

void main() {
  const qrButton = Icon(Icons.qr_code_scanner);

  testWidgets('el `trailing` pinta la acción de la derecha (§10)', (
    tester,
  ) async {
    var taps = 0;

    await _pumpField(
      tester,
      trailing: GestureDetector(
        onTap: () => taps++,
        behavior: HitTestBehavior.opaque,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Center(child: qrButton),
        ),
      ),
    );

    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);

    await tester.tap(find.byIcon(Icons.qr_code_scanner));
    await tester.pump();

    expect(taps, 1);
  });

  testWidgets('con `trailing` el botón de limpiar sigue disponible', (
    tester,
  ) async {
    final changes = await _pumpField(
      tester,
      controller: TextEditingController(text: 'filtro'),
      trailing: const SizedBox(width: 44, height: 44, child: qrButton),
    );

    // Con texto se pintan la «x» y la acción: el hueco del pulgar no se mueve.
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(changes, <String>['']);
  });

  testWidgets('limpiar cancela el aviso pendiente del retardo (§12)', (
    tester,
  ) async {
    final changes = await _pumpField(tester);

    await tester.enterText(find.byType(TextField), 'filtro');
    await tester.pump();
    // Antes de que venza el retardo (350 ms) se vacía el campo: la consulta vieja
    // no puede llegar después.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(milliseconds: 600));

    expect(changes, <String>['']);
  });

  testWidgets('el borde sube a `borderStrong` sobre la banda del POS', (
    tester,
  ) async {
    await _pumpField(tester);
    expect(_border(tester).top.color, EzyColors.borderDark);

    await _pumpField(tester, borderColor: EzyColors.borderDarkStrong);
    expect(_border(tester).top.color, EzyColors.borderDarkStrong);
  });
}
