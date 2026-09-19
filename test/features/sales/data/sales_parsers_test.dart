import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/utils/app_formatters.dart';
import 'package:ezyventas_app/features/sales/data/models/refund_method.dart';
import 'package:ezyventas_app/features/sales/data/models/sales_mutation_results.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_detail.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_filters.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_payment_method.dart';
import 'package:ezyventas_app/features/sales/data/models/transaction_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Venta del listado tal como la devuelve `GET /transactions` (contrato §8):
/// `subtotal`/`total_discount`/`shipping_cost` en texto decimal y
/// `total`/`total_paid`/`remaining_due`/`items_count` numéricos.
Map<String, dynamic> listItemFixture() => <String, dynamic>{
  'id': 987,
  'folio': 'V-014',
  'status': 'pendiente',
  'channel': 'punto_de_venta',
  'customer': <String, dynamic>{'id': 8, 'name': 'Ana Ramírez'},
  'user': <String, dynamic>{'id': 7, 'name': 'María López'},
  'contact_info': null,
  'delivery_date': null,
  'layaway_expiration_date': null,
  'subtotal': '270.00',
  'total_discount': '30.00',
  'shipping_cost': '0.00',
  'total': 270.0,
  'total_paid': 70.0,
  'remaining_due': 200.0,
  'items_count': 1,
  'is_order': false,
  'invoiced': false,
  'created_at': '2026-09-18T14:35:00.000000Z',
};

/// Respuesta de `POST /transactions/{id}/payments` para una venta normal.
Map<String, dynamic> abonoFixture() => <String, dynamic>{
  'transaction': detailFixture(),
  'print': <String, dynamic>{
    'type': 'abono',
    'payload': <String, dynamic>{
      'kind': 'abono',
      'scope': 'transaction',
      'businessName': 'Refaccionaria Aponte',
      'date': '18/09/2026 - 15:10',
      'customer': 'Ana Ramírez',
      'folio': 'V-014',
      'saleTotal': r'$270.00 MXN',
      'previousDue': r'$200.00 MXN',
      'abonado': r'$200.00 MXN',
      'remainingDue': r'$0.00 MXN',
      'liquidated': true,
      'expirationDate': null,
      'paymentMethod': r'Efectivo: $200.00',
    },
    'transaction_id': 987,
    'customer_phone': '4771112233',
    'customer_id': 8,
  },
};

/// Detalle completo (`GET /transactions/{id}`): el listado más ítems, pagos y
/// desglose de saldo ya resuelto por el servidor.
Map<String, dynamic> detailFixture() => <String, dynamic>{
  ...listItemFixture(),
  'branch': <String, dynamic>{'id': 2, 'name': 'Sucursal Centro'},
  'customer': <String, dynamic>{
    'id': 8,
    'name': 'Ana Ramírez',
    'balance': '-350.00',
    'credit_limit': '2000.00',
  },
  'notes': 'Entregar por la tarde',
  'shipping_address': null,
  'total_tax': '0.00',
  'paid_amount': 70.0,
  'pending_balance': 200.0,
  'is_paid': false,
  'invoice': null,
  'cash_register_session': <String, dynamic>{'id': 41},
  'items': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 5510,
      'description': 'Filtro de aceite',
      'itemable_type': 'App\\Models\\Product',
      'itemable_id': 45,
      'quantity': 2,
      'unit_price': '135.00',
      'discount_amount': '15.00',
      'discount_reason': 'Promoción de producto',
      'tax_amount': '0.00',
      'line_total': '240.00',
    },
    <String, dynamic>{
      'id': 5511,
      'description': 'Aceite 1L',
      'itemable_type': 'App\\Models\\Service',
      'itemable_id': 12,
      'quantity': 1.5,
      'unit_price': '80.00',
      'discount_amount': '0.00',
      'discount_reason': null,
      'tax_amount': '0.00',
      'line_total': '120.00',
    },
  ],
  'payments': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 3312,
      'amount': '70.00',
      'payment_method': 'efectivo',
      'status': 'completado',
      'payment_date': '2026-09-18T14:35:00.000000Z',
      'notes': null,
      'bank_account': null,
    },
    <String, dynamic>{
      'id': 3313,
      'amount': '150.00',
      'payment_method': 'transferencia',
      'status': 'completado',
      'payment_date': '2026-09-18T15:00:00.000000Z',
      'notes': 'Voucher 1234',
      'bank_account': <String, dynamic>{
        'id': 2,
        'name': 'Cuenta principal - BBVA (...4471)',
        'bank_name': 'BBVA',
        'account_name': 'Cuenta principal',
        'balance': '5000.00',
      },
    },
  ],
};

