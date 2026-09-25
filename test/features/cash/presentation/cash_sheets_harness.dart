import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/auth/data/auth_repository.dart';
import 'package:ezyventas_app/features/auth/data/models/auth_session.dart';
import 'package:ezyventas_app/features/cash/application/cash_register_controller.dart';
import 'package:ezyventas_app/features/cash/data/cash_register_repository.dart';
import 'package:ezyventas_app/features/cash/data/models/active_cash_session.dart';
import 'package:ezyventas_app/features/cash/data/models/bank_account.dart';
import 'package:ezyventas_app/features/cash/data/models/cash_register_snapshot.dart';
import 'package:ezyventas_app/features/cash/data/models/cash_session_summary.dart';
import 'package:ezyventas_app/features/cash/data/models/closed_cash_session.dart';
import 'package:ezyventas_app/features/cash/presentation/cash_register_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/cash_parsers_test.dart';

/// Fixtures y arnés compartidos por las pruebas de la pestaña **Caja** y de la
/// hoja de corte (no es un archivo de pruebas: no tiene `main()`).
///
/// Las etiquetas que se comprueban con estos datos son las que también busca el
/// recorrido del teléfono (`integration_test/qa_device_test.dart`): `Hacer
/// corte` en la pestaña y `Corte de caja` / `Continuar` dentro de la hoja, así
/// que un cambio de texto ahí rompería esa corrida real.

/// `PUT /cash-register-sessions/{id}`: corte cerrado con faltante de 10.
Map<String, dynamic> closedSessionFixture() {
  final summary = summaryFixture();
  summary['session'] = <String, dynamic>{
    ...summary['session']! as Map<String, dynamic>,
    'status': 'cerrada',
    'closed_at': '2026-09-18T20:05:00.000000Z',
    'calculated_cash_total': '5050.00',
    'closing_cash_balance': '5040.00',
    'cash_difference': '-10.00',
  };

  return <String, dynamic>{
    'session': <String, dynamic>{
      'id': 41,
      'status': 'cerrada',
      'closed_at': '2026-09-18T20:05:00.000000Z',
      'calculated_cash_total': '5050.00',
      'closing_cash_balance': '5040.00',
      'cash_difference': '-10.00',
    },
    'summary': summary,
    'message': 'Corte de caja realizado con éxito.',
  };
}

/// `GET /cash-register-sessions/current` **sin** turno abierto, con terminales
/// libres y turnos a los que unirse.
Map<String, dynamic> noSessionFixture() {
  final current = currentSessionFixture();

  return <String, dynamic>{
    'active_session': null,
    'joinable_sessions': current['joinable_sessions'],
    'available_cash_registers': current['available_cash_registers'],
    'bank_accounts': current['bank_accounts'],
  };
}

/// Cuentas bancarias del usuario para declarar saldos al abrir el turno.
List<BankAccount> cashBankAccounts() => <BankAccount>[
  BankAccount.fromJson(<String, dynamic>{
    'id': 2,
    'name': 'Cuenta principal - BBVA (...4471)',
    'bank_name': 'BBVA',
    'account_name': 'Cuenta principal',
    'balance': '5000.00',
  }),
];

/// Repositorio falso de caja: sirve el contrato §6 sin tocar la red y guarda lo
/// que la pantalla le pidió al servidor.
class FakeCashRepository extends CashRegisterRepository {
  FakeCashRepository({
    Map<String, dynamic>? current,
    Map<String, dynamic>? summary,
    this.openFailure,
    this.closeFailure,
    List<BankAccount>? accounts,
  }) : current = current ?? currentSessionFixture(),
       summary = summary ?? summaryFixture(),
       accounts = accounts ?? cashBankAccounts(),
       super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  Map<String, dynamic> current;
  Map<String, dynamic> summary;
  List<BankAccount> accounts;

  /// Error del servidor en la apertura (p. ej. `409 cash_register_in_use`).
  ApiException? openFailure;

  /// Error del servidor en el corte.
  ApiException? closeFailure;

  int currentCalls = 0;
  int openCalls = 0;
  int joinCalls = 0;
  int leaveCalls = 0;
  int closeCalls = 0;

  int? lastCashRegisterId;
  double? lastOpeningCash;
  Map<int, double>? lastDeclaredBalances;
  int? lastJoinedSessionId;
  int? lastLeftSessionId;
  int? lastClosedSessionId;
  double? lastClosingCash;
  String? lastNotes;

  @override
  Future<CashRegisterSnapshot> fetchCurrent() async {
    currentCalls++;

    return CashRegisterSnapshot.fromJson(current);
  }

  @override
  Future<List<BankAccount>> fetchBankAccounts() async => accounts;

  @override
  Future<CashSessionSummary> fetchSummary(int sessionId) async =>
      CashSessionSummary.fromJson(summary);

