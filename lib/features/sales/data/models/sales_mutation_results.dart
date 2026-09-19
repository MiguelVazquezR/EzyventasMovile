import '../../../../core/utils/json_reader.dart';
import 'transaction_detail.dart';

/// Ticket de abono ya formateado por el servidor (`print.payload`).
///
/// Los montos llegan **listos para mostrar** (`"$350.00 MXN"`): se pintan tal
/// cual, nunca se vuelven a formatear. `kind` es `abono` para ventas normales y
/// `order_payment` para pedidos, así que algunos campos solo existen en uno de
/// los dos casos.
class AbonoTicket {
  const AbonoTicket({
    required this.kind,
    required this.scope,
    required this.businessName,
    required this.date,
    required this.customer,
    required this.folio,
    required this.saleTotal,
    required this.total,
    required this.previousDue,
    required this.abonado,
    required this.remainingDue,
    required this.liquidated,
    required this.estado,
    required this.expirationDate,
    required this.paymentMethod,
    required this.finalMessage,
  });

  factory AbonoTicket.fromJson(Map<String, dynamic> json) => AbonoTicket(
    kind: JsonReader.stringOr(json['kind'], 'abono'),
    scope: JsonReader.string(json['scope']),
    businessName: JsonReader.stringOr(json['businessName'], ''),
    date: JsonReader.string(json['date']),
    customer: JsonReader.stringOr(json['customer'], ''),
    folio: JsonReader.stringOr(json['folio'], ''),
    // Total de la venta (`saleTotal`) o del pedido (`total`).
    saleTotal: JsonReader.string(json['saleTotal']),
    total: JsonReader.string(json['total']),
    previousDue: JsonReader.string(json['previousDue']),
    abonado: JsonReader.string(json['abonado']),
    remainingDue: JsonReader.string(json['remainingDue']),
    liquidated: JsonReader.boolean(json['liquidated']),
    estado: JsonReader.string(json['estado']),
    expirationDate: JsonReader.string(json['expirationDate']),
    paymentMethod: JsonReader.string(json['paymentMethod']),
    finalMessage: JsonReader.string(json['finalMessage']),
  );

  /// `abono` (venta) o `order_payment` (pedido).
  final String kind;

  /// `transaction` en las ventas normales.
  final String? scope;
  final String businessName;
  final String? date;
  final String customer;
  final String folio;

  /// Total de la venta (solo `kind = abono`).
  final String? saleTotal;

  /// Total del pedido (solo `kind = order_payment`).
  final String? total;

  final String? previousDue;

  /// Monto abonado en esta operación (pagos + saldo a favor usado).
  final String? abonado;
  final String? remainingDue;

  /// La venta quedó liquidada con este abono.
  final bool liquidated;

  /// Estado del pedido (`Completado` / `Pendiente`).
  final String? estado;

  /// Vigencia del apartado (`d/m/Y`).
  final String? expirationDate;

  /// Desglose de métodos ya formateado por el servidor.
  final String? paymentMethod;
  final String? finalMessage;

  /// Total de la operación, sirva cual sea el tipo de ticket.
  String? get totalLabel => saleTotal ?? total;

  bool get isOrderPayment => kind == 'order_payment';
}

/// Ticket de WhatsApp que devuelve `POST /transactions/{id}/payments`.
///
/// La etapa de impresión (etapa 6) es la que envía este ticket; aquí se muestra
/// para que el cajero lo revise.
class AbonoReceipt {
  const AbonoReceipt({
    required this.type,
    required this.ticket,
    required this.transactionId,
    required this.customerPhone,
    required this.customerId,
  });

  factory AbonoReceipt.fromJson(Map<String, dynamic> json) => AbonoReceipt(
    type: JsonReader.stringOr(json['type'], 'abono'),
    ticket: AbonoTicket.fromJson(JsonReader.toMap(json['payload'])),
    transactionId: JsonReader.integer(json['transaction_id']),
    customerPhone: JsonReader.string(json['customer_phone']),
    customerId: JsonReader.integer(json['customer_id']),
  );

  /// `abono` o `order_payment`.
  final String type;
  final AbonoTicket ticket;
  final int? transactionId;

  /// Teléfono del cliente (`null` = se abre WhatsApp sin destinatario).
  final String? customerPhone;
  final int? customerId;

  /// Hay un teléfono al que enviar el ticket.
  bool get hasPhone => (customerPhone ?? '').trim().isNotEmpty;
}

/// Respuesta de `POST /transactions/{id}/payments`.
class AbonoResult {
  const AbonoResult({required this.transaction, required this.receipt});

  factory AbonoResult.fromJson(Map<String, dynamic> json) {
    final printInfo = JsonReader.toMap(json['print']);

    return AbonoResult(
      transaction: TransactionDetail.fromJson(
        JsonReader.toMap(json['transaction']),
      ),
      receipt: printInfo.isEmpty ? null : AbonoReceipt.fromJson(printInfo),
    );
  }

  final TransactionDetail transaction;
  final AbonoReceipt? receipt;
}

/// Respuesta de `POST /transactions/{id}/cancel` y `/refund`: la venta
/// actualizada y el `message` del servidor que explica el resultado.
class TransactionMutationResult {
  const TransactionMutationResult({
    required this.transaction,
    required this.message,
  });

  factory TransactionMutationResult.fromJson(Map<String, dynamic> json) =>
      TransactionMutationResult(
        transaction: TransactionDetail.fromJson(
          JsonReader.toMap(json['transaction']),
        ),
        message: JsonReader.stringOr(json['message'], ''),
      );

  final TransactionDetail transaction;
  final String message;
}

/// Respuesta de `PUT /transactions/{id}/payments/{paymentId}`.
class PaymentMutationResult {
  const PaymentMutationResult({
    required this.message,
    required this.payment,
    required this.transaction,
  });

  factory PaymentMutationResult.fromJson(Map<String, dynamic> json) =>
      PaymentMutationResult(
        message: JsonReader.stringOr(json['message'], ''),
        payment: json['payment'] == null
            ? null
            : TransactionPayment.fromJson(JsonReader.toMap(json['payment'])),
        transaction: TransactionDetail.fromJson(
          JsonReader.toMap(json['transaction']),
        ),
      );

  final String message;
  final TransactionPayment? payment;
  final TransactionDetail transaction;
}