void main() {
  group('TransactionSummary', () {
    test('lee los tipos reales del listado (texto y número)', () {
      final summary = TransactionSummary.fromJson(listItemFixture());

      expect(summary.id, 987);
      expect(summary.folio, 'V-014');
      expect(summary.status, 'pendiente');
      expect(summary.channel, 'punto_de_venta');
      expect(summary.subtotal, 270.0);
      expect(summary.totalDiscount, 30.0);
      expect(summary.shippingCost, 0.0);
      expect(summary.total, 270.0);
      expect(summary.totalPaid, 70.0);
      expect(summary.remainingDue, 200.0);
      expect(summary.itemsCount, 1);
      expect(summary.isOrder, isFalse);
      expect(summary.invoiced, isFalse);
      expect(summary.customerLabel, 'Ana Ramírez');
      expect(summary.hasPendingBalance, isTrue);
      expect(summary.isCancelled, isFalse);
      expect(summary.createdAt, isNotNull);
    });

    test('usa el contacto del pedido y cae a público general', () {
      final order = TransactionSummary.fromJson(<String, dynamic>{
        ...listItemFixture(),
        'customer': null,
        'contact_info': <String, dynamic>{
          'name': 'Mesa 4',
          'phone': '4772223344',
          'type': 'comanda',
        },
        'delivery_date': '2026-09-20T18:00:00.000000Z',
        'is_order': true,
      });

      expect(order.customerLabel, 'Mesa 4');
      expect(order.contactPhone, '4772223344');
      expect(order.isOrder, isTrue);

      final guest = TransactionSummary.fromJson(<String, dynamic>{
        ...listItemFixture(),
        'customer': null,
      });

      expect(guest.customerLabel, 'Público general');
    });

    test('marca la venta anulada y calcula los días del apartado', () {
      final future = DateTime.now().add(const Duration(days: 5));
      final layaway = TransactionSummary.fromJson(<String, dynamic>{
        ...listItemFixture(),
        'status': 'apartado',
        'layaway_expiration_date': AppFormatters.apiDate(future),
      });

      expect(layaway.isLayaway, isTrue);
      expect(layaway.layawayDaysLeft, 5);

      final cancelled = TransactionSummary.fromJson(<String, dynamic>{
        ...listItemFixture(),
        'status': 'reembolsado',
      });

      expect(cancelled.isCancelled, isTrue);
    });

    test('una venta anulada con saldo histórico no se marca como pendiente', () {
      // `remaining_due` es `max(0, total - total_paid)`: el servidor conserva el
      // saldo aunque la venta ya esté cancelada o reembolsada.
      final refunded = TransactionSummary.fromJson(<String, dynamic>{
        ...listItemFixture(),
        'status': 'reembolsado',
        'remaining_due': 138.0,
      });

      expect(refunded.remainingDue, 138.0);
      expect(refunded.hasPendingBalance, isFalse);
    });
  });

  group('TransactionDetail', () {
    test('lee ítems, pagos y desglose de saldo', () {
      final detail = TransactionDetail.fromJson(detailFixture());

      expect(detail.folio, 'V-014');
      expect(detail.branch?.name, 'Sucursal Centro');
      expect(detail.customer?.name, 'Ana Ramírez');
      expect(detail.customer?.balance, -350.0);
      expect(detail.customer?.hasDebt, isTrue);
      expect(detail.customer?.creditLimit, 2000.0);
      expect(detail.notes, 'Entregar por la tarde');
      expect(detail.totalTax, 0.0);
      expect(detail.paidAmount, 70.0);
      expect(detail.pendingBalance, 200.0);
      expect(detail.isPaid, isFalse);
      expect(detail.cashRegisterSessionId, 41);
      expect(detail.invoice, isNull);
      expect(detail.hasInvoice, isFalse);

      expect(detail.items.length, 2);
      final first = detail.items.first;
      expect(first.description, 'Filtro de aceite');
      expect(first.quantity, 2.0);
      expect(first.unitPrice, 135.0);
      expect(first.discountAmount, 15.0);
      expect(first.discountReason, 'Promoción de producto');
      expect(first.lineTotal, 240.0);
      expect(first.hasDiscount, isTrue);
      expect(first.isIncrease, isFalse);

      final second = detail.items[1];
      expect(second.quantity, 1.5);
      expect(second.hasDiscount, isFalse);
      expect(second.itemableType, 'App\\Models\\Service');

      expect(detail.payments.length, 2);
      final cash = detail.payments.first;
      expect(cash.amount, 70.0);
      expect(cash.methodLabel, 'Efectivo');
      expect(cash.bankAccount, isNull);
      expect(cash.isRefund, isFalse);

      final transfer = detail.payments[1];
      expect(transfer.amount, 150.0);
      expect(transfer.methodLabel, 'Transferencia');
      expect(transfer.bankAccount?.bankName, 'BBVA');
      expect(transfer.notes, 'Voucher 1234');
    });

    test('acumula el listado y expone las acciones disponibles', () {
      final detail = TransactionDetail.fromJson(detailFixture());

      expect(detail.subtotal, 270.0);
      expect(detail.total, 270.0);
      expect(detail.itemsCount, 1);
      expect(detail.customerLabel, 'Ana Ramírez');
      expect(detail.canReceivePayment, isTrue);
      expect(detail.canBeCancelled, isTrue);
      expect(detail.canEditPayments, isTrue);

      final paid = TransactionDetail.fromJson(<String, dynamic>{
        ...detailFixture(),
        'status': 'completado',
        'is_paid': true,
        'pending_balance': 0.0,
      });

      expect(paid.canReceivePayment, isFalse);

      final cancelled = TransactionDetail.fromJson(<String, dynamic>{
        ...detailFixture(),
        'status': 'cancelado',
      });

      expect(cancelled.canBeCancelled, isFalse);
      expect(cancelled.canEditPayments, isFalse);
    });

    test('marca las devoluciones (monto negativo)', () {
      final detail = TransactionDetail.fromJson(<String, dynamic>{
        ...detailFixture(),
        'payments': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 4000,
            'amount': '-70.00',
            'payment_method': 'efectivo',
            'status': 'completado',
            'payment_date': '2026-09-18T16:00:00.000000Z',
            'notes': null,
            'bank_account': null,
          },
        ],
      });

      expect(detail.payments.single.isRefund, isTrue);
    });
  });

  group('TransactionFilters', () {
    test('arma los parámetros exactos del contrato', () {
      final filters = TransactionFilters(
        search: 'V-014',
        status: 'apartado',
        dateStart: DateTime(2026, 9, 1),
        dateEnd: DateTime(2026, 9, 18),
        sort: TransactionSort.total,
      );

      final query = filters.toQuery();

      expect(query['search'], 'V-014');
      expect(query['status'], 'apartado');
      expect(query['date_start'], '2026-09-01');
      expect(query['date_end'], '2026-09-18');
      expect(query['sortField'], 'total');
      expect(query['sortOrder'], 'desc');
      expect(filters.hasFilters, isTrue);
    });

    test('omite los filtros vacíos y respeta el orden por defecto', () {
      const filters = TransactionFilters();
      final query = filters.toQuery();

      expect(query['search'], isNull);
      expect(query['status'], isNull);
      expect(query['date_start'], isNull);
      expect(query['date_end'], isNull);
      expect(query['sortField'], 'created_at');
      expect(query['sortOrder'], 'desc');
      expect(filters.hasFilters, isFalse);
    });

    test('limpia estatus y fechas conservando el orden', () {
      final filters = TransactionFilters(
        search: 'ana',
        status: 'pendiente',
        dateStart: DateTime(2026, 9, 1),
        sort: TransactionSort.folio,
      ).copyWith(clearStatus: true, clearDateStart: true);

      expect(filters.search, 'ana');
      expect(filters.status, isNull);
      expect(filters.dateStart, isNull);
      expect(filters.sort, TransactionSort.folio);
    });
  });

  group('Enums de pago', () {
    test('TransactionPaymentMethod exige cuenta en tarjeta y transferencia', () {
      expect(TransactionPaymentMethod.cash.requiresBankAccount, isFalse);
      expect(TransactionPaymentMethod.card.requiresBankAccount, isTrue);
      expect(TransactionPaymentMethod.transfer.requiresBankAccount, isTrue);
      expect(TransactionPaymentMethod.balance.requiresBankAccount, isFalse);
      expect(TransactionPaymentMethod.cash.isAllowedOnAbono, isTrue);
      expect(TransactionPaymentMethod.balance.isAllowedOnAbono, isFalse);
      expect(TransactionPaymentMethod.labelOf('saldo'), 'Saldo de cliente');
      expect(TransactionPaymentMethod.labelOf('desconocido'), '—');
      expect(TransactionPaymentMethod.labelOf(null), '—');
    });

    test('el formulario de edición conserva el método intercambio', () {
      final options = TransactionPaymentMethod.editableOptions(
        TransactionPaymentMethod.exchange,
      );

      expect(options, contains(TransactionPaymentMethod.exchange));
      expect(options, contains(TransactionPaymentMethod.balance));
      expect(
        TransactionPaymentMethod.editableOptions(TransactionPaymentMethod.cash),
        isNot(contains(TransactionPaymentMethod.exchange)),
      );
    });

    test('RefundMethod valida turno y cuenta destino', () {
      expect(RefundMethod.cash.requiresSession, isTrue);
      expect(RefundMethod.balance.requiresBankAccount, isFalse);
      expect(RefundMethod.transfer.requiresBankAccount, isTrue);
      expect(RefundMethod.fromValue('transfer'), RefundMethod.transfer);
      expect(RefundMethod.fromValue('otro'), isNull);
    });
  });

  group('AbonoResult y ticket', () {
    test('lee la venta actualizada y el ticket de abono', () {
      final result = AbonoResult.fromJson(abonoFixture());

      expect(result.transaction.folio, 'V-014');
      expect(result.receipt, isNotNull);

      final receipt = result.receipt!;
      expect(receipt.type, 'abono');
      expect(receipt.hasPhone, isTrue);
      expect(receipt.customerPhone, '4771112233');
      expect(receipt.customerId, 8);
      expect(receipt.transactionId, 987);

      final ticket = receipt.ticket;
      expect(ticket.kind, 'abono');
      expect(ticket.scope, 'transaction');
      expect(ticket.businessName, 'Refaccionaria Aponte');
      expect(ticket.folio, 'V-014');
      expect(ticket.totalLabel, r'$270.00 MXN');
      expect(ticket.previousDue, r'$200.00 MXN');
      expect(ticket.abonado, r'$200.00 MXN');
      expect(ticket.remainingDue, r'$0.00 MXN');
      expect(ticket.liquidated, isTrue);
      expect(ticket.isOrderPayment, isFalse);
      expect(ticket.paymentMethod, r'Efectivo: $200.00');
      expect(ticket.date, '18/09/2026 - 15:10');
    });

    test('el ticket del pedido usa total, estado y mensaje final', () {
      final result = AbonoResult.fromJson(<String, dynamic>{
        'transaction': detailFixture(),
        'print': <String, dynamic>{
          'type': 'order_payment',
          'payload': <String, dynamic>{
            'kind': 'order_payment',
            'businessName': 'Refaccionaria Aponte',
            'date': '18/09/2026 - 16:00',
            'folio': 'V-020',
            'estado': 'Pendiente',
            'customer': 'Mesa 4',
            'total': r'$500.00 MXN',
            'previousDue': r'$500.00 MXN',
            'abonado': r'$200.00 MXN',
            'paymentMethod': r'Efectivo: $200.00',
            'remainingDue': r'$300.00 MXN',
            'finalMessage': '¡Gracias por tu pedido!',
          },
          'transaction_id': 990,
          'customer_phone': null,
          'customer_id': null,
        },
      });

      final ticket = result.receipt!.ticket;

      expect(ticket.isOrderPayment, isTrue);
      expect(ticket.totalLabel, r'$500.00 MXN');
      expect(ticket.estado, 'Pendiente');
      expect(ticket.liquidated, isFalse);
      expect(ticket.finalMessage, '¡Gracias por tu pedido!');
      expect(result.receipt!.hasPhone, isFalse);
    });

    test('sin print no hay ticket', () {
      final result = AbonoResult.fromJson(<String, dynamic>{
        'transaction': detailFixture(),
      });

      expect(result.receipt, isNull);
    });
  });

  group('Resultados de anulación y edición', () {
    test('la cancelación devuelve la venta y el message del servidor', () {
      final result = TransactionMutationResult.fromJson(<String, dynamic>{
        'transaction': <String, dynamic>{
          ...detailFixture(),
          'status': 'cancelado',
        },
        'message': 'Venta cancelada correctamente.',
      });

      expect(result.transaction.status, 'cancelado');
      expect(result.transaction.canEditPayments, isFalse);
      expect(result.message, 'Venta cancelada correctamente.');
    });

    test('la edición de un pago devuelve pago y venta', () {
      final result = PaymentMutationResult.fromJson(<String, dynamic>{
        'message': 'Pago actualizado correctamente.',
        'payment': <String, dynamic>{
          'id': 3312,
          'amount': 120.0,
          'payment_method': 'tarjeta',
          'status': 'completado',
          'bank_account_id': 2,
          'notes': 'Voucher 9001',
          'payment_date': '2026-09-18T14:35:00.000000Z',
        },
        'transaction': detailFixture(),
      });

      expect(result.message, 'Pago actualizado correctamente.');
      expect(result.payment?.amount, 120.0);
      expect(result.payment?.paymentMethod, 'tarjeta');
      expect(result.transaction.folio, 'V-014');
    });
  });

  group('Errores del contrato', () {
    test('already_cancelled conserva el message y el code', () {
      final error = ApiException.fromResponse(422, <String, dynamic>{
        'code': 'already_cancelled',
        'message':
            'No se pueden agregar pagos a transacciones canceladas o reembolsadas.',
      });

      expect(error.code, 'already_cancelled');
      expect(error.statusCode, 422);
      expect(
        error.message,
        'No se pueden agregar pagos a transacciones canceladas o reembolsadas.',
      );
    });

    test('el abono excedido llega como message del servidor', () {
      final error = ApiException.fromResponse(422, <String, dynamic>{
        'message': 'El monto total del pago excede el saldo pendiente.',
      });

      expect(
        error.message,
        'El monto total del pago excede el saldo pendiente.',
      );
      expect(error.errorFor('payments'), isNull);
    });

    test('el 422 de validación expone los errores por campo', () {
      final error = ApiException.fromResponse(422, <String, dynamic>{
        'message': 'Los datos enviados no son válidos.',
        'errors': <String, dynamic>{
          'amount': <String>['El monto del pago debe ser mayor que cero.'],
          'bank_account_id': <String>[
            'Selecciona la cuenta destino para los pagos con tarjeta o transferencia.',
          ],
        },
      });

      expect(error.isValidation, isTrue);
      expect(error.hasFieldErrors, isTrue);
      expect(
        error.errorFor('amount'),
        'El monto del pago debe ser mayor que cero.',
      );
    });

    test('el 404 de otra sucursal y el 403 de permiso', () {
      final notFound = ApiException.fromResponse(404, <String, dynamic>{
        'message': 'Recurso no encontrado.',
      });
      final forbidden = ApiException.fromResponse(403, <String, dynamic>{
        'message': 'Tu usuario no tiene permiso para esta acción.',
      });

      expect(notFound.isNotFound, isTrue);
      expect(forbidden.isForbidden, isTrue);
      expect(forbidden.message, 'Tu usuario no tiene permiso para esta acción.');
    });
  });
}
