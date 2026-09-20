import 'package:ezyventas_app/features/service_orders/data/models/service_order_detail.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_filters.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_mutation_results.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_status.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Orden del listado tal como la devuelve `GET /service-orders` (contrato §9):
/// `subtotal`, `discount_amount` y `final_total` en texto decimal;
/// `total_paid` y `amount_due` numéricos.
Map<String, dynamic> listItemFixture() => <String, dynamic>{
  'id': 314,
  'folio': 'OS-014',
  'customer_name': 'Ana Ramírez',
  'customer_phone': '4771112233',
  'item_description': 'iPhone 13, pantalla rota',
  'status': 'en_progreso',
  'technician_name': 'Luis Torres',
  'received_at': '2026-09-15T16:00:00.000000Z',
  'promised_at': '2026-09-20T18:00:00.000000Z',
  'subtotal': '1450.00',
  'discount_amount': '50.00',
  'final_total': '1400.00',
  'total_paid': 700.0,
  'amount_due': 700.0,
  'has_transaction': true,
  'created_at': '2026-09-15T16:00:00.000000Z',
};

/// Detalle completo (`GET /service-orders/{id}`): dos ítems (una refacción de
/// stock y una línea de servicio), evidencias, venta vinculada y actividades.
Map<String, dynamic> detailFixture() => <String, dynamic>{
  ...listItemFixture(),
  'customer': <String, dynamic>{
    'id': 8,
    'name': 'Ana Ramírez',
    'phone': '4771112233',
    'email': 'ana@correo.com',
    'balance': '-350.00',
  },
  'customer_email': 'ana@correo.com',
  'customer_address': <String, dynamic>{
    'street': 'Av. Hidalgo 120',
    'city': 'León',
  },
  'reported_problems': 'No enciende después de una caída',
  'technician_diagnosis': 'Display dañado y batería al 62 %',
  'technician_commission_type': 'percentage',
  'technician_commission_value': '20.00',
  'discount_type': 'fixed',
  'discount_value': '50.00',
  'custom_fields': <String, dynamic>{'pin_desbloqueo': '1234'},
  'custom_field_definitions': <Map<String, dynamic>>[
    <String, dynamic>{
      'key': 'pin_desbloqueo',
      'name': 'PIN de desbloqueo',
      'type': 'text',
      'options': null,
      'is_required': false,
    },
    <String, dynamic>{
      'key': 'garantia',
      'name': 'Con garantía',
      'type': 'switch',
      'options': null,
      'is_required': false,
    },
  ],
  'items': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 902,
      'description': 'Cambio de pantalla (original)',
      'itemable_type': r'App\Models\ServiceVariant',
      'itemable_id': 31,
      'quantity': 1.0,
      'unit_price': '1200.00',
      'line_total': '1200.00',
    },
    <String, dynamic>{
      'id': 903,
      'description': 'Mica templada',
      'itemable_type': r'App\Models\Product',
      'itemable_id': 78,
      'quantity': 2.0,
      'unit_price': '100.00',
      'line_total': '200.00',
    },
  ],
  'media': <String, dynamic>{
    'initial_service_order_evidence': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 551,
        'file_name': 'equipo-1.jpg',
        'original_url': 'https://cdn.test/equipo-1.jpg',
        'thumb_url': null,
        'size': 245000,
      },
    ],
    'closing_service_order_evidence': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 560,
        'file_name': 'cierre-1.jpg',
        'original_url': 'https://cdn.test/cierre-1.jpg',
        'thumb_url': 'https://cdn.test/cierre-1-368.jpg',
        'size': 1500000,
      },
    ],
  },
  'transaction': <String, dynamic>{
    'id': 1201,
    'folio': 'OS-V-006',
    'status': 'pendiente',
    'total': 1400.0,
    'total_paid': 700.0,
    'remaining_due': 700.0,
    'payments': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 5520,
        'amount': '700.00',
        'payment_method': 'efectivo',
        'payment_date': '2026-09-15T16:10:00.000000Z',
        'bank_account': null,
      },
    ],
  },
  'activities': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 9,
      'description': 'La orden de servicio ha sido actualizada',
      'event': 'updated',
      'causer': <String, dynamic>{'id': 7, 'name': 'María López'},
      'created_at': '2026-09-16T10:00:00.000000Z',
    },
  ],
};

