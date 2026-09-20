import 'package:ezyventas_app/features/service_orders/data/models/service_order_detail.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_form.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_item_draft.dart';
import 'package:flutter_test/flutter_test.dart';

/// Concepto de servicio tal como lo devuelve el detalle de una orden.
Map<String, dynamic> serviceItemFixture() => <String, dynamic>{
  'id': 902,
  'description': 'Cambio de pantalla',
  'itemable_type': r'App\Models\ServiceVariant',
  'itemable_id': 31,
  'quantity': 1.0,
  'unit_price': '1200.00',
  'line_total': '1200.00',
};

void main() {
  group('ServiceOrderItemDraft', () {
    test('calcula el total de la línea y clasifica el concepto', () {
      const part = ServiceOrderItemDraft(
        description: 'Mica templada',
        quantity: 2,
        unitPrice: 100,
        itemableType: ServiceOrderItemType.product,
        itemableId: 78,
      );
      const custom = ServiceOrderItemDraft(
        description: 'Revisión',
        quantity: 1,
        unitPrice: 150,
      );

      expect(part.lineTotal, 200);
      expect(part.isPart, isTrue);
      expect(part.isFromCatalog, isTrue);
      expect(part.typeLabel, 'Refacción');
      expect(custom.lineTotal, 150);
      expect(custom.isPart, isFalse);
      expect(custom.isFromCatalog, isFalse);
      expect(custom.typeLabel, 'Concepto libre');
    });

    test('precarga un concepto del detalle sin perder el itemable', () {
      final item = ServiceOrderItem.fromJson(serviceItemFixture());
      final draft = ServiceOrderItemDraft.fromItem(item);

      expect(draft.description, 'Cambio de pantalla');
      expect(draft.itemableType, r'App\Models\ServiceVariant');
      expect(draft.itemableId, 31);
      expect(draft.unitPrice, 1200);
      expect(draft.typeLabel, 'Mano de obra');
      expect(draft.isPart, isFalse);
    });

    test('en multipart cada clave lleva el índice de la línea', () {
      const draft = ServiceOrderItemDraft(
        description: 'Mica templada',
        quantity: 2,
        unitPrice: 100,
        itemableType: ServiceOrderItemType.product,
        itemableId: 78,
      );

      expect(draft.toMultipartFields(1), <String, dynamic>{
        'items[1][itemable_type]': r'App\Models\Product',
        'items[1][itemable_id]': 78,
        'items[1][description]': 'Mica templada',
        'items[1][quantity]': 2,
        'items[1][unit_price]': 100,
        'items[1][line_total]': 200,
      });
    });
  });

  group('ServiceOrderFormData', () {
    const items = <ServiceOrderItemDraft>[
      ServiceOrderItemDraft(
        description: 'Cambio de pantalla',
        quantity: 1,
        unitPrice: 1200,
        itemableType: ServiceOrderItemType.service,
        itemableId: 31,
      ),
      ServiceOrderItemDraft(
        description: 'Mica templada',
        quantity: 2,
        unitPrice: 100,
        itemableType: ServiceOrderItemType.product,
        itemableId: 78,
      ),
    ];

    test('calcula subtotal, descuento fijo y total', () {
      const form = ServiceOrderFormData(
        items: items,
        discountType: ServiceOrderDiscountType.fixed,
        discountValue: 150,
      );

      expect(form.subtotal, 1400);
      expect(form.discountAmount, 150);
      expect(form.finalTotal, 1250);
    });

    test('el descuento porcentual nunca deja el total en negativo', () {
      const form = ServiceOrderFormData(
        items: items,
        discountType: ServiceOrderDiscountType.percentage,
        discountValue: 20,
      );

      expect(form.discountAmount, 280);
      expect(form.finalTotal, 1120);

      const excessive = ServiceOrderFormData(
        items: items,
        discountType: ServiceOrderDiscountType.fixed,
        discountValue: 5000,
      );

      expect(excessive.discountAmount, 1400);
      expect(excessive.finalTotal, 0);
    });

    test('exige equipo, fallas y cliente para poder guardar', () {
      const incomplete = ServiceOrderFormData(itemDescription: 'iPhone 13');

      expect(incomplete.isComplete, isFalse);

      const complete = ServiceOrderFormData(
        itemDescription: 'iPhone 13',
        reportedProblems: 'No enciende',
        customerName: 'Ana Ramírez',
      );

      expect(complete.isComplete, isTrue);

      const withTechnician = ServiceOrderFormData(
        itemDescription: 'iPhone 13',
        reportedProblems: 'No enciende',
        customerName: 'Ana Ramírez',
        assignTechnician: true,
      );

      expect(withTechnician.isComplete, isFalse);
    });
  });

  group('ServiceOrderFormData.toFields', () {
    const form = ServiceOrderFormData(
      customerId: 8,
      customerName: 'Ana Ramírez',
      customerEmail: 'ana@correo.com',
      addressStreet: 'Av. Hidalgo 120',
      addressCity: 'León',
      itemDescription: 'iPhone 13, pantalla rota',
      reportedProblems: 'No enciende después de una caída',
      promisedAt: null,
      assignTechnician: true,
      technicianName: 'Luis Torres',
      commissionType: TechnicianCommissionType.percentage,
      commissionValue: 20,
      items: <ServiceOrderItemDraft>[
        ServiceOrderItemDraft(
          description: 'Cambio de pantalla',
          quantity: 1,
          unitPrice: 1200,
          itemableType: ServiceOrderItemType.service,
          itemableId: 31,
        ),
      ],
      discountType: ServiceOrderDiscountType.fixed,
      discountValue: 0,
      customFields: <String, dynamic>{'garantia': true},
    );

    test('en JSON los booleanos y el anidado viajan con su tipo real', () {
      final fields = form.toFields(
        isUpdate: false,
        multipart: false,
        sessionId: 41,
        clientUuid: '11111111-2222-3333-4444-555555555555',
      );

      expect(fields['customer_id'], 8);
      expect(fields['create_customer'], isFalse);
      expect(fields['assign_technician'], isTrue);
      expect(fields['cash_register_session_id'], 41);
      expect(fields['client_uuid'], '11111111-2222-3333-4444-555555555555');
      expect(fields['technician_commission_type'], 'percentage');
      expect(fields['technician_commission_value'], 20);
      expect(fields['subtotal'], 1200);
      expect(fields['discount_amount'], 0);
      expect(fields['final_total'], 1200);
      expect(fields['customer_address'], <String, dynamic>{
        'street': 'Av. Hidalgo 120',
        'city': 'León',
      });
      expect(fields['items'], <Map<String, dynamic>>[
        <String, dynamic>{
          'itemable_type': r'App\Models\Service',
          'itemable_id': 31,
          'description': 'Cambio de pantalla',
          'quantity': 1.0,
          'unit_price': 1200.0,
          'line_total': 1200,
        },
      ]);
      expect(fields['custom_fields'], <String, dynamic>{'garantia': true});
    });

    test('en multipart los booleanos van como 1/0 y las claves con corchetes', () {
      final fields = form.toFields(
        isUpdate: false,
        multipart: true,
        sessionId: 41,
      );

      // Laravel no acepta la cadena "true" en un campo multipart.
      expect(fields['assign_technician'], 1);
      expect(fields['create_customer'], 0);
      expect(fields['customer_address[street]'], 'Av. Hidalgo 120');
      expect(fields['items[0][quantity]'], 1);
      expect(fields['items[0][line_total]'], 1200);
      expect(fields['custom_fields[garantia]'], 1);
      expect(fields.containsKey('customer_address'), isFalse);
      expect(fields.containsKey('items'), isFalse);
      expect(fields.containsKey('custom_fields'), isFalse);
    });

    test('la edición envía diagnóstico y evidencias por borrar', () {
      final fields = form.toFields(isUpdate: true, multipart: false);

      expect(fields.containsKey('cash_register_session_id'), isFalse);

      const editing = ServiceOrderFormData(
        customerName: 'Ana Ramírez',
        itemDescription: 'iPhone 13',
        reportedProblems: 'No enciende',
        technicianDiagnosis: '',
        deletedMediaIds: <int>[551, 560],
      );

      final updateFields = editing.toFields(isUpdate: true, multipart: false);

      // Cadena vacía = borrar el diagnóstico anterior (contrato §9).
      expect(updateFields['technician_diagnosis'], '');
      expect(updateFields['deleted_media_ids'], <int>[551, 560]);
      expect(updateFields.containsKey('cash_register_session_id'), isFalse);
    });

    test('al crear la orden el id de sesión es obligatorio en el cuerpo', () {
      final fields = form.toFields(isUpdate: false, multipart: false);

      expect(fields.containsKey('cash_register_session_id'), isFalse);

      final withSession = form.toFields(
        isUpdate: false,
        multipart: false,
        sessionId: 41,
      );

      expect(withSession['cash_register_session_id'], 41);
    });

    test('dar de alta al cliente envía create_customer y credit_limit', () {
      const form = ServiceOrderFormData(
        customerName: 'Cliente nuevo',
        itemDescription: 'iPhone 13',
        reportedProblems: 'No enciende',
        createCustomer: true,
        creditLimit: 500,
      );

      final create = form.toFields(isUpdate: false, multipart: false);

      expect(create['create_customer'], isTrue);
      expect(create['credit_limit'], 500);

      // La edición no acepta `create_customer` ni `credit_limit`.
      final update = form.toFields(isUpdate: true, multipart: false);

      expect(update.containsKey('create_customer'), isFalse);
      expect(update.containsKey('credit_limit'), isFalse);
    });
  });
}
