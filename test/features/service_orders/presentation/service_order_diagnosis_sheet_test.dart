import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_chip.dart';
import 'package:ezyventas_app/features/service_orders/application/service_orders_controller.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_diagnosis_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'service_orders_sheets_harness.dart';

/// Hoja de diagnóstico tal como la abre el detalle de la orden.
///
/// El detalle se carga primero en el controlador: el diagnóstico se guarda
/// contra el id que vive ahí.
Future<ProviderContainer> pumpDiagnosisSheet(
  WidgetTester tester, {
  FakeServiceOrdersRepository? repository,
  List<String> permissions = allOrderPermissions,
}) async {
  await useTallScreen(tester);

  final orders = repository ?? FakeServiceOrdersRepository();
  final container = serviceOrdersContainer(
    repository: orders,
    permissions: permissions,
    session: openOrderShift(),
  );
  addTearDown(container.dispose);

  await container.read(serviceOrderDetailControllerProvider.notifier).load(314);

  await tester.pumpWidget(
    serviceOrdersSheetAppIn(
      container: container,
      openLabel: 'Diagnóstico',
      open: (context) =>
          showServiceOrderDiagnosisSheet(context, detail: orders.detail),
    ),
  );

  await openSheet(tester, 'Diagnóstico');

  return container;
}

/// El campo de texto del diagnóstico (la hoja solo tiene uno).
Finder diagnosisField() => find.byType(TextField);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la cabecera usa el folio, el equipo y el cierre', (
    tester,
  ) async {
    await pumpDiagnosisSheet(tester);

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Diagnóstico');
    expect(header.subtitle, 'Folio OS-014 · iPhone 13, pantalla rota');
    expect(find.byTooltip('Cerrar'), findsOneWidget);
  });

  testWidgets('pinta el diagnóstico y las evidencias de cierre', (
    tester,
  ) async {
    await pumpDiagnosisSheet(tester);

    expect(find.text('DIAGNÓSTICO DEL TÉCNICO'), findsOneWidget);
    expect(find.text('DIAGNÓSTICO'), findsOneWidget);
    expect(find.text('EVIDENCIAS DE CIERRE'), findsOneWidget);
    expect(find.text('Evidencias (máximo 5)'), findsOneWidget);

    // Las acciones de la cámara y la galería son chips del sistema.
    expect(find.byType(EzyChip), findsNWidgets(2));
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir de galería'), findsOneWidget);
    expect(find.text('Quedan 5'), findsOneWidget);

    // El diagnóstico anterior ya capturado avisa que se puede borrar.
    expect(
      find.text('Si lo dejas vacío, el diagnóstico anterior se borrará.'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(EzyButton, 'Guardar diagnóstico'),
      findsOneWidget,
    );
  });

  testWidgets('guardar manda el texto nuevo y cierra la hoja', (tester) async {
    final orders = FakeServiceOrdersRepository();

    await pumpDiagnosisSheet(tester, repository: orders);

    await tester.enterText(diagnosisField(), 'Pantalla reemplazada');
    await settleSheet(tester);
    await tester.tap(find.widgetWithText(EzyButton, 'Guardar diagnóstico'));
    await settleSheet(tester);
    await tester.pump();

    expect(orders.diagnosisCalls, 1);
    expect(orders.lastDiagnosis, 'Pantalla reemplazada');
    // El `notice` del servidor se muestra con el SnackBar de la app.
    expect(
      find.text('Diagnóstico y evidencias guardados correctamente.'),
      findsOneWidget,
    );
    expect(find.text('EVIDENCIAS DE CIERRE'), findsNothing);
  });

  testWidgets('un diagnóstico vacío borra el texto anterior', (tester) async {
    final orders = FakeServiceOrdersRepository();

    await pumpDiagnosisSheet(tester, repository: orders);

    await tester.enterText(diagnosisField(), '');
    await settleSheet(tester);
    await tester.tap(find.widgetWithText(EzyButton, 'Guardar diagnóstico'));
    await settleSheet(tester);

    expect(orders.lastDiagnosis, '');
  });

  testWidgets('el 422 del servidor se muestra sin cerrar la hoja', (
    tester,
  ) async {
    await pumpDiagnosisSheet(
      tester,
      repository: FakeServiceOrdersRepository(
        diagnosisFailure: ApiException.fromResponse(422, <String, dynamic>{
          'message': 'La orden ya no se puede editar.',
        }),
      ),
    );

    await tester.tap(find.widgetWithText(EzyButton, 'Guardar diagnóstico'));
    await settleSheet(tester);
    await tester.pump();

    expect(find.text('La orden ya no se puede editar.'), findsOneWidget);
    expect(find.text('Ocultar'), findsOneWidget);
    expect(find.text('EVIDENCIAS DE CIERRE'), findsOneWidget);
  });
}
