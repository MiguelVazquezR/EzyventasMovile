import 'package:ezyventas_app/core/utils/money.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/customers/data/models/customer.dart';
import 'package:ezyventas_app/features/pos/application/cart_state.dart';
import 'package:ezyventas_app/features/pos/application/product_line_builder.dart';
import 'package:ezyventas_app/features/pos/data/models/cart_line.dart';
import 'package:ezyventas_app/features/pos/data/models/payment_draft.dart';
import 'package:ezyventas_app/features/pos/data/models/store_order_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// Producto simple con promoción de línea y precio de mayoreo
/// (misma forma que `GET /catalog/products`, verificada contra la API real).
Product productFixture() => Product.fromJson(<String, dynamic>{
  'id': 45,
  'name': 'Filtro de aceite',
  'sku': 'FIL-001',
  'selling_price': '150.00',
  'price': 135.0,
  'original_price': 150.0,
  'price_tiers': <Map<String, dynamic>>[
    <String, dynamic>{'min_quantity': 6, 'price': 130},
  ],
  'stock': 24.0,
  'reserved_stock': 0.0,
  'measure_unit': 'pz',
  'is_bulk': false,
  'show_in_pos': true,
  'variant_combinations': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 88,
      'attributes': <String, dynamic>{'Talla': 'M', 'Color': 'Azul'},
      'price_modifier': 15.0,
      'price': 150.0,
      'stock': 3,
      'reserved_stock': 0.0,
    },
  ],
});

Customer customerFixture({
  double balance = 0,
  double creditLimit = 2000,
  double availableCredit = 2000,
}) => Customer.fromJson(<String, dynamic>{
  'id': 8,
  'name': 'Ana Ramírez',
  'balance': '$balance',
  'credit_limit': '$creditLimit',
  'available_credit': availableCredit,
});

