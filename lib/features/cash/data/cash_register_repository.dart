import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/utils/json_reader.dart';
import '../../../core/utils/uuid_generator.dart';
import 'models/active_cash_session.dart';
import 'models/bank_account.dart';
import 'models/cash_register_snapshot.dart';
import 'models/cash_session_summary.dart';
import 'models/closed_cash_session.dart';
import '../../printing/data/models/cash_cut_receipt.dart';

/// Turno de caja: apertura, unión, retome, salida, resumen y corte.
///
/// Todas las reglas (terminal libre, fondo, saldos bancarios, conciliación de
/// bancos y diferencia de arqueo) las aplica el servidor con los mismos
/// servicios que usa la web; aquí solo se arma la petición y se tipa la
/// respuesta. La app **nunca** crea movimientos de efectivo ni edita el corte.
class CashRegisterRepository {
  CashRegisterRepository({required this.api});

  final ApiClient api;

  /// `GET /cash-register-sessions/current`.
  Future<CashRegisterSnapshot> fetchCurrent() async {
    final data = await api.getJson(ApiEndpoints.currentCashRegisterSession);

    return CashRegisterSnapshot.fromJson(data);
  }

  /// `GET /bank-accounts` — cuentas bancarias del usuario para los pagos con
  /// tarjeta o transferencia (`bank_account_id` obligatorio).
  Future<List<BankAccount>> fetchBankAccounts() async {
    final data = await api.getJsonList(ApiEndpoints.bankAccounts);

    return data.map(BankAccount.fromJson).toList(growable: false);
  }

  /// `POST /cash-register-sessions` — abre el turno declarando el fondo de
  /// efectivo y, si el usuario gestiona cuentas, el saldo de cada una.
  ///
  /// [declaredBankBalances] son los saldos capturados por cuenta; las cuentas
  /// que no se envíen heredan el saldo del último corte de esa terminal.
  Future<ActiveCashSession> openSession({
    required int cashRegisterId,
    required double openingCashBalance,
    Map<int, double> declaredBankBalances = const <int, double>{},
    String? clientUuid,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.cashRegisterSessions,
      data: <String, dynamic>{
        'client_uuid': clientUuid ?? UuidGenerator.v4(),
        'cash_register_id': cashRegisterId,
        'opening_cash_balance': openingCashBalance,
        'bank_accounts': declaredBankBalances.entries
            .map(
              (entry) => <String, dynamic>{
                'id': entry.key,
                'balance': entry.value,
              },
            )
            .toList(growable: false),
      },
    );

    return ActiveCashSession.fromJson(
      JsonReader.toMap(data['active_session']),
    );
  }

  /// `POST /cash-register-sessions/{id}/join` — se une al turno abierto.
  Future<ActiveCashSession> joinSession(int sessionId) async {
    final data = await api.postJson(
      ApiEndpoints.joinCashRegisterSession(sessionId),
      data: <String, dynamic>{'client_uuid': UuidGenerator.v4()},
    );

    return ActiveCashSession.fromJson(
      JsonReader.toMap(data['active_session']),
    );
  }

  /// `POST /cash-register-sessions/{id}/leave` — sale del turno sin cerrarlo.
  Future<String> leaveSession(int sessionId) async {
    final data = await api.postJson(
      ApiEndpoints.leaveCashRegisterSession(sessionId),
      data: <String, dynamic>{'client_uuid': UuidGenerator.v4()},
    );

    return JsonReader.stringOr(data['message'], '');
  }

  /// `POST /cash-register-sessions/rejoin-or-start` — retoma el turno de una
  /// terminal sin volver a contar el fondo.
  Future<ActiveCashSession> rejoinOrStart({
    required int cashRegisterId,
    required int originalOpenerId,
    String? clientUuid,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.rejoinOrStartCashRegisterSession,
      data: <String, dynamic>{
        'client_uuid': clientUuid ?? UuidGenerator.v4(),
        'cash_register_id': cashRegisterId,
        'original_opener_id': originalOpenerId,
      },
    );

    return ActiveCashSession.fromJson(
      JsonReader.toMap(data['active_session']),
    );
  }

  /// `GET /cash-register-sessions/{id}/summary` — resumen del corte.
  Future<CashSessionSummary> fetchSummary(int sessionId) async {
    final data = await api.getJson(
      ApiEndpoints.cashRegisterSessionSummary(sessionId),
    );

    return CashSessionSummary.fromJson(data);
  }

  /// `GET /cash-register-sessions/{id}/receipt` — el corte **listo para
  /// imprimir o reimprimir** (§6.3).
  ///
  /// El servidor elige la plantilla: `templateId` si se pide (404 si no es de la
  /// suscripción), la del negocio con contexto `cash_register` y, si el negocio
  /// todavía no tiene una, la **incorporada** (`template.builtin = true`).
  /// Devuelve las operaciones de impresión ya codificadas, así que la app no
  /// arma el corte.
  Future<CashCutReceipt> fetchCutReceipt(int sessionId, {int? templateId}) async {
    final data = await api.getJson(
      ApiEndpoints.cashRegisterSessionReceipt(sessionId),
      query: <String, dynamic>{'template_id': templateId},
    );

    return CashCutReceipt.fromJson(data);
  }

  /// `PUT /cash-register-sessions/{id}` — cierra la caja (corte).
  Future<CloseCashSessionResult> closeSession({
    required int sessionId,
    required double closingCashBalance,
    String? notes,
    String? clientUuid,
  }) async {
    final data = await api.putJson(
      ApiEndpoints.closeCashRegisterSession(sessionId),
      data: <String, dynamic>{
        'client_uuid': clientUuid ?? UuidGenerator.v4(),
        'closing_cash_balance': closingCashBalance,
        'notes': notes,
      },
    );

    return CloseCashSessionResult.fromJson(data);
  }
}
