import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_chip.dart';
import 'package:ezyventas_app/features/cash/data/models/bank_account.dart';
import 'package:ezyventas_app/features/pos/data/models/payment_draft.dart';
import 'package:ezyventas_app/features/service_orders/application/service_orders_controller.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_payment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'service_orders_sheets_harness.dart';

/// Hoja de anticipo tal como la abre el detalle de la orden.
///
/// El detalle se carga primero en el controlador (`load`) y hay un turno de
/// caja abierto: sin él `POST /service-orders/{id}/payments` responde
/// `422 session_required`.
Future<ProviderContainer> pumpPaymentSheet(
  WidgetTester tester, {
  FakeServiceOrdersRepository? repository,
  List<String> permissions = allOrderPermissions,
  bool withShift = true,
  bool withBanks = false,
  String customerBalance = '-350.00',
}) async {
  await useTallScreen(tester);

  final orders =
      repository ??
      FakeServiceOrdersRepository(customerBalance: customerBalance);
  final banks = withBanks ? orderBankAccounts() : const <BankAccount>[];
  final container = serviceOrdersContainer(
    repository: orders,
    permissions: permissions,
    session: withShift ? openOrderShift() : null,
    banks: banks,
  );
  addTearDown(container.dispose);

  await container.read(serviceOrderDetailControllerProvider.notifier).load(314);

  await tester.pumpWidget(
    serviceOrdersSheetAppIn(
      container: container,
      openLabel: 'Cobrar',
      open: (context) =>
          showServiceOrderPaymentSheet(context, detail: orders.detail),
    ),
  );

  await openSheet(tester, 'Cobrar');

  return container;
}

