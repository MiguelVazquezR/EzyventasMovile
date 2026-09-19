import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/data/models/product.dart';
import '../../cash/application/cash_register_controller.dart';
import '../../customers/data/models/customer.dart';
import '../data/models/cart_line.dart';
import '../data/models/checkout_result.dart';
import '../data/models/payment_draft.dart';
import '../data/models/store_order_draft.dart';
import '../data/pos_repository.dart';
import 'cart_state.dart';
import 'product_line_builder.dart';

/// Repositorio de escrituras del POS.
final posRepositoryProvider = Provider<PosRepository>(
  (ref) => PosRepository(api: ref.watch(apiClientProvider)),
);

/// Carrito del POS.
///
/// Mantiene las líneas, el cliente, los pagos y el resultado de la venta. Al
/// cobrar, refresca el catálogo (stock) y el turno de caja (cobros por método)
/// con los mismos datos que verá la web.
class CartController extends Notifier<CartState> {
  /// Se reutiliza en reintentos del mismo cobro (`client_uuid` idempotente).
  String? _pendingClientUuid;

  @override
  CartState build() => const CartState();

  String _clientUuidFor() => _pendingClientUuid ??= UuidGenerator.v4();

  // --- Líneas -------------------------------------------------------------

  /// Agrega un producto del catálogo (y su variante) al carrito.
  void addProduct(
    Product product, {
    VariantCombination? variant,
    double quantity = 1,
  }) => addLine(
    ProductLineBuilder.build(product, variant: variant, quantity: quantity),
  );

  /// Agrega una línea; si ya existe la misma variante del mismo producto, suma
  /// la cantidad (sin tocar un precio capturado a mano).
  void addLine(CartLine line) {
    final index = state.lines.indexWhere((existing) => existing.matches(line));

    if (index < 0) {
      final fitted = _fitToStock(line, line.quantity);
      state = state.copyWith(
        lines: <CartLine>[...state.lines, fitted],
        notice: fitted.quantity < line.quantity
            ? 'El producto ya no tiene stock suficiente.'
            : null,
        clearNotice: fitted.quantity >= line.quantity,
        clearError: true,
      );
      return;
    }

    final existing = state.lines[index];
    setQuantity(existing, Money.round2(existing.quantity + line.quantity));
  }

  /// Suma una unidad (o medio kilo si el producto es a granel).
  void incrementLine(CartLine line) =>
      setQuantity(line, Money.round2(line.quantity + _step(line)));

  /// Resta una unidad; en 0 se elimina la línea.
  void decrementLine(CartLine line) {
    final next = Money.round2(line.quantity - _step(line));

    if (next <= 0) {
      removeLine(line);
      return;
    }

    setQuantity(line, next);
  }

  /// Cambia la cantidad y recalcula el precio de mayoreo.
  ///
  /// La app nunca pide más que el stock de la sucursal: el servidor respondería
  /// `insufficient_stock`.
  void setQuantity(CartLine line, double quantity) {
    final index = _indexOf(line);
    if (index < 0) {
      return;
    }

    final minimum = line.isBulk ? 0.01 : 1.0;
    final requested = quantity < minimum ? minimum : quantity;
    final fitted = line.exceedsStock(requested) ? line.stockLimit : requested;
    final clamped = fitted < minimum ? minimum : fitted;

    state = state.copyWith(
      lines: _replaced(
        index,
        ProductLineBuilder.applyQuantity(line, Money.round2(clamped)),
      ),
      notice: clamped < requested
          ? 'El producto ya no tiene stock suficiente.'
          : null,
      clearNotice: clamped >= requested,
      clearError: true,
    );
  }

  /// Precio por unidad capturado por el cajero (`pos.edit_prices`).
  void setUnitPrice(CartLine line, double unitPrice) {
    final index = _indexOf(line);
    if (index < 0) {
      return;
    }

    state = state.copyWith(
      lines: _replaced(
        index,
        ProductLineBuilder.withManualPrice(line, unitPrice),
      ),
      clearError: true,
      clearNotice: true,
    );
  }

