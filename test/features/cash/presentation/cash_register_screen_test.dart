import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_dialog.dart';
import 'package:ezyventas_app/core/widgets/section_card.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'cash_sheets_harness.dart';

/// Pestaña Caja: resumen del turno, corte y salida del turno.
///
/// Se usa `pump` con duración fija (nunca `pumpAndSettle`) porque el
/// `StatusBadge` del turno anima en bucle mientras la caja está abierta.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('con turno abierto muestra el resumen y las acciones', (
    tester,
  ) async {
    final repository = FakeCashRepository();

    await useTallScreen(tester);
    await tester.pumpWidget(cashScreenApp(repository: repository));
    await settleSheet(tester);

    expect(find.text('Turno abierto en Caja 1'), findsOneWidget);
    expect(find.text('TURNO ACTUAL'), findsOneWidget);
    expect(find.text('Caja 1'), findsOneWidget);
    expect(find.text('José Pérez'), findsOneWidget);
    expect(find.text('ABIERTA'), findsOneWidget);
    expect(find.text('COBROS DEL TURNO'), findsOneWidget);
    expect(find.text('SALDOS BANCARIOS AL ABRIR'), findsOneWidget);
    expect(find.text('Cuenta principal · BBVA'), findsOneWidget);

    // Con más de un usuario en la sesión el cierre afecta a todos.
    expect(
      find.textContaining('Hay 2 usuarios en esta sesión'),
      findsOneWidget,
    );

    expect(find.text('Hacer corte'), findsOneWidget);
    expect(find.text('Salir del turno'), findsOneWidget);
    expect(find.text('Actualizar estado'), findsOneWidget);
  });

  testWidgets('salir del turno pide confirmación con el diálogo del sistema', (
    tester,
  ) async {
    final repository = FakeCashRepository();

    await useTallScreen(tester);
    await tester.pumpWidget(cashScreenApp(repository: repository));
    await settleSheet(tester);

    await tester.tap(find.text('Salir del turno'));
    await settleSheet(tester);

    expect(find.byType(EzyDialog), findsOneWidget);
    expect(
      find.text(
        'Dejarás de cobrar en este dispositivo. La caja sigue abierta para '
        'los demás usuarios.',
      ),
      findsOneWidget,
    );

    // Cancelar deja el turno como estaba.
    await tester.tap(find.text('Cancelar'));
    await settleSheet(tester);

    expect(find.byType(EzyDialog), findsNothing);
    expect(repository.leaveCalls, 0);

    // Confirmar sale del turno sin cerrarlo.
    await tester.tap(find.text('Salir del turno'));
    await settleSheet(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(EzyDialog),
        matching: find.widgetWithText(EzyButton, 'Salir del turno'),
      ),
    );
    await settleSheet(tester);

    expect(repository.leaveCalls, 1);
    expect(repository.lastLeftSessionId, 41);
  });

  testWidgets('sin turno ofrece abrir caja y unirse a un turno', (
    tester,
  ) async {
    final repository = FakeCashRepository(current: noSessionFixture());

    await useTallScreen(tester);
    await tester.pumpWidget(cashScreenApp(repository: repository));
    await settleSheet(tester);

    expect(find.text('Sin turno abierto'), findsOneWidget);
    expect(find.text('INICIAR TURNO'), findsOneWidget);
    expect(find.text('TURNOS ABIERTOS'), findsOneWidget);
    expect(find.text('Unirme'), findsOneWidget);
    expect(find.text('Retomar'), findsOneWidget);
    expect(find.text('Hacer corte'), findsNothing);
  });

  testWidgets(
    'el turno al que se puede unir usa el panel interno del sistema',
    (tester) async {
      final repository = FakeCashRepository(current: noSessionFixture());

      await useTallScreen(tester);
      await tester.pumpWidget(cashScreenApp(repository: repository));
      await settleSheet(tester);

      // El panel con los datos del turno es una tarjeta interna (`panelInner`),
      // no un contenedor copiado a mano.
      final inner = tester
          .widgetList<SectionCard>(find.byType(SectionCard))
          .where((card) => card.inner);

      expect(inner, isNotEmpty);
      expect(find.text('Caja 2'), findsOneWidget);
      expect(find.textContaining('por Luis'), findsOneWidget);
    },
  );
}
