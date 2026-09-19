import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../data/cash_register_repository.dart';
import '../data/models/active_cash_session.dart';
import '../data/models/bank_account.dart';
import '../data/models/cash_register_ref.dart';
import '../data/models/cash_register_snapshot.dart';
import '../data/models/cash_session_summary.dart';
import '../data/models/closed_cash_session.dart';
import '../data/models/joinable_cash_session.dart';

/// Repositorio del turno de caja.
final cashRegisterRepositoryProvider = Provider<CashRegisterRepository>(
  (ref) => CashRegisterRepository(api: ref.watch(apiClientProvider)),
);

/// Terminal ocupada por otro usuario al intentar abrir caja
/// (`409 cash_register_in_use`): la app ofrece unirse a esa sesión.
class CashRegisterConflict {
  const CashRegisterConflict({
    required this.sessionId,
    required this.cashRegisterName,
    this.openedByName,
  });

  final int sessionId;
  final String cashRegisterName;
  final String? openedByName;

  /// `Caja 2 · abierta por José Pérez`
  String get label {
    final opener = openedByName;
    return (opener == null || opener.isEmpty)
        ? cashRegisterName
        : '$cashRegisterName · abierta por $opener';
  }
}

/// Estado del turno: sesión activa, turnos a los que unirse, terminales libres,
/// cuentas bancarias para la apertura y el último corte.
class CashRegisterState {
  const CashRegisterState({
    this.snapshot = const CashRegisterSnapshot.empty(),
    this.isLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.notice,
    this.conflict,
    this.lastClose,
  });

  final CashRegisterSnapshot snapshot;
  final bool isLoading;

  /// Petición de apertura, unión, salida o corte en curso.
  final bool isSubmitting;
  final String? errorMessage;

  /// Aviso puntual con el `message` del servidor (apertura, corte, salida).
  final String? notice;

  /// Terminal ocupada detectada al abrir caja.
  final CashRegisterConflict? conflict;

  /// Resultado del último corte (para ofrecer imprimir o enviar por WhatsApp).
  final CloseCashSessionResult? lastClose;

  ActiveCashSession? get activeSession => snapshot.activeSession;
  List<JoinableCashSession> get joinableSessions => snapshot.joinableSessions;
  List<CashRegisterRef> get availableCashRegisters =>
      snapshot.availableCashRegisters;
  List<BankAccount> get bankAccounts => snapshot.bankAccounts;

  bool get hasActiveSession => snapshot.hasActiveSession;

  /// Hay terminales libres: se puede abrir un turno nuevo.
  bool get canStartShift => snapshot.canStartShift;

  /// Hay turnos de la sucursal a los que unirse o retomar.
  bool get canJoinShift => snapshot.canJoinShift;

  /// Sin terminales libres ni turnos de la sucursal: pide abrir caja desde la web.
  bool get isBlocked => snapshot.isBlocked;

  CashRegisterState copyWith({
    CashRegisterSnapshot? snapshot,
    bool? isLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? notice,
    CashRegisterConflict? conflict,
    CloseCashSessionResult? lastClose,
    bool clearError = false,
    bool clearNotice = false,
    bool clearConflict = false,
    bool clearLastClose = false,
  }) {
    return CashRegisterState(
      snapshot: snapshot ?? this.snapshot,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      conflict: clearConflict ? null : (conflict ?? this.conflict),
      lastClose: clearLastClose ? null : (lastClose ?? this.lastClose),
    );
  }
}

/// Controlador del turno de caja.
///
/// Tras cada operación sincroniza la sesión con [AuthController] para que el POS
/// (y el punto verde de la pestaña Caja) queden al día sin volver a pedir
/// `/auth/me`, y refresca `current` para actualizar terminales libres, turnos a
/// los que unirse y saldos bancarios.
class CashRegisterController extends Notifier<CashRegisterState> {
  @override
  CashRegisterState build() {
    Future<void>.microtask(refresh);

    return const CashRegisterState(isLoading: true);
  }

  /// `GET /cash-register-sessions/current`.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final snapshot = await ref
          .read(cashRegisterRepositoryProvider)
          .fetchCurrent();

      state = state.copyWith(
        snapshot: snapshot,
        isLoading: false,
        clearError: true,
        clearConflict: snapshot.hasActiveSession,
      );

