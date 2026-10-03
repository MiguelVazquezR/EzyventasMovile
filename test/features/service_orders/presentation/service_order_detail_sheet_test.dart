import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_icon_button.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_detail_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'service_orders_sheets_harness.dart';

/// Detalle de una orden tal como lo abre la pestaña «Órdenes».
///
/// Las anclas que se comprueban son las que el recorrido del teléfono
/// (`integration_test/qa_device_test.dart`) busca dentro de esta hoja: la
/// cabecera con el folio (y su botón de cierre) y el panel de impresión con
/// `Imprimir orden`.
Future<void> pumpOrderDetailSheet(
  WidgetTester tester, {
  FakeServiceOrdersRepository? repository,
  List<String> permissions = allOrderPermissions,
  bool withShift = true,
}) async {
  await useTallScreen(tester);

  await tester.pumpWidget(
    serviceOrdersSheetApp(
      openLabel: 'Abrir detalle',
      repository: repository ?? FakeServiceOrdersRepository(),
      permissions: permissions,
      session: withShift ? openOrderShift() : null,
      open: (context) =>
          showServiceOrderDetailSheet(context, serviceOrderId: 314),
    ),
  );

  await openSheet(tester, 'Abrir detalle');
}

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `DateFormat` de es-MX lanza
    // `LocaleDataException` al pintar la fecha de recepción.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets(
    'la cabecera usa el folio, el equipo y las acciones del sistema',
    (tester) async {
      await pumpOrderDetailSheet(tester);

      final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
      expect(header.title, 'OS-014');
      expect(header.subtitle, 'iPhone 13, pantalla rota');

      // Las dos acciones son botones del design system con su tooltip.
      expect(
        find.descendant(
          of: find.byType(EzySheetHeader),
          matching: find.byType(EzyIconButton),
        ),
        findsNWidgets(2),
      );
      expect(find.byTooltip('Actualizar'), findsOneWidget);
      expect(find.byTooltip('Cerrar'), findsOneWidget);
    },
  );

  testWidgets('la pestaña Orden pinta el stepper, los conceptos y el dock', (
    tester,
  ) async {
    await pumpOrderDetailSheet(tester);

    expect(find.text('OS-014'), findsOneWidget);
    expect(find.text('iPhone 13, pantalla rota'), findsWidgets);
    // Stepper completo (el estatus actual también sale en el badge).
    expect(find.text('PENDIENTE'), findsWidgets);
    expect(find.text('ENTREGADO'), findsOneWidget);
    // Pestaña por defecto: diagnóstico, conceptos y la ficha del cliente.
    expect(find.text('Display dañado'), findsOneWidget);
    expect(find.text('Mica templada'), findsOneWidget);
    // El tipo de concepto se pinta en una etiqueta aparte (`Refacción`).
    expect(find.text('Refacción'.toUpperCase()), findsOneWidget);
    expect(find.text('Llamar'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
    // El dock vive al pie: saldo, CTA y píldoras de acción.
    expect(find.text('SALDO POR COBRAR'), findsOneWidget);
    expect(find.text('Cobrar ahora'), findsOneWidget);
    expect(find.text('Cambiar estatus'), findsOneWidget);
    expect(find.text('Editar orden'), findsOneWidget);
    expect(find.text('Eliminar orden'), findsOneWidget);
    // Las otras dos pestañas no se construyen hasta que se tocan.
    expect(find.text('Utilidad neta'), findsNothing);
    expect(find.text('HISTORIAL'), findsNothing);
  });

  testWidgets('la pestaña Cobros reúne el panel financiero y los anticipos', (
    tester,
  ) async {
    await pumpOrderDetailSheet(tester);

    await tester.tap(find.text('Cobros'));
    await settleSheet(tester);

    // Comisión del técnico, utilidad y el anticipo de la venta vinculada.
    expect(find.text('Comisión del técnico'), findsOneWidget);
    expect(find.text('Utilidad neta'), findsOneWidget);
    expect(find.text('OS-V-006'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    // El contenido de la pestaña anterior se desmonta.
    expect(find.text('Display dañado'), findsNothing);
  });

  testWidgets('la pestaña Historial lista los movimientos de la orden', (
    tester,
  ) async {
    await pumpOrderDetailSheet(tester);

    await tester.tap(find.text('Historial'));
    await settleSheet(tester);

    // El título de la tarjeta va en micro-mayúsculas.
    expect(find.text('HISTORIAL'), findsOneWidget);
    expect(
      find.text('La orden de servicio ha sido actualizada'),
      findsOneWidget,
    );
  });

  testWidgets('entregar con saldo pendiente encadena el cobro', (tester) async {
    final repository = FakeServiceOrdersRepository(rememberStatus: true);
    await pumpOrderDetailSheet(tester, repository: repository);

    // Con `services.orders.change_status` el stepper es táctil: cuatro avances
    // llevan la orden de `pendiente` a `entregado` (el flujo son cinco pasos).
    for (var step = 0; step < 4; step++) {
      await tester.tap(find.byTooltip('Avanzar'));
      await settleSheet(tester);
    }

    expect(repository.statusCalls, 4);
    expect(repository.lastStatus, 'entregado');
    // Al quedar entregada con saldo pendiente, el cobro se abre solo.
    expect(find.text('Cobrar orden'), findsOneWidget);
  });

  testWidgets('sin permisos la hoja no ofrece ninguna acción', (tester) async {
    await pumpOrderDetailSheet(tester, permissions: const <String>[]);

    expect(find.text('OS-014'), findsOneWidget);
    // Sin `change_status` el stepper es de solo lectura y el dock no pinta
    // nada: ni saldo, ni CTA, ni píldoras.
    expect(find.byTooltip('Avanzar'), findsNothing);
    expect(find.text('SALDO POR COBRAR'), findsNothing);
    expect(find.text('Cobrar ahora'), findsNothing);
    expect(find.text('Cambiar estatus'), findsNothing);
    expect(find.text('Editar orden'), findsNothing);
    expect(find.text('Eliminar orden'), findsNothing);
    // Sin `see_financial_info` tampoco se muestran comisión ni utilidad.
    await tester.tap(find.text('Cobros'));
    await settleSheet(tester);
    expect(find.text('Comisión del técnico'), findsNothing);
    expect(find.text('Utilidad neta'), findsNothing);
  });

  testWidgets('el 422 del estatus se muestra desde errors.status[0]', (
    tester,
  ) async {
    await pumpOrderDetailSheet(
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

    await openSheet(tester, 'Cambiar estatus');

    // El paso actual es `pendiente`: el único paso hacia adelante natural de la
    // lista es `En progreso` (la etiqueta del stepper va en mayúsculas).
    await tester.tap(find.text('En progreso').last);
    await settleSheet(tester);

    // El mensaje lo pintan las dos capas: la hoja de estatus (arriba) y el
    // detalle que queda detrás, que también pinta `state.statusMessage`.
    expect(find.text('El estatus ya es el seleccionado.'), findsNWidgets(2));
    expect(find.text('Ocultar'), findsNWidgets(2));
  });

  testWidgets('el 422 de un avance del stepper se queda en el detalle', (
    tester,
  ) async {
    await pumpOrderDetailSheet(
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

    // El stepper avanza aquí mismo, sin abrir `Cambiar estatus`: el aviso tiene
    // que pintarse en el detalle (si no, el rechazo pasaría en silencio).
    await tester.tap(find.byTooltip('Avanzar'));
    await settleSheet(tester);

    expect(find.text('El estatus ya es el seleccionado.'), findsOneWidget);
    expect(find.text('Ocultar'), findsOneWidget);
  });

  testWidgets('una orden sin venta vinculada avisa y ofrece cobrar', (
    tester,
  ) async {
    await pumpOrderDetailSheet(
      tester,
      repository: FakeServiceOrdersRepository(isLegacy: true),
    );

    expect(find.text('OS-014'), findsOneWidget);
    // El aviso vive en el dock, junto al CTA que crea la venta.
    expect(
      find.text(
        'Esta orden no tiene venta vinculada: al cobrar se creará '
        'automáticamente.',
      ),
      findsOneWidget,
    );
    // El botón sigue disponible: el cobro crea la venta con
    // `ensure-transaction` antes de registrar el anticipo.
    expect(find.text('Cobrar ahora'), findsOneWidget);
  });

  testWidgets('el botón de cerrar baja la hoja', (tester) async {
    await pumpOrderDetailSheet(tester);

    await tester.tap(find.byTooltip('Cerrar'));
    await settleSheet(tester);

    expect(find.text('OS-014'), findsNothing);
  });
}
