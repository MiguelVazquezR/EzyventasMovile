import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../customers/data/models/customer.dart';
import '../data/models/cart_line.dart';
import '../data/models/checkout_result.dart';
import '../data/models/payment_draft.dart';
import '../data/models/store_order_draft.dart';

/// Estado del carrito del POS.
///
/// Los totales replican **exactamente** el POS web (`ShoppingCart.vue`):
/// - `subtotal = Σ(precio de lista × cantidad)`
/// - `total_discount = Σ(descuento por unidad × cantidad)`
/// - `total = subtotal - total_discount`
///
/// Las promociones de carrito (mínimo de compra, N×M) las evalúa el servidor al
/// cobrar: la app no las descuenta por su cuenta.
class CartState {
  const CartState({
    this.lines = const <CartLine>[],
    this.customer,
    this.guestName = '',
    this.useBalance = false,
    this.payments = const <PaymentDraft>[],
    this.isSubmitting = false,
    this.result,
    this.errorMessage,
    this.errorFields = const <String, List<String>>{},
    this.notice,
  });

  final List<CartLine> lines;

  /// Cliente de la venta (necesario si queda saldo pendiente).
  final Customer? customer;

  /// Nombre de mostrador cuando no hay cliente seleccionado (`guest_name`).
  final String guestName;

  /// El cajero marcó "Usar saldo a favor" (`use_balance`).
  final bool useBalance;

  /// Pagos capturados (efectivo / tarjeta / transferencia).
  final List<PaymentDraft> payments;

  /// Petición de cobro, apartado o pedido en curso.
  final bool isSubmitting;

  /// Última venta registrada (folio, cambio y pista de impresión).
  final CheckoutResult? result;

  /// `message` del servidor.
  final String? errorMessage;

  /// Errores por campo del `422` (`cartItems`, `payments.0.bank_account_id`, ...).
  final Map<String, List<String>> errorFields;

  /// Aviso puntual (por ejemplo un tope de stock alcanzado).
  final String? notice;

  bool get isEmpty => lines.isEmpty;

  /// Suma de las cantidades (piezas o unidades a granel).
  double get itemCount =>
      Money.round2(lines.fold<double>(0, (sum, line) => sum + line.quantity));

  /// `Σ(precio de lista × cantidad)`.
  double get subtotal => Money.round2(
    lines.fold<double>(0, (sum, line) => sum + line.lineSubtotal),
  );

  /// `Σ(descuento por unidad × cantidad)`.
  double get totalDiscount => Money.round2(
    lines.fold<double>(0, (sum, line) => sum + line.lineDiscount),
  );

  /// Total a cobrar.
  double get total => Money.round2(
    lines.fold<double>(0, (sum, line) => sum + line.lineTotal),
  );

  /// Saldo a favor aplicado: `min(balance, total)` (igual que el servidor).
  double get balanceUsed {
    final balance = customer?.balance ?? 0;
    if (!useBalance || balance <= 0) {
      return 0;
    }

    return Money.round2(balance < total ? balance : total);
  }

  /// Suma de los pagos capturados.
  double get paymentsTotal => Money.round2(
    payments.fold<double>(0, (sum, payment) => sum + payment.amount),
  );

  /// Pagos + saldo a favor.
  double get paidTotal => Money.round2(paymentsTotal + balanceUsed);

  /// Lo que falta por cubrir (negativo = sobra, es el cambio).
  double get remaining => Money.round2(total - paidTotal);

  bool get isOverpaid => remaining < -0.01;

  /// Cambio en efectivo con el mismo criterio del servidor: solo cuando todos
  /// los pagos son en efectivo (`Σ pagos - total`, nunca negativo).
  double get change {
    if (payments.isEmpty || !payments.every((payment) => payment.isCash)) {
      return 0;
    }

    final over = Money.round2(paymentsTotal - total);
    return over > 0 ? over : 0;
  }

  /// Crédito disponible del cliente (`available_credit` del servidor).
  double get availableCredit => customer?.availableCredit ?? 0;

  /// Quedaría saldo pendiente y no hay cliente: el servidor responde
  /// `customer_required`, así que la app bloquea antes de enviar.
  bool get needsCustomer => remaining > 0.01 && customer == null;

