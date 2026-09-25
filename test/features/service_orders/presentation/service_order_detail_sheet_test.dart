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

  testWidgets('el detalle pinta stepper, conceptos, saldo y anticipos', (
    tester,
  ) async {
    await pumpOrderDetailSheet(tester);

    expect(find.text('OS-014'), findsOneWidget);
    expect(find.text('iPhone 13, pantalla rota'), findsWidgets);
    // Stepper completo (el estatus actual también sale en el badge).
    expect(find.text('PENDIENTE'), findsWidgets);
    expect(find.text('ENTREGADO'), findsOneWidget);
    expect(find.text('Display dañado'), findsOneWidget);
    // Acciones visibles con todos los permisos.
    expect(find.text('Cobrar ahora'), findsOneWidget);
    expect(find.text('Cambiar estatus'), findsOneWidget);
    expect(find.text('Editar orden'), findsOneWidget);
    expect(find.text('Eliminar orden'), findsOneWidget);
    // Conceptos, panel financiero (con utilidad) y anticipos de la venta.
    expect(find.text('Mica templada'), findsOneWidget);
    // El tipo de concepto se pinta en una etiqueta aparte (`Refacción`).
    expect(find.text('Refacción'.toUpperCase()), findsOneWidget);
    expect(find.text('Comisión del técnico'), findsOneWidget);
    expect(find.text('Utilidad neta'), findsOneWidget);
    expect(find.text('OS-V-006'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    // Historial de cambios (el título de la tarjeta va en micro-mayúsculas).
    expect(find.text('HISTORIAL'), findsOneWidget);
    expect(
      find.text('La orden de servicio ha sido actualizada'),
      findsOneWidget,
    );
  });

  testWidgets('sin permisos la hoja no ofrece ninguna acción', (tester) async {
    await pumpOrderDetailSheet(tester, permissions: const <String>[]);

    expect(find.text('OS-014'), findsOneWidget);
    expect(find.text('Cobrar ahora'), findsNothing);
    expect(find.text('Cambiar estatus'), findsNothing);
    expect(find.text('Editar orden'), findsNothing);
    expect(find.text('Eliminar orden'), findsNothing);
    // Sin `see_financial_info` tampoco se muestra la utilidad.
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
