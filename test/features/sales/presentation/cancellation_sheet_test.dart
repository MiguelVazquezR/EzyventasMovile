import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_selectable_tile.dart';
import 'package:ezyventas_app/features/sales/application/sales_controller.dart';
import 'package:ezyventas_app/features/sales/data/models/refund_method.dart';
import 'package:ezyventas_app/features/sales/presentation/widgets/cancellation_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'sales_sheets_harness.dart';

/// Hoja de anulación (reembolso o penalización) de una venta.
Future<void> pumpCancellationSheet(
  WidgetTester tester, {
  FakeSalesRepository? repository,
  bool withShift = true,
  List<String> permissions = allSalesPermissions,
}) async {
  await useTallScreen(tester);

  final detail = transactionDetail();
  final container = salesContainer(
    repository: repository ?? FakeSalesRepository(),
    permissions: permissions,
    session: withShift ? openShift() : null,
    banks: bankAccountsFixture(),
  );
  addTearDown(container.dispose);

  // El detalle ya estaba cargado cuando el usuario pidió anular.
  await container.read(transactionDetailControllerProvider.notifier).load(987);

  await tester.pumpWidget(
    salesSheetAppIn(
      container: container,
      openLabel: 'Abrir anulación',
      open: (context) => showCancellationSheet(context, detail: detail),
    ),
  );

  await openSheet(tester, 'Abrir anulación');
}

/// Fila seleccionable que contiene ese texto (opciones y métodos).
///
/// Los métodos de reembolso van anidados dentro de la opción de devolución, así
/// que se busca la fila por su título y no por el árbol.
EzySelectableTile tileWith(WidgetTester tester, String title) => tester
    .widgetList<EzySelectableTile>(find.byType(EzySelectableTile))
    .firstWhere((tile) => tile.title == title);

/// Botón de confirmación de la anulación.
EzyButton confirmButton(
  WidgetTester tester, [
  String label = 'Confirmar devolución',
]) => tester.widget<EzyButton>(find.widgetWithText(EzyButton, label));

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la cabecera explica que se cancela o se reembolsa', (
    tester,
  ) async {
    await pumpCancellationSheet(tester);

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Anular transacción');
    expect(header.subtitle, 'Cancelación o reembolso');
    expect(find.byTooltip('Cerrar'), findsOneWidget);
    // Avisa de los pagos ya registrados con el monto real del servidor.
    expect(find.textContaining('tiene pagos registrados por'), findsOneWidget);
  });

  testWidgets('con caja abierta el reembolso arranca en efectivo', (
    tester,
  ) async {
    await pumpCancellationSheet(tester);

    expect(find.text('Devolver al cliente (reembolso)'), findsOneWidget);
    expect(find.text('Cobrar como penalización'), findsOneWidget);
    expect(find.text('Entregar efectivo de caja'), findsOneWidget);
    expect(find.text('Transferencia bancaria'), findsOneWidget);
    expect(find.text('Abonar a su saldo a favor'), findsOneWidget);

    expect(
      tileWith(tester, 'Devolver al cliente (reembolso)').isSelected,
      isTrue,
    );
    expect(tileWith(tester, 'Entregar efectivo de caja').isSelected, isTrue);
    expect(tileWith(tester, 'Transferencia bancaria').isSelected, isFalse);
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('la transferencia exige la cuenta destino del negocio', (
    tester,
  ) async {
    final repository = FakeSalesRepository();

    await pumpCancellationSheet(tester, repository: repository);

    await tester.tap(find.text('Transferencia bancaria'));
    await settleSheet(tester);

    expect(find.text('CUENTA DESTINO *'), findsOneWidget);
    expect(
      find.text(
        'Selecciona la cuenta bancaria para el reembolso por transferencia.',
      ),
      findsOneWidget,
    );
    expect(confirmButton(tester).onPressed, isNull);

    // Se elige la cuenta del negocio y el reembolso queda listo.
    await tester.tap(find.text('Seleccionar cuenta…'));
    await settleSheet(tester);
    await tester.tap(find.text('Cuenta principal - BBVA (...4471)').last);
    await settleSheet(tester);

    expect(confirmButton(tester).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(EzyButton, 'Confirmar devolución'));
    await settleSheet(tester);

    expect(repository.refundCalls, 1);
    expect(repository.lastRefundMethod, RefundMethod.transfer);
    expect(repository.lastRefundBankAccountId, 2);
    // La hoja se cierra cuando el servidor confirma la anulación.
    expect(find.text('Anular transacción'), findsNothing);
  });

  testWidgets('la penalización se confirma con su propio botón', (
    tester,
  ) async {
    final repository = FakeSalesRepository();

    await pumpCancellationSheet(tester, repository: repository);

    await tester.tap(find.text('Cobrar como penalización'));
    await settleSheet(tester);

    expect(tileWith(tester, 'Cobrar como penalización').isSelected, isTrue);
    expect(
      confirmButton(tester, 'Confirmar penalización').onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(EzyButton, 'Confirmar penalización'));
    await settleSheet(tester);

    expect(repository.cancelCalls, 1);
    expect(repository.refundCalls, 0);
    expect(find.text('Anular transacción'), findsNothing);
  });

  testWidgets('sin permiso de reembolso solo queda la penalización', (
    tester,
  ) async {
    await pumpCancellationSheet(
      tester,
      permissions: const <String>[
        'transactions.access',
        'transactions.see_details',
        'transactions.cancel',
      ],
    );

    expect(find.text('Devolver al cliente (reembolso)'), findsNothing);
    expect(tileWith(tester, 'Cobrar como penalización').isSelected, isTrue);
    expect(find.text('Confirmar penalización'), findsOneWidget);
  });

  testWidgets('sin caja abierta el reembolso cae al saldo a favor', (
    tester,
  ) async {
    await pumpCancellationSheet(tester, withShift: false);

    expect(
      find.text('No hay caja abierta para devolver efectivo.'),
      findsOneWidget,
    );
    expect(tileWith(tester, 'Abonar a su saldo a favor').isSelected, isTrue);
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('muestra el message del servidor cuando la anulación falla', (
    tester,
  ) async {
    final repository = FakeSalesRepository()
      ..mutationFailure = ApiException(
        message: 'La venta ya fue anulada.',
        statusCode: 422,
      );

    await pumpCancellationSheet(tester, repository: repository);

    await tester.tap(find.text('Cobrar como penalización'));
    await settleSheet(tester);
    await tester.tap(find.widgetWithText(EzyButton, 'Confirmar penalización'));
    await settleSheet(tester);

    expect(find.text('La venta ya fue anulada.'), findsOneWidget);
    // La hoja sigue abierta para que el usuario corrija.
    expect(find.text('Anular transacción'), findsOneWidget);
  });
}