void main() {
  group('ServiceOrderSummary', () {
    test('lee el dinero en texto decimal y el saldo numérico', () {
      final order = ServiceOrderSummary.fromJson(listItemFixture());

      expect(order.id, 314);
      expect(order.folio, 'OS-014');
      expect(order.subtotal, 1450);
      expect(order.discountAmount, 50);
      expect(order.finalTotal, 1400);
      expect(order.totalPaid, 700);
      expect(order.amountDue, 700);
      expect(order.hasTransaction, isTrue);
      expect(order.statusLabel, 'En progreso');
      expect(order.isCancelled, isFalse);
      expect(order.canReceivePayment, isTrue);
    });

    test('una orden cancelada ya no admite cobros', () {
      final order = ServiceOrderSummary.fromJson(<String, dynamic>{
        ...listItemFixture(),
        'status': 'cancelado',
      });

      expect(order.isCancelled, isTrue);
      expect(order.hasPendingAmount, isFalse);
      expect(order.canReceivePayment, isFalse);
    });

    test('sin venta vinculada el cobro exige ensure-transaction', () {
      final order = ServiceOrderSummary.fromJson(<String, dynamic>{
        ...listItemFixture(),
        'has_transaction': false,
      });

      expect(order.hasTransaction, isFalse);
      expect(order.canReceivePayment, isFalse);
      expect(order.amountDue, 700);
    });

    test('ordena y filtra con los parámetros exactos del contrato', () {
      const filters = ServiceOrderFilters(
        search: 'OS-014',
        status: 'pendiente',
        sort: ServiceOrderSort.promised,
      );

      expect(filters.toQuery(), <String, dynamic>{
        'search': 'OS-014',
        'status': 'pendiente',
        'sortField': 'promised_at',
        'sortOrder': 'asc',
      });
      expect(filters.hasFilters, isTrue);
      expect(
        filters.copyWith(clearStatus: true).toQuery()['status'],
        isNull,
      );
    });
  });

  group('ServiceOrderDetail', () {
    test('parsea cliente, conceptos, evidencias, venta e historial', () {
      final detail = ServiceOrderDetail.fromJson(detailFixture());

      expect(detail.customer?.name, 'Ana Ramírez');
      expect(detail.customer?.hasDebt, isTrue);
      expect(detail.customerAddress?.label, 'Av. Hidalgo 120, León');
      expect(detail.items.length, 2);
      expect(detail.items.first.isService, isTrue);
      expect(detail.items.last.isPart, isTrue);
      expect(detail.initialEvidence.single.sizeLabel, '239 KB');
      // `thumb_url` nulo cae a la original; cuando existe se usa la miniatura.
      expect(
        detail.initialEvidence.single.thumbUrl,
        'https://cdn.test/equipo-1.jpg',
      );
      expect(
        detail.closingEvidence.single.thumbUrl,
        'https://cdn.test/cierre-1-368.jpg',
      );
      expect(detail.closingEvidence.single.sizeLabel, '1.4 MB');
      expect(detail.transaction?.folio, 'OS-V-006');
      expect(detail.transaction?.payments.single.amount, 700);
      expect(detail.activities.single.causerName, 'María López');
      expect(detail.customFieldDefinitions.first.isSwitch, isFalse);
      expect(detail.customFieldDefinitions.last.isSwitch, isTrue);
      expect(detail.allEvidence.length, 2);
    });

    test('calcula refacciones, comisión del técnico y utilidad', () {
      final detail = ServiceOrderDetail.fromJson(detailFixture());

      // Solo el ítem `App\Models\Product` cuenta como refacción (2 × 100).
      expect(detail.partsCost, 200);
      // (1400 − 200) × 20 %.
      expect(detail.technicianCommission, 240);
      expect(detail.netProfit, 960);
    });

    test('la comisión fija se toma tal cual del contrato', () {
      final detail = ServiceOrderDetail.fromJson(<String, dynamic>{
        ...detailFixture(),
        'technician_commission_type': 'fixed',
        'technician_commission_value': '150.00',
      });

      expect(detail.commissionIsPercentage, isFalse);
      expect(detail.technicianCommission, 150);
      expect(detail.netProfit, 1050);
    });

    test('sin venta vinculada el saldo es el del resumen', () {
      final detail = ServiceOrderDetail.fromJson(<String, dynamic>{
        ...detailFixture(),
        'transaction': null,
        'has_transaction': false,
      });

      expect(detail.hasTransaction, isFalse);
      expect(detail.transaction, isNull);
      expect(detail.pendingAmount, 700);
      expect(detail.canReceivePayment, isTrue);
    });
  });

  group('ServiceOrderStatus', () {
    test('el flujo excluye el estatus cancelado', () {
      expect(ServiceOrderStatus.flow.length, 5);
      expect(ServiceOrderStatus.pending.flowIndex, 0);
      expect(ServiceOrderStatus.delivered.flowIndex, 4);
      expect(ServiceOrderStatus.cancelled.flowIndex, -1);
      expect(ServiceOrderStatus.cancelled.stepsAhead, isEmpty);
    });

    test('ofrece los pasos siguientes y los anteriores', () {
      expect(
        ServiceOrderStatus.inProgress.nextStep,
        ServiceOrderStatus.waitingParts,
      );
      expect(
        ServiceOrderStatus.finished.stepsAhead.single,
        ServiceOrderStatus.delivered,
      );
      expect(
        ServiceOrderStatus.finished.stepsBehind.first,
        ServiceOrderStatus.waitingParts,
      );
      expect(ServiceOrderStatus.delivered.stepsAhead, isEmpty);
    });

    test('nunca inventa un estatus desconocido', () {
      expect(ServiceOrderStatus.fromValue('desconocido'), isNull);
      expect(
        ServiceOrderStatus.fromValue('esperando_refaccion'),
        ServiceOrderStatus.waitingParts,
      );
    });
  });

  group('ServiceOrderMutationResult', () {
    test('lee el detalle y el message del servidor', () {
      final result = ServiceOrderMutationResult.fromJson(<String, dynamic>{
        'message': 'Orden de servicio creada.',
        'service_order': detailFixture(),
      });

      expect(result.message, 'Orden de servicio creada.');
      expect(result.detail.folio, 'OS-014');
    });

    test('el cambio de estatus solo trae el resumen', () {
      final result = ServiceOrderStatusResult.fromJson(<String, dynamic>{
        'message': 'Estatus actualizado a “Terminado”.',
        'service_order': <String, dynamic>{
          ...listItemFixture(),
          'status': 'terminado',
        },
      });

      expect(result.message, 'Estatus actualizado a “Terminado”.');
      expect(result.summary.status, 'terminado');
    });

    test('el anticipo trae orden, venta y ticket de abono', () {
      final result = ServiceOrderPaymentResult.fromJson(<String, dynamic>{
        'service_order': detailFixture(),
        'transaction': <String, dynamic>{'id': 1201, 'folio': 'OS-V-006'},
        'print': <String, dynamic>{
          'type': 'abono',
          'payload': <String, dynamic>{
            'kind': 'abono',
            'customer': 'Ana Ramírez',
            'folio': 'OS-V-006',
            'abonado': r'$700.00 MXN',
            'remainingDue': r'$0.00 MXN',
            'liquidated': true,
          },
          'transaction_id': 1201,
          'customer_phone': '4771112233',
        },
      });

      expect(result.detail.pendingAmount, 700);
      expect(result.transaction.folio, 'OS-V-006');
      expect(result.receipt?.hasPhone, isTrue);
      expect(result.receipt?.ticket.liquidated, isTrue);
    });
  });
}
