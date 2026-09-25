import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/features/service_orders/application/service_orders_controller.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_status_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'service_orders_sheets_harness.dart';

/// Hoja de estatus tal como la abre el detalle de la orden.
///
/// El detalle se carga primero en el controlador (`load`): la hoja trabaja
/// sobre el id que vive ahí, igual que en la app.
Future<ProviderContainer> pumpStatusSheet(
  WidgetTester tester, {
  FakeServiceOrdersRepository? repository,
  List<String> permissions = allOrderPermissions,
  String status = 'pendiente',
  void Function(bool? result)? onResult,
}) async {
  await useTallScreen(tester);

  final orders = repository ?? FakeServiceOrdersRepository(status: status);
  final container = serviceOrdersContainer(
    repository: orders,
    permissions: permissions,
  );
  addTearDown(container.dispose);

  await container.read(serviceOrderDetailControllerProvider.notifier).load(314);

  await tester.pumpWidget(
    serviceOrdersSheetAppIn(
      container: container,
      openLabel: 'Cambiar estatus',
      open: (context) async {
        final result = await showServiceOrderStatusSheet(
          context,
          detail: orders.detail,
        );
        onResult?.call(result);
      },
    ),
  );

  await openSheet(tester, 'Cambiar estatus');

  return container;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la cabecera usa el folio y las acciones del sistema', (
    tester,
  ) async {
    await pumpStatusSheet(tester);

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Estatus de la orden');
    expect(header.subtitle, 'Folio OS-014');
    expect(find.byTooltip('Cerrar'), findsOneWidget);
    expect(find.text('Cerrar'), findsNothing, reason: 'es botón de icono');
  });

  testWidgets('ofrece los pasos siguientes y la cancelación', (tester) async {
    await pumpStatusSheet(tester);

    // El stepper (en micro-mayúsculas) y los botones de cada paso.
    expect(find.text('PENDIENTE'), findsOneWidget);
    expect(find.text('En progreso'), findsOneWidget);
    expect(find.text('Esperando refacción'), findsOneWidget);
    expect(find.text('Terminado'), findsOneWidget);
    expect(find.text('Entregado'), findsOneWidget);
    // Desde `pendiente` no hay pasos hacia atrás.
    expect(find.text('REGRESAR'), findsNothing);
    expect(find.text('Cancelar orden'), findsOneWidget);
  });

  testWidgets('avanzar cambia el estatus y cierra la hoja', (tester) async {
    bool? collected;
    final orders = FakeServiceOrdersRepository();

    await pumpStatusSheet(
      tester,
      repository: orders,
      onResult: (result) => collected = result,
    );

    await tester.tap(find.text('En progreso'));
    await settleSheet(tester);
    await tester.pump();

    expect(orders.lastStatus, 'en_progreso');
    expect(orders.statusCalls, 1);
    expect(collected, isFalse, reason: 'la orden sigue en el taller');
    expect(find.text('Estatus de la orden'), findsNothing);
  });

  testWidgets('entregar con saldo pendiente devuelve true para cobrar', (
    tester,
  ) async {
    bool? collected;

    await pumpStatusSheet(
      tester,
      status: 'terminado',
      onResult: (result) => collected = result,
    );

    await tester.tap(find.text('Entregado'));
    await settleSheet(tester);
    await tester.pump();

    expect(collected, isTrue, reason: 'la orden se entregó con saldo');
  });

  testWidgets('regresar un paso pide confirmación explícita (§8.2)', (
    tester,
  ) async {
    final orders = FakeServiceOrdersRepository(status: 'terminado');

    await pumpStatusSheet(tester, repository: orders);

    // El paso hacia atrás está en la card de regresar.
    expect(find.text('REGRESAR'), findsOneWidget);
    expect(
      find.text('Regresar el estatus requiere confirmación.'),
      findsOneWidget,
    );

    await tester.tap(find.text('En progreso').last);
    await settleSheet(tester);

    expect(
      find.textContaining(
        '¿Seguro que quieres regresar la orden a esta etapa?',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Nuevo estatus: En progreso.'), findsOneWidget);
    // Todavía no se llamó al servidor.
    expect(orders.statusCalls, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Regresar estatus'));
    await settleSheet(tester);
    await tester.pump();

    expect(orders.lastStatus, 'en_progreso');
  });

  testWidgets('cancelar la orden pide confirmación y libera el inventario', (
    tester,
  ) async {
    final orders = FakeServiceOrdersRepository();

    await pumpStatusSheet(tester, repository: orders);

    await tester.tap(find.text('Cancelar orden'));
    await settleSheet(tester);

    expect(
      find.textContaining('¿Seguro que quieres cancelar esta orden?'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar orden'));
    await settleSheet(tester);
    await tester.pump();

    expect(orders.lastStatus, 'cancelado');
    expect(find.text('Estatus de la orden'), findsNothing);
  });

  testWidgets('una orden cancelada no ofrece ningún paso', (tester) async {
    await pumpStatusSheet(tester, status: 'cancelado');

    expect(find.text('CANCELADO'), findsOneWidget);
    expect(
      find.text('La orden está cancelada: su estatus ya no se puede cambiar.'),
      findsOneWidget,
    );
    expect(find.text('Cancelar orden'), findsNothing);
    expect(find.text('En progreso'), findsNothing);
  });

  testWidgets('el 422 muestra el motivo del servidor sin cerrar la hoja', (
    tester,
  ) async {
    await pumpStatusSheet(
      tester,
      repository: FakeServiceOrdersRepository(
        statusFailure: ApiException.fromResponse(422, <String, dynamic>{
          'message': 'El estatus ya es el seleccionado.',
          'errors': <String, dynamic>{
            'status': <String>['El estatus ya es el seleccionado.'],
          },
        }),
      ),
    );

    await tester.tap(find.text('En progreso'));
    await settleSheet(tester);
    await tester.pump();

    expect(find.text('El estatus ya es el seleccionado.'), findsOneWidget);
    expect(find.text('Ocultar'), findsOneWidget);
    expect(find.text('Estatus de la orden'), findsOneWidget);
  });
}
