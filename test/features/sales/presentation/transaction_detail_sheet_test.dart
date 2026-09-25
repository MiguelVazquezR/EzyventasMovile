import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_icon_button.dart';
import 'package:ezyventas_app/features/sales/presentation/widgets/transaction_detail_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'sales_sheets_harness.dart';

/// Detalle de una venta tal como lo abre la pestaña «Ventas».
///
/// Las anclas que se comprueban son las que el recorrido del teléfono
/// (`integration_test/qa_device_test.dart`) busca dentro de esta hoja: el
/// tooltip `Cerrar` de la cabecera y el botón `Imprimir ticket` del panel.
Future<void> pumpDetailSheet(
  WidgetTester tester, {
  FakeSalesRepository? repository,
  List<String> permissions = allSalesPermissions,
  bool withShift = true,
}) async {
  await useTallScreen(tester);

  await tester.pumpWidget(
    salesSheetApp(
      openLabel: 'Abrir detalle',
      repository: repository ?? FakeSalesRepository(),
      permissions: permissions,
      session: withShift ? openShift() : null,
      open: (context) =>
          showTransactionDetailSheet(context, transactionId: 987),
    ),
  );

  await openSheet(tester, 'Abrir detalle');
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la cabecera usa el folio, el canal y las acciones del sistema', (
    tester,
  ) async {
    await pumpDetailSheet(tester);

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'V-014');
    // El subtítulo une la fecha del servidor con el canal de la venta.
    expect(header.subtitle, contains('Punto de venta'));

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
  });

  testWidgets('pinta artículos, pagos, totales e información de la venta', (
    tester,
  ) async {
    await pumpDetailSheet(tester);

    // El título de cada tarjeta va en micro-mayúsculas.
    expect(find.text('ARTÍCULOS'), findsOneWidget);
    expect(find.text('PAGOS REALIZADOS'), findsOneWidget);
    expect(find.text('TOTALES'), findsOneWidget);
    expect(find.text('INFORMACIÓN DE LA VENTA'), findsOneWidget);
    expect(find.text('TICKET'), findsOneWidget);

    // Contenido real del detalle.
    expect(find.text('Filtro de aceite'), findsOneWidget);
    expect(find.text('Aceite 1L'), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Transferencia'), findsOneWidget);
    expect(find.text('Ana Ramírez'), findsWidgets);
    expect(find.text('María López'), findsOneWidget);
    expect(find.text('Entregar por la tarde'), findsOneWidget);
    expect(find.text('Sucursal Centro'), findsOneWidget);
  });

  testWidgets('el documento se puede imprimir (ancla del recorrido real)', (
    tester,
  ) async {
    await pumpDetailSheet(tester);

    expect(find.widgetWithText(EzyButton, 'Imprimir ticket'), findsOneWidget);
    expect(find.text('Enviar por WhatsApp'), findsOneWidget);

    // Ya no queda el aviso de que la impresión «se habilitará»: el panel de
    // arriba la tiene funcionando.
    expect(
      find.textContaining('cuando se habilite la impresión'),
      findsNothing,
    );
  });

  testWidgets('con permisos ofrece abono y anulación', (tester) async {
    await pumpDetailSheet(tester);

    expect(find.text('Registrar abono'), findsOneWidget);
    expect(find.text('Cancelar o reembolsar'), findsOneWidget);
  });

  testWidgets('sin permisos no ofrece ninguna acción de negocio', (
    tester,
  ) async {
    await pumpDetailSheet(tester, permissions: const <String>[]);

    expect(find.text('Registrar abono'), findsNothing);
    expect(find.text('Cancelar o reembolsar'), findsNothing);
    // El detalle sigue siendo de solo lectura.
    expect(find.text('V-014'), findsOneWidget);
    expect(find.text('ARTÍCULOS'), findsOneWidget);
  });

  testWidgets('sin turno de caja explica por qué no se puede abonar', (
    tester,
  ) async {
    await pumpDetailSheet(tester, withShift: false);

    expect(
      find.text('Necesitas una sesión de caja abierta para registrar abonos.'),
      findsOneWidget,
    );
    expect(find.text('Ir a caja'), findsOneWidget);
  });

  testWidgets('los pagos se editan y se borran con botones del sistema', (
    tester,
  ) async {
    await pumpDetailSheet(tester);

    expect(find.byTooltip('Editar pago'), findsNWidgets(2));
    expect(find.byTooltip('Eliminar pago'), findsNWidgets(2));
  });

  testWidgets('el botón de cerrar baja la hoja', (tester) async {
    await pumpDetailSheet(tester);

    await tester.tap(find.byTooltip('Cerrar'));
    await settleSheet(tester);

    expect(find.text('ARTÍCULOS'), findsNothing);
  });
}
