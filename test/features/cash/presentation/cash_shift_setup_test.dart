import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/features/cash/data/models/bank_account.dart';
import 'package:ezyventas_app/features/cash/data/models/cash_register_ref.dart';
import 'package:ezyventas_app/features/cash/presentation/widgets/cash_shift_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'cash_sheets_harness.dart';

/// Formulario de apertura del turno: terminal, fondo y saldos bancarios.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('declara terminal, fondo y saldos bancarios al abrir el turno', (
    tester,
  ) async {
    final repository = FakeCashRepository(current: twoRegistersFixture());

    await useTallScreen(tester);
    await tester.pumpWidget(cashScreenApp(repository: repository));
    await tester.pumpAndSettle();

    // El desplegable arranca en la primera terminal libre y se puede cambiar.
    await tester.tap(find.text('Caja 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Caja 4').last);
    await tester.pumpAndSettle();

    // El primer campo de texto del formulario es el fondo de efectivo.
    await tester.enterText(find.byType(TextField).first, '1500');
    await tester.pump();

    await tester.tap(find.text('Iniciar turno'));
    await tester.pumpAndSettle();

    expect(repository.openCalls, 1);
    expect(repository.lastCashRegisterId, 6);
    expect(repository.lastOpeningCash, 1500);
    expect(repository.lastDeclaredBalances, <int, double>{2: 5000});
  });

  testWidgets('una terminal ocupada ofrece unirse a la sesión abierta', (
    tester,
  ) async {
    final repository = FakeCashRepository(current: noSessionFixture())
      ..openFailure = ApiException.fromResponse(409, <String, dynamic>{
        'code': 'cash_register_in_use',
        'message':
            'Parece que otro usuario abrió caja antes que tú. Puedes unirte '
            'a la sesión.',
        'session_id': 42,
        'cash_register': <String, dynamic>{'id': 4, 'name': 'Caja 2'},
        'opened_by': <String, dynamic>{'id': 5, 'name': 'Luis Torres'},
      });

    await useTallScreen(tester);
    await tester.pumpWidget(cashScreenApp(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar turno'));
    await tester.pumpAndSettle();

    // El aviso trae el `message` del servidor y la salida para unirse. Hoy el
    // mensaje sale dos veces en la pestaña (el formulario y el panel de turnos
    // abiertos, que comparten el error del controlador), así que se comprueba
    // que esté, no cuántas veces.
    expect(
      find.text(
        'Parece que otro usuario abrió caja antes que tú. Puedes unirte a la '
        'sesión.',
      ),
      findsWidgets,
    );
    expect(find.text('Unirme a esa sesión'), findsOneWidget);

    await tester.tap(find.text('Unirme a esa sesión'));
    await tester.pumpAndSettle();

    expect(repository.joinCalls, 1);
    expect(repository.lastJoinedSessionId, 42);
  });

  testWidgets('la terminal y las cuentas siguen al refrescar del servidor', (
    tester,
  ) async {
    final repository = FakeCashRepository(
      current: noSessionFixture(),
      accounts: const <BankAccount>[],
    );
    final refreshed = ValueNotifier<bool>(false);
    addTearDown(refreshed.dispose);

    await useTallScreen(tester);
    await tester.pumpWidget(
      cashHostApp(
        repository: repository,
        child: ValueListenableBuilder<bool>(
          valueListenable: refreshed,
          builder: (context, withNewData, child) => StartShiftCard(
            registers: withNewData
                ? const <CashRegisterRef>[
                    CashRegisterRef(id: 7, name: 'Caja 1'),
                  ]
                : const <CashRegisterRef>[
                    CashRegisterRef(id: 5, name: 'Caja 3'),
                  ],
            bankAccounts: withNewData
                ? cashBankAccounts()
                : const <BankAccount>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Caja 3'), findsOneWidget);
    expect(find.text('SALDOS BANCARIOS DECLARADOS'), findsNothing);

    // El servidor devuelve otra terminal (la 5 ya no existe) y una cuenta nueva.
    refreshed.value = true;
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason:
          'el desplegable no puede quedarse con una terminal que ya no '
          'existe: `DropdownButtonFormField` truena cuando su valor no está en '
          'los items',
    );
    expect(find.text('Caja 1'), findsOneWidget);
    expect(find.text('SALDOS BANCARIOS DECLARADOS'), findsOneWidget);

    // La cuenta que apareció después entra en la petición con su saldo
    // declarado (antes se enviaba sin controlador y se perdía en silencio).
    await tester.tap(find.text('Iniciar turno'));
    await tester.pumpAndSettle();

    expect(repository.lastCashRegisterId, 7);
    expect(repository.lastDeclaredBalances, <int, double>{2: 5000});
  });
}