  /// Quedaría saldo pendiente por encima del crédito del cliente
  /// (`credit_limit_exceeded`).
  bool get creditExceeded =>
      remaining > 0.01 && customer != null && remaining > availableCredit;

  /// Algún pago con tarjeta o transferencia sin cuenta destino
  /// (`bank_account_id` obligatorio).
  bool get hasIncompletePayments =>
      payments.any((payment) => !payment.isComplete);

  bool get canSubmitCheckout =>
      !isEmpty &&
      !isSubmitting &&
      !needsCustomer &&
      !creditExceeded &&
      !hasIncompletePayments;

  /// Motivo (texto aprobado del contrato) por el que no se puede cobrar aún.
  String? get blockerMessage {
    if (isEmpty) {
      return 'Agrega al menos un producto a la venta.';
    }

    if (hasIncompletePayments) {
      return 'Selecciona la cuenta destino para los pagos con tarjeta o transferencia.';
    }

    if (needsCustomer) {
      return 'Selecciona un cliente para dejar saldo pendiente.';
    }

    if (creditExceeded) {
      return 'El cliente no tiene crédito disponible suficiente.';
    }

    return null;
  }

  /// Payload de `POST /pos/checkout` y `POST /pos/layaway`.
  ///
  /// [layawayExpirationDate] solo viaja en el apartado (formato `YYYY-MM-DD`).
  Map<String, dynamic> buildSalePayload({
    required int sessionId,
    required String clientUuid,
    DateTime? layawayExpirationDate,
  }) {
    return <String, dynamic>{
      'client_uuid': clientUuid,
      'cash_register_session_id': sessionId,
      'customerId': customer?.id,
      'guest_name': (customer == null && guestName.trim().isNotEmpty)
          ? guestName.trim()
          : null,
      'cartItems': lines
          .map((line) => line.toCartItemJson())
          .toList(growable: false),
      'subtotal': subtotal,
      'total_discount': totalDiscount,
      'total': total,
      'payments': payments
          .where((payment) => payment.amount > 0)
          .map((payment) => payment.toJson())
          .toList(growable: false),
      'use_balance': useBalance && balanceUsed > 0,
      'layaway_expiration_date': layawayExpirationDate == null
          ? null
          : AppFormatters.apiDate(layawayExpirationDate),
    };
  }

  /// Payload de `POST /pos/store-order` (sin pagos; el servidor suma el envío).
  Map<String, dynamic> buildOrderPayload({
    required int sessionId,
    required StoreOrderDraft order,
    required String clientUuid,
  }) {
    return <String, dynamic>{
      'client_uuid': clientUuid,
      'cash_register_session_id': sessionId,
      'customerId': customer?.id,
      'cartItems': lines
          .map((line) => line.toCartItemJson())
          .toList(growable: false),
      'contact_info': order.toContactInfoJson(),
      'delivery_date': order.deliveryDate.toIso8601String(),
      'shipping_address': order.hasShippingAddress
          ? order.shippingAddress!.trim()
          : null,
      'shipping_cost': order.shippingCost,
      'subtotal': subtotal,
      'total_discount': totalDiscount,
      'notes': order.notes,
    };
  }

  CartState copyWith({
    List<CartLine>? lines,
    Customer? customer,
    String? guestName,
    bool? useBalance,
    List<PaymentDraft>? payments,
    bool? isSubmitting,
    CheckoutResult? result,
    String? errorMessage,
    Map<String, List<String>>? errorFields,
    String? notice,
    bool clearCustomer = false,
    bool clearResult = false,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      customer: clearCustomer ? null : (customer ?? this.customer),
      guestName: guestName ?? this.guestName,
      useBalance: clearCustomer ? false : (useBalance ?? this.useBalance),
      payments: payments ?? this.payments,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorFields: clearError
          ? const <String, List<String>>{}
          : (errorFields ?? this.errorFields),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }

  /// Primer error de validación de un campo devuelto por el servidor.
  String? errorFor(String field) {
    final messages = errorFields[field];
    if (messages == null || messages.isEmpty) {
      return null;
    }

    return messages.first;
  }
}
