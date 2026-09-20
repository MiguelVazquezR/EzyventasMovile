import '../../../../core/utils/json_reader.dart';
import '../../../sales/data/models/sales_mutation_results.dart';
import '../../../sales/data/models/transaction_detail.dart';
import 'service_order_detail.dart';
import 'service_order_summary.dart';

/// Respuesta de `POST /service-orders`, `PUT /service-orders/{id}` y
/// `POST /service-orders/{id}/diagnosis`: traen el detalle completo ya
/// recalculado por el servidor.
class ServiceOrderMutationResult {
  const ServiceOrderMutationResult({
    required this.message,
    required this.detail,
  });

  factory ServiceOrderMutationResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderMutationResult(
        message: JsonReader.stringOr(json['message'], ''),
        detail: ServiceOrderDetail.fromJson(
          JsonReader.toMap(json['service_order']),
        ),
      );

  /// `message` del servidor (español), listo para mostrar.
  final String message;
  final ServiceOrderDetail detail;
}

/// Respuesta de `PATCH /service-orders/{id}/status`: solo el resumen del
/// listado (`service_order` = `listPayload`).
class ServiceOrderStatusResult {
  const ServiceOrderStatusResult({
    required this.message,
    required this.summary,
  });

  factory ServiceOrderStatusResult.fromJson(Map<String, dynamic> json) =>
      ServiceOrderStatusResult(
        message: JsonReader.stringOr(json['message'], ''),
        summary: ServiceOrderSummary.fromJson(
          JsonReader.toMap(json['service_order']),
        ),
      );

  /// Ej. `Estatus actualizado a “Terminado”.`
  final String message;
  final ServiceOrderSummary summary;
}

/// Respuesta de `POST /service-orders/{id}/payments` (anticipos).
///
/// Trae la orden actualizada, la venta vinculada y el ticket de abono que el
/// servidor ya formateó (`print.payload`), el mismo que usa la venta.
class ServiceOrderPaymentResult {
  const ServiceOrderPaymentResult({
    required this.detail,
    required this.transaction,
    required this.receipt,
  });

  factory ServiceOrderPaymentResult.fromJson(Map<String, dynamic> json) {
    final printInfo = JsonReader.toMap(json['print']);

    return ServiceOrderPaymentResult(
      detail: ServiceOrderDetail.fromJson(
        JsonReader.toMap(json['service_order']),
      ),
      transaction: TransactionDetail.fromJson(
        JsonReader.toMap(json['transaction']),
      ),
      receipt: printInfo.isEmpty ? null : AbonoReceipt.fromJson(printInfo),
    );
  }

  final ServiceOrderDetail detail;
  final TransactionDetail transaction;
  final AbonoReceipt? receipt;
}
