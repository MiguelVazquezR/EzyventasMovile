import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/paginated.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../pos/data/models/payment_draft.dart';
import 'models/refund_method.dart';
import 'models/sales_mutation_results.dart';
import 'models/transaction_detail.dart';
import 'models/transaction_filters.dart';
import 'models/transaction_summary.dart';

/// Historial de ventas: listado, detalle, abonos, cancelación/reembolso y
/// edición de pagos.
///
/// Todas las reglas (stock, deuda del cliente, saldos bancarios, movimientos de
/// caja y permiso de cada operación) las aplica el servidor con los mismos
/// servicios que usa la web. La app solo arma la petición y tipa la respuesta.
class SalesRepository {
  SalesRepository({required this.api});

  final ApiClient api;

  /// `GET /transactions` — historial paginado de la sucursal.
  ///
  /// El servidor excluye el canal `abono_a_saldo` y ordena por `created_at`
  /// descendente si no se pide otro orden.
  Future<Paginated<TransactionSummary>> fetchTransactions({
    TransactionFilters filters = const TransactionFilters(),
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await api.getJson(
      ApiEndpoints.transactions,
      query: <String, dynamic>{
        ...filters.toQuery(),
        'page': page,
        'per_page': perPage,
      },
    );

    return Paginated<TransactionSummary>.fromJson(
      data,
      TransactionSummary.fromJson,
    );
  }

  /// `GET /transactions/{id}` — detalle con ítems, pagos y desglose resuelto.
  Future<TransactionDetail> fetchTransaction(int transactionId) async {
    final data = await api.getJson(ApiEndpoints.transaction(transactionId));

    return TransactionDetail.fromJson(data);
  }

  /// `POST /transactions/{id}/payments` — abono a una venta existente.
  ///
  /// Exige sesión de caja abierta. [useBalance] aplica el saldo a favor del
  /// cliente (puede ir con `payments` vacío) y [payments] solo admite
  /// `efectivo`, `tarjeta` y `transferencia`.
  Future<AbonoResult> addPayment({
    required int transactionId,
    required int sessionId,
    bool useBalance = false,
    List<PaymentDraft> payments = const <PaymentDraft>[],
    String? clientUuid,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.transactionPayments(transactionId),
      data: <String, dynamic>{
        'client_uuid': clientUuid ?? UuidGenerator.v4(),
        'cash_register_session_id': sessionId,
        'use_balance': useBalance,
        'payments': payments
            .where((payment) => payment.amount > 0)
            .map((payment) => payment.toJson())
            .toList(growable: false),
      },
    );

    return AbonoResult.fromJson(data);
  }

  /// `POST /transactions/{id}/cancel` con `action = penalty`: cancela la venta
  /// **reteniendo** el dinero recibido (permiso `transactions.cancel`).
  Future<TransactionMutationResult> cancelWithPenalty(
    int transactionId, {
    String? clientUuid,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.transactionCancel(transactionId),
      data: <String, dynamic>{
        'action': 'penalty',
        'client_uuid': clientUuid ?? UuidGenerator.v4(),
      },
    );

    return TransactionMutationResult.fromJson(data);
  }

  /// `POST /transactions/{id}/refund`: cancela y devuelve el dinero
  /// (permiso `transactions.refund`).
  Future<TransactionMutationResult> refund({
    required int transactionId,
    required RefundMethod method,
    int? bankAccountId,
    String? clientUuid,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.transactionRefund(transactionId),
      data: <String, dynamic>{
        'refund_method': method.value,
        'bank_account_id': bankAccountId,
        'client_uuid': clientUuid ?? UuidGenerator.v4(),
      }..removeWhere((key, value) => value == null),
    );

    return TransactionMutationResult.fromJson(data);
  }

  /// `PUT /transactions/{id}/payments/{paymentId}` — edita un pago y concilia
  /// el saldo de la cuenta bancaria (permiso `transactions.edit_payment`).
  Future<PaymentMutationResult> updatePayment({
    required int transactionId,
    required int paymentId,
    required double amount,
    required String paymentMethod,
    int? bankAccountId,
    String? notes,
    String? clientUuid,
  }) async {
    final data = await api.putJson(
      ApiEndpoints.transactionPayment(transactionId, paymentId),
      data: <String, dynamic>{
        'amount': amount,
        'payment_method': paymentMethod,
        'bank_account_id': bankAccountId,
        'notes': notes,
        'client_uuid': clientUuid ?? UuidGenerator.v4(),
      }..removeWhere((key, value) => value == null),
    );

    return PaymentMutationResult.fromJson(data);
  }

  /// `DELETE /transactions/{id}/payments/{paymentId}` — elimina el pago y
  /// revierte sus efectos. Responde `204` sin cuerpo.
  Future<void> deletePayment({
    required int transactionId,
    required int paymentId,
  }) async {
    await api.deleteJson(
      ApiEndpoints.transactionPayment(transactionId, paymentId),
    );
  }
}
