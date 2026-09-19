import '../../../../core/utils/json_reader.dart';
import 'active_cash_session.dart';
import 'bank_account.dart';
import 'cash_register_ref.dart';
import 'joinable_cash_session.dart';

/// Estado completo del turno (`GET /cash-register-sessions/current`).
///
/// Es lo que alimenta la pantalla de apertura: la sesión activa (si la hay),
/// las sesiones a las que el usuario puede unirse, las terminales libres y las
/// cuentas bancarias con su saldo actual para declararlas al abrir.
class CashRegisterSnapshot {
  const CashRegisterSnapshot({
    required this.activeSession,
    required this.joinableSessions,
    required this.availableCashRegisters,
    required this.bankAccounts,
  });

  const CashRegisterSnapshot.empty()
    : activeSession = null,
      joinableSessions = const <JoinableCashSession>[],
      availableCashRegisters = const <CashRegisterRef>[],
      bankAccounts = const <BankAccount>[];

  factory CashRegisterSnapshot.fromJson(Map<String, dynamic> json) =>
      CashRegisterSnapshot(
        activeSession: json['active_session'] == null
            ? null
            : ActiveCashSession.fromJson(
                JsonReader.toMap(json['active_session']),
              ),
        joinableSessions: JsonReader.toMapList(
          json['joinable_sessions'],
        ).map(JoinableCashSession.fromJson).toList(growable: false),
        availableCashRegisters: JsonReader.toMapList(
          json['available_cash_registers'],
        ).map(CashRegisterRef.fromJson).toList(growable: false),
        bankAccounts: JsonReader.toMapList(
          json['bank_accounts'],
        ).map(BankAccount.fromJson).toList(growable: false),
      );

  final ActiveCashSession? activeSession;
  final List<JoinableCashSession> joinableSessions;
  final List<CashRegisterRef> availableCashRegisters;
  final List<BankAccount> bankAccounts;

  bool get hasActiveSession => activeSession != null;

  /// Hay terminales libres: se puede abrir un turno nuevo.
  bool get canStartShift => availableCashRegisters.isNotEmpty;

  /// Hay turnos de la sucursal a los que se puede unir o retomar.
  bool get canJoinShift => joinableSessions.isNotEmpty;

  /// Sin terminales libres ni turnos abiertos: pide abrir caja desde la web.
  bool get isBlocked => !canStartShift && !canJoinShift;

  /// Copia el estado cambiando solo la sesión activa (apertura, unión o corte
  /// devuelven la sesión definitiva; el resto se refresca en segundo plano).
  CashRegisterSnapshot copyWithSession(ActiveCashSession? session) =>
      CashRegisterSnapshot(
        activeSession: session,
        joinableSessions: joinableSessions,
        availableCashRegisters: availableCashRegisters,
        bankAccounts: bankAccounts,
      );
}
