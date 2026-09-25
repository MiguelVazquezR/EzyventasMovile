import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_dialog.dart';
import 'package:ezyventas_app/core/widgets/money_field.dart';
import 'package:ezyventas_app/features/sales/presentation/widgets/transaction_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'sales_sheets_harness.dart';

/// Hoja de edición de un pago.
///
/// Se abre como en la app: primero el detalle de la venta (que carga el id en el
/// controlador) y desde ahí el pago con `Editar pago`.
Future<void> pumpEditPaymentSheet(
  WidgetTester tester, {
  FakeSalesRepository? repository,
}) async {
  await useTallScreen(tester);

  await tester.pumpWidget(
    salesSheetApp(
      openLabel: 'Abrir detalle',
      repository: repository ?? FakeSalesRepository(),
      session: openShift(),
      open: (context) =>
          showTransactionDetailSheet(context, transactionId: 987),
    ),
  );

  await openSheet(tester, 'Abrir detalle');

  await tester.tap(find.byTooltip('Editar pago').first);
  await settleSheet(tester);
}

/// Campo de monto del pago.
Finder amountField() => find.descendant(
  of: find.byType(MoneyField),
  matching: find.byType(TextField),
);

/// Botón del design system dentro de la hoja.
EzyButton sheetButton(WidgetTester tester, String label) =>
    tester.widget<EzyButton>(find.widgetWithText(EzyButton, label));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la cabecera explica qué concilia el servidor', (tester) async {
    await pumpEditPaymentSheet(tester);

    // La última cabecera es la de la hoja de edición (el detalle sigue detrás).
    final header = tester.widget<EzySheetHeader>(
      find.byType(EzySheetHeader).last,
    );
    expect(header.title, 'Editar pago');
    expect(header.subtitle, contains('El servidor concilia la cuenta'));
    expect(find.byTooltip('Cerrar'), findsWidgets);
  });

  testWidgets('precarga el monto y el método del pago', (tester) async {
    await pumpEditPaymentSheet(tester);

    expect(find.text('70.00'), findsOneWidget);
    expect(find.text('Efectivo'), findsWidgets);
    expect(find.text('MÉTODO DE PAGO *'), findsOneWidget);
    expect(find.text('NOTAS INTERNAS / REFERENCIA'), findsOneWidget);
    expect(sheetButton(tester, 'Guardar cambios').onPressed, isNotNull);
  });

  testWidgets('sin monto no se puede guardar', (tester) async {
    await pumpEditPaymentSheet(tester);

    await tester.enterText(amountField(), '0');
    await settleSheet(tester);

    expect(sheetButton(tester, 'Guardar cambios').onPressed, isNull);
  });

  testWidgets('guardar manda el pago al servidor y cierra la hoja', (
    tester,
  ) async {
    final repository = FakeSalesRepository();

    await pumpEditPaymentSheet(tester, repository: repository);

    await tester.tap(find.widgetWithText(EzyButton, 'Guardar cambios'));
    await settleSheet(tester);

    expect(repository.updateCalls, 1);
    expect(find.text('Editar pago'), findsNothing);
  });

  testWidgets('el error del servidor se muestra desde su message', (
    tester,
  ) async {
    final repository = FakeSalesRepository()
      ..updateFailure = ApiException(
        message: 'El monto del pago no puede ser mayor al de la venta.',
        statusCode: 422,
      );

    await pumpEditPaymentSheet(tester, repository: repository);

    await tester.tap(find.widgetWithText(EzyButton, 'Guardar cambios'));
    await settleSheet(tester);

    expect(
      find.text('El monto del pago no puede ser mayor al de la venta.'),
      findsWidgets,
    );
    expect(find.text('Editar pago'), findsOneWidget);
  });

  testWidgets('borrar pide confirmación antes de eliminar el pago', (
    tester,
  ) async {
    final repository = FakeSalesRepository();

    await pumpEditPaymentSheet(tester, repository: repository);

    await tester.tap(find.widgetWithText(EzyButton, 'Eliminar pago'));
    await settleSheet(tester);

    expect(find.byType(EzyDialog), findsOneWidget);
    expect(
      find.text(
        '¿Estás seguro de que quieres eliminar este pago '
        'permanentemente?',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(EzyDialog),
        matching: find.widgetWithText(EzyButton, 'Eliminar pago'),
      ),
    );
    await settleSheet(tester);

    expect(repository.deleteCalls, 1);
    expect(find.text('Editar pago'), findsNothing);
  });

  testWidgets('cancelar la confirmación deja el pago como estaba', (
    tester,
  ) async {
    final repository = FakeSalesRepository();

    await pumpEditPaymentSheet(tester, repository: repository);

    await tester.tap(find.widgetWithText(EzyButton, 'Eliminar pago'));
    await settleSheet(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(EzyDialog),
        matching: find.widgetWithText(EzyButton, 'Cancelar'),
      ),
    );
    await settleSheet(tester);

    expect(find.byType(EzyDialog), findsNothing);
    expect(repository.deleteCalls, 0);
    expect(find.text('Editar pago'), findsOneWidget);
  });
}