  @override
  Future<ActiveCashSession> openSession({
    required int cashRegisterId,
    required double openingCashBalance,
    Map<int, double> declaredBankBalances = const <int, double>{},
    String? clientUuid,
  }) async {
    openCalls++;
    lastCashRegisterId = cashRegisterId;
    lastOpeningCash = openingCashBalance;
    lastDeclaredBalances = declaredBankBalances;

    final failure = openFailure;
    if (failure != null) {
      throw failure;
    }

    return ActiveCashSession.fromJson(
      currentSessionFixture()['active_session']! as Map<String, dynamic>,
    );
  }

  @override
  Future<ActiveCashSession> joinSession(int sessionId) async {
    joinCalls++;
    lastJoinedSessionId = sessionId;

    return ActiveCashSession.fromJson(
      currentSessionFixture()['active_session']! as Map<String, dynamic>,
    );
  }

  @override
  Future<String> leaveSession(int sessionId) async {
    leaveCalls++;
    lastLeftSessionId = sessionId;

    return 'Has salido de la sesión de caja.';
  }

  @override
  Future<CloseCashSessionResult> closeSession({
    required int sessionId,
    required double closingCashBalance,
    String? notes,
    String? clientUuid,
  }) async {
    closeCalls++;
    lastClosedSessionId = sessionId;
    lastClosingCash = closingCashBalance;
    lastNotes = notes;

    final failure = closeFailure;
    if (failure != null) {
      throw failure;
    }

    return CloseCashSessionResult.fromJson(closedSessionFixture());
  }
}

/// Sesión falsa: sin sesión guardada, `setActiveSession` no toca el almacén
/// seguro (la pestaña refresca el turno en cada `refresh`).
class FakeCashAuthRepository extends AuthRepository {
  FakeCashAuthRepository()
    : super(api: ApiClient(), sessionStore: SessionStore());

  @override
  Future<AuthSession?> readStoredSession() async => null;
}

/// App mínima de la pestaña Caja con el repositorio de turno falso.
///
/// Los overrides van literales dentro del `ProviderScope` porque Riverpod 3 no
/// expone el tipo de la lista.
Widget cashScreenApp({required FakeCashRepository repository}) => ProviderScope(
  overrides: [
    cashRegisterRepositoryProvider.overrideWithValue(repository),
    authRepositoryProvider.overrideWithValue(FakeCashAuthRepository()),
  ],
  child: MaterialApp(theme: EzyTheme.dark(), home: const CashRegisterScreen()),
);

/// App mínima con un botón que abre la hoja que se está probando.
Widget cashSheetApp({
  required FakeCashRepository repository,
  required String openLabel,
  required void Function(BuildContext context) open,
}) => ProviderScope(
  overrides: [
    cashRegisterRepositoryProvider.overrideWithValue(repository),
    authRepositoryProvider.overrideWithValue(FakeCashAuthRepository()),
  ],
  child: MaterialApp(
    theme: EzyTheme.dark(),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => open(context),
            child: Text(openLabel),
          ),
        ),
      ),
    ),
  ),
);

/// Pantalla alta: la hoja de corte (0.92 del alto) pinta todas sus tarjetas.

/// Dos terminales libres: para comprobar que el desplegable manda el elegido.
Map<String, dynamic> twoRegistersFixture() {
  final current = noSessionFixture();
  current['available_cash_registers'] = <Map<String, dynamic>>[
    <String, dynamic>{'id': 5, 'name': 'Caja 3'},
    <String, dynamic>{'id': 6, 'name': 'Caja 4'},
  ];

  return current;
}

/// App mínima que hospeda un widget del sistema (el formulario de apertura).
Widget cashHostApp({
  required FakeCashRepository repository,
  required Widget child,
}) => ProviderScope(
  overrides: [
    cashRegisterRepositoryProvider.overrideWithValue(repository),
    authRepositoryProvider.overrideWithValue(FakeCashAuthRepository()),
  ],
  child: MaterialApp(
    theme: EzyTheme.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

///
/// El resumen del turno es largo (turno, efectivo, cobros por método,
/// movimientos y saldos bancarios), así que con la pantalla de prueba por
/// defecto el `ListView` deja sin construir las últimas tarjetas.
Future<void> useTallScreen(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(440, 4400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Abre la hoja del botón [openLabel] y deja pasar la animación de entrada.
///
/// Se usa `pump` y **no** `pumpAndSettle`: el `StatusBadge` del turno anima en
/// bucle, así que `pumpAndSettle` nunca terminaría.
Future<void> openSheet(WidgetTester tester, String openLabel) async {
  await tester.tap(find.text(openLabel));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Deja pasar la animación de una acción posterior (avanzar de paso, cerrar).
Future<void> settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
