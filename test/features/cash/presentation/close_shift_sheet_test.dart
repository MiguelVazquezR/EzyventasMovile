import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/features/cash/presentation/widgets/close_shift_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'cash_sheets_harness.dart';

/// Hoja del corte de caja: resumen → aviso de usuarios → arqueo → resultado.
///
/// Las etiquetas `Corte de caja` y `Continuar` son las que busca el recorrido
/// del teléfono (`integration_test/qa_device_test.dart`).
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  /// Abre la hoja con el número de usuarios que se quiera simular.
  Future<FakeCashRepository> openCloseSheet(
    WidgetTester tester, {
    int usersCount = 1,
    Map<String, dynamic>? summary,
  }) async {
    final repository = FakeCashRepository(summary: summary);

    await useTallScreen(tester);
    await tester.pumpWidget(
      cashSheetApp(
        repository: repository,
        openLabel: 'Abrir corte',
        open: (context) =>
            showCloseShiftSheet(context, sessionId: 41, usersCount: usersCount),
      ),
    );
    await openSheet(tester, 'Abrir corte');

    return repository;
  }

  testWidgets('el resumen del turno se lee antes de capturar el efectivo', (
    tester,
  ) async {
    await openCloseSheet(tester);

    // Cabecera del sistema con el título del paso y su subtítulo.
    expect(find.text('Corte de caja'), findsOneWidget);
    expect(
      find.text('Revisa el turno antes de capturar el efectivo.'),
      findsOneWidget,
    );

    expect(find.text('TURNO'), findsOneWidget);
    expect(find.text('Caja 1'), findsOneWidget);
    expect(find.text('12 ventas · 14 pagos'), findsOneWidget);

    expect(find.text('EFECTIVO'), findsOneWidget);
    expect(find.text('COBROS POR MÉTODO'), findsOneWidget);
    expect(find.text('MOVIMIENTOS DE EFECTIVO'), findsOneWidget);
    expect(find.text('CUENTAS BANCARIAS'), findsOneWidget);
    expect(find.text('Cuenta principal · BBVA'), findsOneWidget);

    expect(find.text('Continuar'), findsOneWidget);

    // El arqueo todavía no aparece.
    expect(find.text('Arqueo de efectivo'), findsNothing);
    expect(find.text('Finalizar turno'), findsNothing);
  });

  testWidgets('el arqueo calcula la diferencia en vivo y la manda al corte', (
    tester,
  ) async {
    final repository = await openCloseSheet(tester);

    await tester.tap(find.text('Continuar'));
    await settleSheet(tester);

    expect(find.text('Arqueo de efectivo'), findsOneWidget);
    expect(find.text('Cuenta el efectivo físico de la caja.'), findsOneWidget);

    // Sin capturar el efectivo no se puede cerrar el turno.
    EzyButton finalize() => tester.widget<EzyButton>(
      find.widgetWithText(EzyButton, 'Finalizar turno'),
    );

    expect(finalize().onPressed, isNull);

    // Primer campo del arqueo: el efectivo contado (el segundo son las notas).
    await tester.enterText(find.byType(TextField).first, '5040');
    await settleSheet(tester);

    expect(finalize().onPressed, isNotNull);
    expect(find.textContaining('Descuadre'), findsOneWidget);
    expect(find.text('COMPARATIVO'), findsOneWidget);

    await tester.tap(find.text('Finalizar turno'));
    await settleSheet(tester);

    expect(repository.closeCalls, 1);
    expect(repository.lastClosedSessionId, 41);
    expect(repository.lastClosingCash, 5040);
    expect(repository.lastNotes, isNull);

    // Resultado del corte con la impresión del servidor (§6.3).
    expect(find.text('TURNO CERRADO'), findsOneWidget);
    expect(find.text('Corte de caja realizado con éxito.'), findsOneWidget);
    expect(find.text('Imprimir corte'), findsOneWidget);
    expect(find.text('Enviar corte por WhatsApp'), findsOneWidget);
    expect(find.text('Listo'), findsOneWidget);
  });

  testWidgets('el arqueo sin diferencia lo avisa en verde', (tester) async {
    await openCloseSheet(tester);

    await tester.tap(find.text('Continuar'));
    await settleSheet(tester);

    await tester.enterText(find.byType(TextField).first, '5050');
    await settleSheet(tester);

    expect(find.text('Sin diferencia.'), findsOneWidget);
    expect(find.textContaining('Descuadre'), findsNothing);
  });

  testWidgets('las notas del arqueo viajan con el corte', (tester) async {
    final repository = await openCloseSheet(tester);

    await tester.tap(find.text('Continuar'));
    await settleSheet(tester);

    await tester.enterText(find.byType(TextField).first, '5050');
    await tester.enterText(find.byType(TextField).last, 'Faltó cambio');
    await settleSheet(tester);

    await tester.tap(find.text('Finalizar turno'));
    await settleSheet(tester);

    expect(repository.lastNotes, 'Faltó cambio');
  });

  testWidgets('con más de un usuario el cierre pide confirmación explícita', (
    tester,
  ) async {
    await openCloseSheet(tester, usersCount: 2);

    await tester.tap(find.text('Continuar'));
    await settleSheet(tester);

    expect(find.text('Confirmar cierre'), findsOneWidget);
    expect(
      find.text('Este turno lo están usando varios usuarios.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Hay 2 usuarios en esta sesión; al cerrarla, todos saldrán de la caja.',
      ),
      findsOneWidget,
    );

    // Cancelar vuelve al resumen sin cerrar nada.
    await tester.tap(find.text('Cancelar'));
    await settleSheet(tester);

    expect(find.text('Corte de caja'), findsOneWidget);
    expect(find.text('Finalizar turno'), findsNothing);

    // Volver a continuar y aceptar el aviso lleva al arqueo.
    await tester.tap(find.text('Continuar'));
    await settleSheet(tester);
    await tester.tap(find.text('Cerrar la caja de todos modos'));
    await settleSheet(tester);

    expect(find.text('Arqueo de efectivo'), findsOneWidget);
  });

  testWidgets('el error del servidor se muestra sin cerrar la hoja', (
    tester,
  ) async {
    final repository = FakeCashRepository()
      ..closeFailure = ApiException.fromResponse(422, <String, dynamic>{
        'code': 'session_not_open',
        'message': 'La sesión de caja ya no está abierta.',
      });

    await useTallScreen(tester);
    await tester.pumpWidget(
      cashSheetApp(
        repository: repository,
        openLabel: 'Abrir corte',
        open: (context) =>
            showCloseShiftSheet(context, sessionId: 41, usersCount: 1),
      ),
    );
    await openSheet(tester, 'Abrir corte');

    await tester.tap(find.text('Continuar'));
    await settleSheet(tester);

    await tester.enterText(find.byType(TextField).first, '5050');
    await settleSheet(tester);

    await tester.tap(find.text('Finalizar turno'));
    await settleSheet(tester);

    expect(find.text('La sesión de caja ya no está abierta.'), findsOneWidget);
    expect(
      find.text('Arqueo de efectivo'),
      findsOneWidget,
      reason: 'la hoja sigue abierta para reintentar el corte',
    );
  });
}