      await _syncActiveSession(snapshot.activeSession);
    } on ApiException catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.message);
    }
  }

  /// Abre el turno declarando fondo de efectivo y saldos bancarios.
  ///
  /// Si la terminal fue tomada por otro usuario (`409 cash_register_in_use`), el
  /// estado guarda el conflicto para ofrecer "Unirme a esa sesión".
  Future<bool> startShift({
    required int cashRegisterId,
    required double openingCashBalance,
    Map<int, double> declaredBankBalances = const <int, double>{},
    String? clientUuid,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
      clearConflict: true,
    );

    try {
      final session = await ref
          .read(cashRegisterRepositoryProvider)
          .openSession(
            cashRegisterId: cashRegisterId,
            openingCashBalance: openingCashBalance,
            declaredBankBalances: declaredBankBalances,
            clientUuid: clientUuid,
          );

      await _afterSessionChange(
        session,
        notice: 'La caja ha sido abierta con éxito.',
      );

      return true;
    } on ApiException catch (error) {
      final conflict = _conflictFrom(error);

      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
        conflict: conflict,
        clearConflict: conflict == null,
      );

      // `session_already_open`: el turno vive en otro dispositivo; se refresca.
      if (error.code == 'session_already_open') {
        await refresh();
      }

      return false;
    }
  }

  /// `POST /{id}/join`: se une a un turno abierto de la sucursal.
  Future<bool> joinShift(int sessionId) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
      clearConflict: true,
    );

    try {
      final session = await ref
          .read(cashRegisterRepositoryProvider)
          .joinSession(sessionId);

      await _afterSessionChange(
        session,
        notice: 'Te has unido a la sesión de caja.',
      );

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
        clearConflict: true,
      );

      return false;
    }
  }

  /// `POST /{id}/leave`: sale del turno sin cerrarlo.
  Future<bool> leaveShift(int sessionId) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final message = await ref
          .read(cashRegisterRepositoryProvider)
          .leaveSession(sessionId);

      state = state.copyWith(
        isSubmitting: false,
        snapshot: const CashRegisterSnapshot.empty(),
        notice: message.isEmpty ? 'Has salido de la sesión de caja.' : message,
      );

      await _syncActiveSession(null);
      await refresh();

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  /// `POST /rejoin-or-start`: retoma el turno de una terminal sin contar el
  /// fondo otra vez (por ejemplo tras un cierre remoto).
  Future<bool> rejoinShift({
    required int cashRegisterId,
    required int originalOpenerId,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
      clearConflict: true,
    );

    try {
      final session = await ref
          .read(cashRegisterRepositoryProvider)
          .rejoinOrStart(
            cashRegisterId: cashRegisterId,
            originalOpenerId: originalOpenerId,
          );

      await _afterSessionChange(
        session,
        notice: 'Te has unido a la nueva sesión.',
      );

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      return false;
    }
  }

  /// `PUT /{id}`: cierra la caja (corte) con el efectivo contado y las notas.
  ///
  /// Devuelve el resultado (sesión cerrada + resumen definitivo) para que la
  /// pantalla muestre la diferencia y ofrezca el ticket del corte.
  Future<CloseCashSessionResult?> closeShift({
    required int sessionId,
    required double closingCashBalance,
    String? notes,
    String? clientUuid,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await ref
          .read(cashRegisterRepositoryProvider)
          .closeSession(
            sessionId: sessionId,
            closingCashBalance: closingCashBalance,
            notes: notes,
            clientUuid: clientUuid,
          );

      state = state.copyWith(
        isSubmitting: false,
        snapshot: const CashRegisterSnapshot.empty(),
        lastClose: result,
        notice: result.message.isEmpty
            ? 'Corte de caja realizado con éxito.'
            : result.message,
      );

      await _syncActiveSession(null);
      await refresh();

      return result;
    } on ApiException catch (error) {
      state = state.copyWith(isSubmitting: false, errorMessage: error.message);

      // Otro dispositivo cerró la sesión: el turno local ya no existe.
      if (error.code == 'session_not_open') {
        await _syncActiveSession(null);
      }

      return null;
    }
  }

  void consumeNotice() {
    if (state.notice != null) {
      state = state.copyWith(clearNotice: true);
    }
  }

  void consumeError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void consumeLastClose() {
    if (state.lastClose != null) {
      state = state.copyWith(clearLastClose: true);
    }
  }

  /// Aplica el cambio de turno y refresca el resto del contexto.
  Future<void> _afterSessionChange(
    ActiveCashSession session, {
    required String notice,
  }) async {
    state = state.copyWith(
      isSubmitting: false,
      snapshot: state.snapshot.copyWithSession(session),
      notice: notice,
      clearError: true,
      clearConflict: true,
    );

    await _syncActiveSession(session);
    await refresh();
  }

  Future<void> _syncActiveSession(ActiveCashSession? session) =>
      ref.read(authControllerProvider.notifier).setActiveSession(session);

  static CashRegisterConflict? _conflictFrom(ApiException error) {
    if (error.code != 'cash_register_in_use') {
      return null;
    }

    final sessionId = error.detailInt('session_id');
    if (sessionId == null) {
      return null;
    }

    final register = error.detailMap('cash_register');
    final openedBy = error.detailMap('opened_by');

    return CashRegisterConflict(
      sessionId: sessionId,
      cashRegisterName: register['name'] is String
          ? register['name'] as String
          : 'Terminal',
      openedByName: openedBy['name'] is String
          ? openedBy['name'] as String
          : null,
    );
  }
}

final cashRegisterControllerProvider =
    NotifierProvider<CashRegisterController, CashRegisterState>(
      CashRegisterController.new,
    );

/// Resumen del corte de un turno (`GET /{id}/summary`).
///
/// Se invalida con `ref.invalidate(cashSummaryProvider(id))` tras cada corte.
final cashSummaryProvider = FutureProvider.family<CashSessionSummary, int>(
  (ref, sessionId) =>
      ref.watch(cashRegisterRepositoryProvider).fetchSummary(sessionId),
);

/// Cuentas bancarias del usuario (`GET /bank-accounts`) para elegir la cuenta
/// destino de los pagos con tarjeta o transferencia.
final bankAccountsProvider = FutureProvider<List<BankAccount>>(
  (ref) => ref.watch(cashRegisterRepositoryProvider).fetchBankAccounts(),
);