  /// Descuento por unidad capturado por el cajero: baja el precio de la línea.
  void setDiscountPerUnit(CartLine line, double discount) {
    final value = discount < 0 ? 0 : discount;
    setUnitPrice(line, Money.round2(line.listPrice - value));
  }

  /// Devuelve la línea al precio del catálogo (quita el precio manual).
  void clearManualPrice(CartLine line) {
    final index = _indexOf(line);
    if (index < 0) {
      return;
    }

    final restored = ProductLineBuilder.applyQuantity(
      line.copyWith(
        unitPrice: line.basePrice ?? line.unitPrice,
        isManualPrice: false,
        isTierPrice: false,
        clearDiscountReason: true,
      ),
      line.quantity,
    );

    state = state.copyWith(lines: _replaced(index, restored));
  }

  void removeLine(CartLine line) {
    final index = _indexOf(line);
    if (index < 0) {
      return;
    }

    final lines = <CartLine>[...state.lines]..removeAt(index);
    state = state.copyWith(lines: lines, clearError: true, clearNotice: true);
  }

  /// Vacía el carrito (el cliente se conserva salvo que se pida lo contrario).
  void clear({bool keepCustomer = true}) {
    _pendingClientUuid = null;

    state = CartState(
      customer: keepCustomer ? state.customer : null,
      guestName: keepCustomer ? state.guestName : '',
    );
  }

  // --- Cliente y saldo a favor --------------------------------------------

  void setCustomer(Customer? customer) {
    state = customer == null
        ? state.copyWith(clearCustomer: true, clearError: true)
        : state.copyWith(customer: customer, clearError: true);
  }

  void setGuestName(String name) =>
      state = state.copyWith(guestName: name, clearError: true);

  /// "Usar saldo a favor" (`use_balance`).
  void setUseBalance(bool useBalance) =>
      state = state.copyWith(useBalance: useBalance, clearError: true);

  // --- Pagos ---------------------------------------------------------------

  /// Prepara el cobro al contado: un pago en efectivo por el total (igual que
  /// el POS web).
  void preparePayments() {
    if (state.payments.isNotEmpty || state.total <= 0) {
      return;
    }

    state = state.copyWith(
      payments: <PaymentDraft>[
        PaymentDraft(method: PosPaymentMethod.cash, amount: state.total),
      ],
      clearError: true,
    );
  }

  /// Agrega un método de pago; el monto inicial es lo que falta por cubrir.
  void addPayment(PosPaymentMethod method) {
    if (state.payments.any((payment) => payment.method == method)) {
      return;
    }

    var payments = <PaymentDraft>[...state.payments];

    // Sustitución inteligente (igual que la web): si solo hay un pago en
    // efectivo que cubre el total exacto, se reemplaza por el método elegido.
    if (payments.length == 1 &&
        payments.first.isCash &&
        payments.first.amount == state.total) {
      payments = <PaymentDraft>[];
    }

    final covered = state.balanceUsed + _paymentsSum(payments);
    final missing = Money.round2(state.total - covered);

    state = state.copyWith(
      payments: <PaymentDraft>[
        ...payments,
        PaymentDraft(
          method: method,
          amount: missing > 0 ? missing : 0,
        ),
      ],
      useBalance: state.useBalance && state.balanceUsed > 0,
      clearError: true,
    );
  }

  void setPaymentAmount(int index, double amount) =>
      _updatePayment(index, (payment) => payment.copyWith(amount: amount < 0 ? 0 : amount));

  /// Cuenta destino de un pago con tarjeta o transferencia.
  void setPaymentBankAccount(int index, {required int id, required String name}) =>
      _updatePayment(
        index,
        (payment) => payment.copyWith(bankAccountId: id, bankAccountName: name),
      );