/// El botón principal del anticipo, que solo se habilita cuando el cobro es
/// válido (cubre algo, no sobra y los pagos están completos).
EzyButton submitButton(WidgetTester tester) => tester.widget<EzyButton>(
  find.widgetWithText(EzyButton, 'Registrar anticipo'),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la cabecera usa el folio y el cliente de la orden', (
    tester,
  ) async {
    await pumpPaymentSheet(tester);

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Cobrar orden');
    expect(header.subtitle, 'Folio OS-014 · Ana Ramírez');
    expect(find.byTooltip('Cerrar'), findsOneWidget);
  });

  testWidgets('pinta el resumen, el pago precargado y el resultado', (
    tester,
  ) async {
    await pumpPaymentSheet(tester);

    // El título de cada tarjeta va en micro-mayúsculas.
    expect(find.text('RESUMEN DE LA ORDEN'), findsOneWidget);
    expect(find.text('PAGO'), findsOneWidget);
    expect(find.text('RESULTADO DEL COBRO'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Pagado'), findsOneWidget);
    expect(find.text('Saldo pendiente'), findsOneWidget);
    expect(find.text('Cubierto'), findsOneWidget);
    expect(find.text('Queda pendiente'), findsOneWidget);

    // El efectivo viene precargado por el saldo pendiente.
    expect(find.text('Efectivo'), findsOneWidget);
    // `MoneyField` pinta su etiqueta con `FieldLabel` (micro-mayúsculas).
    expect(find.text('MONTO'), findsOneWidget);
    expect(submitButton(tester).onPressed, isNotNull);
  });

  testWidgets('los métodos disponibles son chips del sistema', (tester) async {
    await pumpPaymentSheet(tester);

    expect(find.text('AGREGAR MÉTODO'), findsOneWidget);
    // Los dos métodos que faltan, como chips del design system.
    expect(find.byType(EzyChip), findsNWidgets(2));
    expect(find.text('Tarjeta'), findsOneWidget);
    expect(find.text('Transferencia'), findsOneWidget);
  });

  testWidgets('quitar un método lo saca del cobro', (tester) async {
    await pumpPaymentSheet(tester);

    await tester.tap(find.byTooltip('Quitar método'));
    await settleSheet(tester);

    // Ya no queda ningún pago capturado y el cobro no se puede enviar.
    expect(find.byTooltip('Quitar método'), findsNothing);
    expect(find.text('MONTO'), findsNothing);
    expect(submitButton(tester).onPressed, isNull);
    // El método retirado vuelve a estar disponible como chip.
    expect(find.byType(EzyChip), findsNWidgets(3));
    expect(find.text('Efectivo'), findsOneWidget);
  });

  testWidgets('tarjeta exige la cuenta destino (FieldLabel en mayúsculas)', (
    tester,
  ) async {
    await pumpPaymentSheet(tester);

    await tester.tap(find.text('Tarjeta'));
    await settleSheet(tester);

    expect(find.text('CUENTA DESTINO *'), findsOneWidget);
    // Sin cuentas asignadas el servidor no puede recibir el pago.
    expect(
      find.text('No tienes cuentas bancarias asignadas para este método.'),
      findsOneWidget,
    );
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('con cuentas bancarias la tarjeta ofrece el selector', (
    tester,
  ) async {
    await pumpPaymentSheet(tester, withBanks: true);

    await tester.tap(find.text('Tarjeta'));
    await settleSheet(tester);

    expect(find.text('CUENTA DESTINO *'), findsOneWidget);

    // La cuenta se elige en el desplegable (los ítems se construyen al abrirlo).
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await settleSheet(tester);
    await tester.pump();

    expect(find.text('Cuenta principal - BBVA (...4471)'), findsWidgets);
  });

  testWidgets('registrar el anticipo manda la sesión, el pago y el saldo', (
    tester,
  ) async {
    final orders = FakeServiceOrdersRepository();

    await pumpPaymentSheet(tester, repository: orders);

    await tester.tap(find.widgetWithText(EzyButton, 'Registrar anticipo'));
    await settleSheet(tester);
    await tester.pump();

    expect(orders.paymentCalls, 1);
    expect(orders.lastSessionId, 41);
    expect(orders.lastPayments, hasLength(1));
    expect(orders.lastPayments.single.method, PosPaymentMethod.cash);
    expect(orders.lastPayments.single.amount, 700);
    expect(orders.lastUseBalance, isFalse);
  });

  testWidgets('sin turno de caja el anticipo no se envía', (tester) async {
    final orders = FakeServiceOrdersRepository();

    await pumpPaymentSheet(tester, repository: orders, withShift: false);

    await tester.tap(find.widgetWithText(EzyButton, 'Registrar anticipo'));
    await settleSheet(tester);

    expect(orders.paymentCalls, 0);
  });

  testWidgets('el saldo a favor no puede sobrepasar el saldo pendiente', (
    tester,
  ) async {
    await pumpPaymentSheet(tester, customerBalance: '350.00');

    expect(find.text('Usar saldo a favor'), findsOneWidget);
    expect(find.text(r'Disponible $350.00'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await settleSheet(tester);

    // 700 del efectivo precargado + 350 del saldo = 1,050 contra 700 debidos.
    expect(
      find.text('El monto excede el saldo pendiente de la orden.'),
      findsOneWidget,
    );
    expect(submitButton(tester).onPressed, isNull);
  });

  testWidgets('el 422 del servidor se muestra como aviso', (tester) async {
    await pumpPaymentSheet(
      tester,
      repository: FakeServiceOrdersRepository(
        paymentFailure: ApiException.fromResponse(422, <String, dynamic>{
          'message':
              'Necesitas una sesión de caja abierta para registrar pagos.',
        }),
      ),
    );

    await tester.tap(find.widgetWithText(EzyButton, 'Registrar anticipo'));
    await settleSheet(tester);
    await tester.pump();

    expect(
      find.text('Necesitas una sesión de caja abierta para registrar pagos.'),
      findsOneWidget,
    );
    expect(find.text('Ocultar'), findsOneWidget);
  });
}
