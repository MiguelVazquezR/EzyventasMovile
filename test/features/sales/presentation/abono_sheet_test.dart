import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_chip.dart';
import 'package:ezyventas_app/core/widgets/money_field.dart';
import 'package:ezyventas_app/features/sales/application/sales_controller.dart';
import 'package:ezyventas_app/features/sales/presentation/widgets/abono_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'sales_sheets_harness.dart';

/// Hoja de abono de una venta con saldo pendiente.
Future<void> pumpAbonoSheet(
  WidgetTester tester, {
  FakeSalesRepository? repository,
  String customerBalance = '-350.00',
  bool withShift = true,
}) async {
  await useTallScreen(tester);

  final detail = transactionDetail(customerBalance: customerBalance);
  final container = salesContainer(
    repository: repository ?? FakeSalesRepository(),
    session: withShift ? openShift() : null,
    banks: bankAccountsFixture(),
  );
  addTearDown(container.dispose);

  // El detalle ya estaba cargado cuando el usuario abrió el abono: el
  // controlador guarda el id de la venta y es el que registra la operación.
  await container.read(transactionDetailControllerProvider.notifier).load(987);

  await tester.pumpWidget(
    salesSheetAppIn(
      container: container,
      openLabel: 'Abrir abono',
      open: (context) => showAbonoSheet(context, detail: detail),
    ),
  );

  await openSheet(tester, 'Abrir abono');
}

/// Campo de monto del abono (efectivo precargado).
Finder abonoAmountField() => find.descendant(
  of: find.byType(MoneyField),
  matching: find.byType(TextField),
);

/// Botón principal del abono.
EzyButton submitButton(WidgetTester tester) =>
    tester.widget<EzyButton>(find.widgetWithText(EzyButton, 'Registrar abono'));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la cabecera une el folio con el cliente', (tester) async {
    await pumpAbonoSheet(tester);

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Registrar abono');
    expect(header.subtitle, 'Folio V-014 · Ana Ramírez');
    expect(find.byTooltip('Cerrar'), findsOneWidget);
  });

  testWidgets('precarga el efectivo por el saldo pendiente', (tester) async {
    await pumpAbonoSheet(tester);

    expect(find.text('RESUMEN DE LA VENTA'), findsOneWidget);
    expect(find.text('Saldo pendiente'), findsOneWidget);
    expect(find.text('PAGO'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    // El monto nace con lo que falta por cobrar.
    expect(find.text('200.00'), findsOneWidget);
  });

  testWidgets('Liquidar saldo es del design system y rellena el efectivo', (
    tester,
  ) async {
    await pumpAbonoSheet(tester);

    await tester.enterText(abonoAmountField(), '50');
    await settleSheet(tester);

    // Quedó saldo a medias: aparece la acción del design system.
    final liquidar = find.widgetWithText(EzyButton, 'Liquidar saldo');
    expect(liquidar, findsOneWidget);
    expect(find.textContaining('Quedarán'), findsOneWidget);

    await tester.tap(liquidar);
    await settleSheet(tester);

    expect(find.widgetWithText(EzyButton, 'Liquidar saldo'), findsNothing);
    expect(find.text('200.00'), findsOneWidget);
  });

  testWidgets('avisa cuando el monto excede el saldo pendiente', (
    tester,
  ) async {
    await pumpAbonoSheet(tester);

    await tester.enterText(abonoAmountField(), '300');
    await settleSheet(tester);

    expect(
      find.text('El monto total del pago excede el saldo pendiente.'),
      findsOneWidget,
    );
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('con saldo a favor lo aplica y retira el efectivo', (
    tester,
  ) async {
    final repository = FakeSalesRepository();

    await pumpAbonoSheet(
      tester,
      repository: repository,
      customerBalance: '350.00',
    );

    expect(find.text('SALDO A FAVOR'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await settleSheet(tester);

    // El saldo a favor cubre el pendiente: el efectivo precargado se retira y
    // solo queda el chip para volver a agregarlo.
    expect(find.byType(MoneyField), findsNothing);
    expect(find.widgetWithText(EzyChip, 'Efectivo'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(EzyButton, 'Registrar abono'));
    await settleSheet(tester);

    expect(repository.addPaymentCalls, 1);
    expect(repository.lastUseBalance, isTrue);
    expect(repository.lastPaidAmount, 0);
  });

  testWidgets('registra el abono y muestra el ticket del servidor', (
    tester,
  ) async {
    final repository = FakeSalesRepository(receipt: abonoReceiptFixture());

    await pumpAbonoSheet(tester, repository: repository);

    await tester.tap(find.widgetWithText(EzyButton, 'Registrar abono'));
    await settleSheet(tester);

    expect(repository.addPaymentCalls, 1);
    expect(repository.lastPaidAmount, 200);

    // El ticket que devolvió el servidor se pinta tal cual.
    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Abono registrado');
    expect(header.subtitle, 'Folio V-014');
    expect(find.text('TICKET DE ABONO'), findsOneWidget);
    expect(find.text(r'$200.00 MXN'), findsWidgets);
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('muestra el message del servidor cuando el abono falla', (
    tester,
  ) async {
    final repository = FakeSalesRepository()
      ..addPaymentFailure = ApiException(
        message: 'El monto excede el saldo pendiente de la venta.',
        statusCode: 422,
      );

    await pumpAbonoSheet(tester, repository: repository);

    await tester.tap(find.widgetWithText(EzyButton, 'Registrar abono'));
    await settleSheet(tester);

    expect(
      find.text('El monto excede el saldo pendiente de la venta.'),
      findsOneWidget,
    );
  });
}