  void removePayment(int index) {
    if (index < 0 || index >= state.payments.length) {
      return;
    }

    final payments = <PaymentDraft>[...state.payments]..removeAt(index);
    state = state.copyWith(payments: payments, clearError: true);
  }

  void _updatePayment(
    int index,
    PaymentDraft Function(PaymentDraft payment) update,
  ) {
    if (index < 0 || index >= state.payments.length) {
      return;
    }

    final payments = <PaymentDraft>[...state.payments];
    payments[index] = update(payments[index]);
    state = state.copyWith(payments: payments, clearError: true);
  }

  double _paymentsSum(List<PaymentDraft> payments) =>
      payments.fold<double>(0, (sum, payment) => sum + payment.amount);

  double _step(CartLine line) => line.isBulk ? 0.5 : 1;

  /// Índice de la línea en el carrito.
  ///
  /// Primero por identidad (la lista se reemplaza con copias en cada cambio) y,
  /// si la instancia ya no está (por ejemplo un diálogo abierto), por
  /// producto + variante.
  int _indexOf(CartLine line) {
    final exact = state.lines.indexOf(line);
    if (exact >= 0) {
      return exact;
    }

    return state.lines.indexWhere(
      (candidate) =>
          candidate.productId == line.productId &&
          candidate.variantId == line.variantId,
    );
  }

  List<CartLine> _replaced(int index, CartLine line) =>
      <CartLine>[...state.lines]..[index] = line;

  CartLine _fitToStock(CartLine line, double quantity) {
    if (!line.exceedsStock(quantity)) {
      return line;
    }

    return ProductLineBuilder.applyQuantity(line, line.stockLimit);
  }

  // --- Cobro ---------------------------------------------------------------

  /// `POST /pos/checkout`: venta de contado (o a crédito si queda saldo).
  Future<CheckoutResult?> checkout({required int sessionId}) => _submit(
    () => ref
        .read(posRepositoryProvider)
        .checkout(
          state.buildSalePayload(
            sessionId: sessionId,
            clientUuid: _clientUuidFor(),
          ),
        ),
  );

  /// `POST /pos/layaway`: apartado con fecha límite (`after:today`).
  Future<CheckoutResult?> layaway({
    required int sessionId,
    required DateTime expirationDate,
  }) => _submit(
    () => ref
        .read(posRepositoryProvider)
        .layaway(
          state.buildSalePayload(
            sessionId: sessionId,
            clientUuid: _clientUuidFor(),
            layawayExpirationDate: expirationDate,
          ),
        ),
  );

  /// `POST /pos/store-order`: pedido o comanda (sin pagos, stock reservado).
  Future<CheckoutResult?> submitOrder({
    required int sessionId,
    required StoreOrderDraft order,
  }) => _submit(
    () => ref
        .read(posRepositoryProvider)
        .storeOrder(
          state.buildOrderPayload(
            sessionId: sessionId,
            order: order,
            clientUuid: _clientUuidFor(),
          ),
        ),
  );

  /// Envía la operación y deja el carrito listo para la siguiente venta.
  ///
  /// Al terminar se refrescan el catálogo (stock) y el turno de caja (cobros por
  /// método) para que la app muestre lo mismo que la web.
  Future<CheckoutResult?> _submit(
    Future<CheckoutResult> Function() request,
  ) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await request();
      _pendingClientUuid = null;

      state = CartState(
        customer: state.customer,
        guestName: state.guestName,
        result: result,
      );

      ref.read(productsControllerProvider.notifier).refresh().ignore();
      ref.read(cashRegisterControllerProvider.notifier).refresh().ignore();

      return result;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
        errorFields: error.errors,
      );

      return null;
    }
  }

  /// Descarta el resultado mostrado (al cerrar el ticket de la venta).
  void consumeResult() {
    if (state.result != null) {
      state = state.copyWith(clearResult: true);
    }
  }

  void consumeError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void consumeNotice() {
    if (state.notice != null) {
      state = state.copyWith(clearNotice: true);
    }
  }
}

final cartControllerProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);
