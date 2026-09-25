import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Diálogo del design system: `EzyDialog`, la confirmación y la captura de un
/// dato (contraseña).
void main() {
  /// App mínima con el botón que abre el diálogo que se prueba.
  Widget app({
    required Future<void> Function(BuildContext context) open,
    double textScale = 1,
  }) => MaterialApp(
    theme: EzyTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => open(context),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('pinta el título, el cuerpo y las acciones del sistema', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        open: (context) => showDialog<void>(
          context: context,
          builder: (dialogContext) => EzyDialog(
            title: 'Eliminar orden',
            message: 'Esta acción no se puede deshacer.',
            actions: <Widget>[
              EzyButton(
                label: 'Cancelar',
                variant: EzyButtonVariant.outline,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              EzyButton(
                label: 'Eliminar',
                variant: EzyButtonVariant.danger,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byType(EzyDialog), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Eliminar orden'), findsOneWidget);
    expect(find.text('Esta acción no se puede deshacer.'), findsOneWidget);

    final confirm = tester.widget<EzyButton>(
      find.widgetWithText(EzyButton, 'Eliminar'),
    );
    expect(confirm.variant, EzyButtonVariant.danger);

    // El cuerpo vive sobre el panel del tema, no sobre el gris de Material.
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.backgroundColor, isNotNull);
  });

  testWidgets('la confirmación devuelve true al confirmar y false al salir', (
    tester,
  ) async {
    final results = <bool>[];

    await tester.pumpWidget(
      app(
        open: (context) async => results.add(
          await showEzyConfirmDialog(
            context,
            title: 'Eliminar pago',
            message: '¿Estás seguro de que quieres eliminar este pago?',
            confirmLabel: 'Eliminar pago',
            isDestructive: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(results, <bool>[false]);

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(EzyButton, 'Eliminar pago'));
    await tester.pumpAndSettle();

    expect(results, <bool>[false, true]);

    // Tocar fuera del diálogo también cuenta como cancelar.
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();

    expect(results, <bool>[false, true, false]);
  });

  testWidgets('la captura de un dato se habilita al escribir', (tester) async {
    final entered = <String?>[];

    await tester.pumpWidget(
      app(
        open: (context) async => entered.add(
          await showEzyPromptDialog(
            context,
            title: 'Confirmar cierre',
            message: 'Escribe tu contraseña para confirmar el cierre.',
            fieldLabel: 'Contraseña',
            confirmLabel: 'Cerrar otras sesiones',
            obscureText: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    final confirm = find.widgetWithText(EzyButton, 'Cerrar otras sesiones');

    // Sin texto no hay acción: el diálogo no se cierra en vano.
    expect(tester.widget<EzyButton>(confirm).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'secreta');
    await tester.pump();

    expect(tester.widget<EzyButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(entered, <String?>['secreta']);
    expect(find.byType(EzyDialog), findsNothing);
  });

  testWidgets('con texto grande el diálogo no desborda', (tester) async {
    await tester.pumpWidget(
      app(
        textScale: 1.3,
        open: (context) => showEzyConfirmDialog(
          context,
          title: 'Cancelar orden',
          message:
              '¿Seguro que quieres cancelar esta orden? El inventario de las '
              'refacciones se devolverá al stock y la venta vinculada se '
              'ajustará.',
          confirmLabel: 'Cancelar orden',
          cancelLabel: 'Regresar',
          isDestructive: true,
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Regresar'), findsOneWidget);
    expect(find.text('Cancelar orden'), findsNWidgets(2));
  });
}