void main() {
  final product = productFixture();
  final variant = product.variantCombinations.single;

  group('ProductLineBuilder', () {
    test('aplica la promoción de línea del producto', () {
      final line = ProductLineBuilder.build(product, quantity: 2);

      expect(line.listPrice, 150.0);
      expect(line.unitPrice, 135.0);
      expect(line.discountPerUnit, 15.0);
      expect(line.discountReason, 'Promoción de producto');
      expect(line.lineSubtotal, 300.0);
      expect(line.lineDiscount, 30.0);
      expect(line.lineTotal, 270.0);
      expect(line.stockLimit, 24.0);
      expect(line.isManualPrice, isFalse);
    });

    test('aplica el mayoreo al cambiar la cantidad', () {
      final line = ProductLineBuilder.build(product, quantity: 5);
      expect(line.unitPrice, 135.0);

      final wholesale = ProductLineBuilder.applyQuantity(line, 6);

      expect(wholesale.isTierPrice, isTrue);
      expect(wholesale.unitPrice, 130.0);
      expect(wholesale.discountPerUnit, 20.0);
      expect(wholesale.discountReason, 'Precio de mayoreo');
      expect(wholesale.lineTotal, 780.0);

      // Volver a una cantidad menor regresa al precio normal.
      final back = ProductLineBuilder.applyQuantity(wholesale, 2);
      expect(back.unitPrice, 135.0);
      expect(back.discountReason, 'Promoción de producto');
    });

    test('usa la variante elegida (product_attribute_id)', () {
      final line = ProductLineBuilder.build(
        product,
        variant: variant,
        quantity: 1,
      );

      expect(line.variantId, 88);
      expect(line.variantLabel, 'Talla M · Color Azul');
      expect(line.unitPrice, 150.0);
      expect(line.listPrice, 165.0);
      expect(line.discountPerUnit, 15.0);
      expect(line.stockLimit, 3.0);
      expect(line.toCartItemJson()['product_attribute_id'], 88);
    });

    test('el precio manual respeta descuento y aumento', () {
      final line = ProductLineBuilder.build(product, quantity: 1);
      final discount = ProductLineBuilder.withManualPrice(line, 100);

      expect(discount.isManualPrice, isTrue);
      expect(discount.discountPerUnit, 50.0);
      expect(discount.discountReason, 'Descuento manual');

      // Con precio manual, cambiar la cantidad no vuelve al mayoreo.
      final more = ProductLineBuilder.applyQuantity(discount, 10);
      expect(more.unitPrice, 100.0);
      expect(more.isManualPrice, isTrue);

      final increase = ProductLineBuilder.withManualPrice(line, 200);
      expect(increase.discountPerUnit, 0.0);
      expect(increase.discountReason, 'Aumento manual');
    });
  });

  group('CartState', () {
    CartLine line({double quantity = 2, VariantCombination? variant}) =>
        ProductLineBuilder.build(
          product,
          variant: variant,
          quantity: quantity,
        );

    test('suma subtotal, descuento y total como el POS web', () {
      final cart = CartState(lines: <CartLine>[line()]);

      expect(cart.subtotal, 300.0);
      expect(cart.totalDiscount, 30.0);
      expect(cart.total, 270.0);
      expect(cart.itemCount, 2.0);
      expect(cart.isEmpty, isFalse);
    });

    test('el saldo a favor se aplica hasta el total', () {
      final cart = CartState(
        lines: <CartLine>[line()],
        customer: customerFixture(balance: 500),
        useBalance: true,
      );

      expect(cart.balanceUsed, 270.0);
      expect(cart.paidTotal, 270.0);
      expect(cart.remaining, 0.0);
      expect(cart.canSubmitCheckout, isTrue);
    });

    test('bloquea la venta con saldo pendiente sin cliente', () {
      final cart = CartState(lines: <CartLine>[line()]);

      expect(cart.needsCustomer, isTrue);
      expect(cart.canSubmitCheckout, isFalse);
      expect(
        cart.blockerMessage,
        'Selecciona un cliente para dejar saldo pendiente.',
      );
    });

    test('bloquea la venta cuando el crédito no alcanza', () {
      final cart = CartState(
        lines: <CartLine>[line()],
        customer: customerFixture(
          creditLimit: 100,
          availableCredit: 100,
        ),
      );

      expect(cart.creditExceeded, isTrue);
      expect(
        cart.blockerMessage,
        'El cliente no tiene crédito disponible suficiente.',
      );
    });

    test('exige la cuenta destino en tarjeta y transferencia', () {
      final cart = CartState(
        lines: <CartLine>[line()],
        payments: <PaymentDraft>[
          const PaymentDraft(method: PosPaymentMethod.card, amount: 270),
        ],
      );

      expect(cart.hasIncompletePayments, isTrue);
      expect(
        cart.blockerMessage,
        'Selecciona la cuenta destino para los pagos con tarjeta o transferencia.',
      );

      final complete = CartState(
        lines: <CartLine>[line()],
        payments: <PaymentDraft>[
          const PaymentDraft(
            method: PosPaymentMethod.card,
            amount: 270,
            bankAccountId: 2,
          ),
        ],
      );

      expect(complete.hasIncompletePayments, isFalse);
      expect(complete.canSubmitCheckout, isTrue);
    });

    test('el cambio solo se calcula con efectivo puro (regla del servidor)', () {
      final cashOnly = CartState(
        lines: <CartLine>[line()],
        payments: <PaymentDraft>[
          const PaymentDraft(method: PosPaymentMethod.cash, amount: 500),
        ],
      );

      expect(cashOnly.remaining, -230.0);
      expect(cashOnly.isOverpaid, isTrue);
      expect(cashOnly.change, 230.0);

      final mixed = CartState(
        lines: <CartLine>[line()],
        payments: <PaymentDraft>[
          const PaymentDraft(method: PosPaymentMethod.cash, amount: 400),
          const PaymentDraft(
            method: PosPaymentMethod.transfer,
            amount: 100,
            bankAccountId: 2,
          ),
        ],
      );

      expect(mixed.change, 0.0);
    });
  });

  group('payloads', () {
    final cart = CartState(
      lines: <CartLine>[ProductLineBuilder.build(product, quantity: 2)],
      customer: customerFixture(),
      payments: <PaymentDraft>[
        const PaymentDraft(method: PosPaymentMethod.cash, amount: 300),
      ],
    );

    test('arma el payload de /pos/checkout con el contrato exacto', () {
      final payload = cart.buildSalePayload(
        sessionId: 41,
        clientUuid: '9c2f7a1b-7d3e-4a55-8f21-0c9d4e7a1b30',
      );

      expect(payload['cash_register_session_id'], 41);
      expect(payload['customerId'], 8);
      expect(payload['guest_name'], isNull);
      expect(payload['subtotal'], 300.0);
      expect(payload['total_discount'], 30.0);
      expect(payload['total'], 270.0);
      expect(payload['use_balance'], isFalse);
      expect(payload['layaway_expiration_date'], isNull);

      final item = (payload['cartItems']! as List<dynamic>).single
          as Map<String, dynamic>;
      expect(item['id'], 45);
      expect(item['product_attribute_id'], isNull);
      expect(item['quantity'], 2.0);
      expect(item['unit_price'], 135.0);
      expect(item['description'], 'Filtro de aceite');
      // `discount` es por unidad, no por línea.
      expect(item['discount'], 15.0);
      expect(item['discount_reason'], 'Promoción de producto');

      final payment = (payload['payments']! as List<dynamic>).single
          as Map<String, dynamic>;
      expect(payment['method'], 'efectivo');
      expect(payment['amount'], 300.0);
      expect(payment['bank_account_id'], isNull);
    });

    test('envía la fecha límite del apartado en formato YYYY-MM-DD', () {
      final payload = cart.buildSalePayload(
        sessionId: 41,
        clientUuid: 'uuid',
        layawayExpirationDate: DateTime(2026, 10, 15),
      );

      expect(payload['layaway_expiration_date'], '2026-10-15');
    });

    test('marca use_balance solo con cliente y saldo a favor', () {
      final withBalance = cart.copyWith(
        customer: customerFixture(balance: 500),
        useBalance: true,
      );

      final payload = withBalance.buildSalePayload(
        sessionId: 41,
        clientUuid: 'uuid',
      );

      expect(payload['use_balance'], isTrue);
      expect(withBalance.balanceUsed, 270.0);
    });

    test('usa guest_name cuando la venta es de público general', () {
      final guest = cart.copyWith(
        clearCustomer: true,
        guestName: 'Cliente mostrador',
      );

      final payload = guest.buildSalePayload(
        sessionId: 41,
        clientUuid: 'uuid',
      );

      expect(payload['customerId'], isNull);
      expect(payload['guest_name'], 'Cliente mostrador');
    });

    test('arma el payload de /pos/store-order sin pagos', () {
      final payload = cart.buildOrderPayload(
        sessionId: 41,
        clientUuid: 'uuid',
        order: StoreOrderDraft(
          contactName: 'Ana Ramírez',
          contactPhone: '4771112233',
          deliveryDate: DateTime(2026, 9, 20, 18),
          shippingAddress: 'Av. Hidalgo 120, León',
          shippingCost: 80,
          notes: 'Entregar después de las 6 pm',
        ),
      );

      expect(payload['cash_register_session_id'], 41);
      expect(payload['customerId'], 8);
      expect(payload['subtotal'], 300.0);
      expect(payload['total_discount'], 30.0);
      expect(payload['shipping_cost'], 80.0);
      expect(payload.containsKey('payments'), isFalse);
      expect(payload.containsKey('use_balance'), isFalse);

      final contact = payload['contact_info']! as Map<String, dynamic>;
      expect(contact['name'], 'Ana Ramírez');
      expect(contact['phone'], '4771112233');
      expect(contact['type'], 'pedido');
      expect(payload['delivery_date'], startsWith('2026-09-20T18:00'));
      expect(payload['notes'], 'Entregar después de las 6 pm');
    });

    test('la comanda viaja con type comanda', () {
      final payload = cart.buildOrderPayload(
        sessionId: 41,
        clientUuid: 'uuid',
        order: StoreOrderDraft(
          contactName: 'Mesa 4',
          type: StoreOrderDraft.comanda,
          deliveryDate: DateTime(2026, 9, 20, 14),
        ),
      );

      final contact = payload['contact_info']! as Map<String, dynamic>;
      expect(contact['type'], 'comanda');
      expect(payload['shipping_address'], isNull);
      expect(payload['shipping_cost'], 0.0);
    });

    test('la línea del carrito redondea a centavos', () {
      final odd = CartLine(
        productId: 1,
        productName: 'Granel',
        listPrice: 10.005,
        unitPrice: 10,
        quantity: 3,
        isBulk: true,
      );

      expect(odd.lineTotal, Money.round2(30));
      expect(odd.toCartItemJson()['quantity'], 3.0);
    });
  });
}
