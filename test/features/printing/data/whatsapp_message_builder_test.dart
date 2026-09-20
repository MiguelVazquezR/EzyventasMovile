import 'package:ezyventas_app/features/printing/data/whatsapp_message_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'printing_fixtures.dart';

/// Ticket de venta de contado (`WhatsAppTicketService::buildSalePayload`).
Map<String, dynamic> saleTicket() => <String, dynamic>{
  'kind': 'sale',
  'title': 'TICKET DE VENTA',
  'businessName': 'Refaccionaria López',
  'saleType': 'contado',
  'saleTypeLabel': 'Contado',
  'date': '18/09/2026 - 14:35',
  'folio': 'V-014',
  'customer': 'Ana Ramírez',
  'items': <Map<String, dynamic>>[
    <String, dynamic>{
      'cantidad': 2,
      'descripcion': 'Filtro de aceite',
      'total': '\$240.00',
    },
  ],
  'total': '\$270.00 MXN',
  'totalPaid': '\$270.00 MXN',
  'remainingDue': null,
  'expirationDate': null,
  'paymentMethod': 'Efectivo (Pagado: \$300.00 | Cambio: \$30.00)',
  'address': '',
  'finalMessage': '¡Gracias por tu compra!',
};

void main() {
  // `AppFormatters` usa `intl` es-MX; en la app lo inicializa
  // `flutter_localizations`.
  setUpAll(() => initializeDateFormatting('es_MX'));

  group('WhatsAppMessageBuilder · venta', () {
    test('arma el ticket de contado como la web', () {
      final message = WhatsAppMessageBuilder.build(saleTicket());

      expect(message, startsWith('» *TICKET DE VENTA* «'));
      expect(message, contains('• *Refaccionaria López*'));
      expect(message, contains('• Tipo de venta: *Contado*'));
      expect(message, contains('• Fecha: *18/09/2026 - 14:35*'));
      expect(message, contains('• Folio: *V-014*'));
      expect(message, contains('• Cliente: *Ana Ramírez*'));
      expect(message, contains('» *Detalle de compra* «'));
      expect(message, contains('Cant Producto'));
      expect(message, contains('2    Filtro de aceite'));
      expect(message, contains('• Total de venta: *\$270.00 MXN*'));
      expect(message, contains('• Pagado: *\$270.00 MXN*'));
      expect(message, contains('• Método de pago: *Efectivo'));
      expect(message, isNot(contains('Restante a pagar')));
      expect(message, endsWith('» ¡Gracias por tu compra! «'));
    });

    test('en crédito o apartado el pago se rotula como abono', () {
      final ticket = saleTicket()
        ..['saleType'] = 'apartado'
        ..['saleTypeLabel'] = 'Apartado'
        ..['totalPaid'] = '\$50.00 MXN'
        ..['remainingDue'] = '\$220.00 MXN'
        ..['expirationDate'] = '30/09/2026';

      final message = WhatsAppMessageBuilder.build(ticket);

      expect(message, contains('• Abono: *\$50.00 MXN*'));
      expect(message, contains('• Restante a pagar: *\$220.00 MXN*'));
      expect(message, contains('• Vencimiento: *30/09/2026*'));
      expect(
        message,
        endsWith(
          '» ¡Gracias por tu compra! Recuerda liquidar tu saldo antes del '
          '30/09/2026. «',
        ),
      );
    });

    test('sin vencimiento recuerda el saldo pendiente', () {
      final ticket = saleTicket()
        ..['saleType'] = 'credito'
        ..['totalPaid'] = null
        ..['remainingDue'] = '\$270.00 MXN';

      expect(
        WhatsAppMessageBuilder.build(ticket),
        contains('Queda un saldo pendiente de \$270.00 MXN.'),
      );
    });
  });

  group('WhatsAppMessageBuilder · pedido', () {
    test('incluye el estado y el envío del pedido', () {
      final message = WhatsAppMessageBuilder.build(<String, dynamic>{
        'kind': 'order',
        'businessName': 'Refaccionaria López',
        'date': '19/09/2026 - 10:12',
        'folio': 'V-020',
        'statusLabel': 'Por entregar',
        'customer': 'Juan Pérez',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'cantidad': 1,
            'descripcion': 'Bujía de encendido',
            'total': '\$120.00',
          },
        ],
        'subtotal': '\$120.00 MXN',
        'shippingCost': '\$80.00 MXN',
        'total': '\$200.00 MXN',
        'totalPaid': null,
        'paymentMethod': null,
        'remainingDue': null,
        'finalMessage': '¡Gracias por tu pedido!',
      });

      expect(message, startsWith('» *TICKET DE PEDIDO* «'));
      expect(message, contains('• Estado del pedido: *Por entregar*'));
      expect(message, contains('• Subtotal: *\$120.00 MXN*'));
      expect(message, contains('• Envío: *\$80.00 MXN*'));
      expect(message, contains('• Total del pedido: *\$200.00 MXN*'));
      expect(message, isNot(contains('Método de pago')));
      expect(message, endsWith('» ¡Gracias por tu pedido! «'));
    });

    test('un pedido con pagos muestra el monto y el restante', () {
      final message = WhatsAppMessageBuilder.build(<String, dynamic>{
        'kind': 'order',
        'businessName': 'Refaccionaria López',
        'statusLabel': 'Pagado',
        'items': <Map<String, dynamic>>[],
        'totalPaid': '\$200.00 MXN',
        'paymentMethod': 'Efectivo: \$200.00',
        'remainingDue': '\$0.00 MXN',
      });

      expect(message, contains('• Monto pagado: *\$200.00 MXN*'));
      expect(message, contains('• Método de pago: *Efectivo: \$200.00*'));
      expect(message, contains('• Restante a pagar: *\$0.00 MXN*'));
    });
  });

  group('WhatsAppMessageBuilder · abono', () {
    test('abono a una venta particular', () {
      final message = WhatsAppMessageBuilder.build(<String, dynamic>{
        'kind': 'abono',
        'scope': 'transaction',
        'businessName': 'Refaccionaria López',
        'date': '20/09/2026 - 12:00',
        'customer': 'Ana Ramírez',
        'folio': 'V-014',
        'saleTotal': '\$270.00 MXN',
        'previousDue': '\$220.00 MXN',
        'abonado': '\$50.00 MXN',
        'remainingDue': '\$170.00 MXN',
        'liquidated': false,
        'expirationDate': '30/09/2026',
        'paymentMethod': 'Efectivo: \$50.00',
      });

      expect(message, startsWith('» *TICKET DE ABONO* «'));
      expect(message, contains('• Tipo de venta: *Abono*'));
      expect(message, contains('• Folio de venta: *V-014*'));
      expect(message, contains('• Total de la venta: *\$270.00 MXN*'));
      expect(message, contains('• Monto anterior: *\$220.00 MXN*'));
      expect(message, contains('• Abonado: *\$50.00 MXN*'));
      expect(message, contains('• Restante a pagar: *\$170.00 MXN*'));
      expect(message, contains('• Método de pago: *Efectivo: \$50.00*'));
      expect(message, contains('• Vencimiento: *30/09/2026*'));
      expect(message, endsWith('» ¡Gracias por tu abono! «'));
    });

    test('un abono que liquida cambia la leyenda y oculta el vencimiento', () {
      final message = WhatsAppMessageBuilder.build(<String, dynamic>{
        'kind': 'abono',
        'businessName': 'Refaccionaria López',
        'customer': 'Ana Ramírez',
        'folio': 'V-014',
        'abonado': '\$170.00 MXN',
        'remainingDue': '\$0.00 MXN',
        'liquidated': true,
        'expirationDate': '30/09/2026',
        'paymentMethod': 'Efectivo: \$170.00',
      });

      expect(message, isNot(contains('Vencimiento')));
      expect(
        message,
        endsWith('» ¡Gracias por tu abono! Tu compra quedó liquidada. «'),
      );
    });

    test('abono general a la cuenta del cliente con su desglose', () {
      final message = WhatsAppMessageBuilder.build(<String, dynamic>{
        'kind': 'abono',
        'scope': 'general',
        'businessName': 'Refaccionaria López',
        'date': '20/09/2026 - 12:30',
        'customer': 'Ana Ramírez',
        'totalAbonado': '\$50.00 MXN',
        'paymentMethod': 'Efectivo: \$50.00',
        'breakdown': <Map<String, dynamic>>[
          <String, dynamic>{
            'folio': 'V-00492',
            'abonado': '\$20.00',
            'restante': '\$0.00',
            'liquidada': true,
          },
          <String, dynamic>{
            'folio': 'V-00495',
            'abonado': '\$30.00',
            'restante': '\$15.00',
            'liquidada': false,
          },
        ],
        'liquidatedFolios': <String>['V-00492'],
        'totalRemaining': '\$15.00 MXN',
        'nextExpiration': '30/09/2026',
      });

      expect(message, contains('• Total abonado: *\$50.00 MXN*'));
      expect(message, contains('» *Aplicado a ventas* «'));
      expect(message, contains('Venta'));
      expect(message, contains('V-00492'));
      expect(message, contains('• Ventas liquidadas: *V-00492*'));
      expect(message, contains('• Restante total: *\$15.00 MXN*'));
      expect(message, contains('• Próximo vencimiento: *30/09/2026*'));
    });
  });


  group('WhatsAppMessageBuilder · pago de pedido', () {
    test('arma el ticket de pago del pedido', () {
      final message = WhatsAppMessageBuilder.build(<String, dynamic>{
        'kind': 'order_payment',
        'businessName': 'Refaccionaria López',
        'date': '20/09/2026 - 18:00',
        'folio': 'V-020',
        'estado': 'Completado',
        'customer': 'Juan Pérez',
        'total': '\$200.00 MXN',
        'previousDue': '\$120.00 MXN',
        'abonado': '\$120.00 MXN',
        'paymentMethod': 'Efectivo: \$120.00',
        'remainingDue': '\$0.00 MXN',
        'finalMessage': '¡Gracias por tu pedido! Ya ha sido completado.',
      });

      expect(message, startsWith('» *TICKET DE PEDIDO* «'));
      expect(message, contains('• Estado del pedido: *Completado*'));
      expect(message, contains('• Total de la venta: *\$200.00 MXN*'));
      expect(message, contains('• Monto anterior: *\$120.00 MXN*'));
      expect(message, contains('• Abonado: *\$120.00 MXN*'));
      expect(message, contains('• Restante a pagar: *\$0.00 MXN*'));
      expect(message, contains('Ya ha sido completado.'));
    });
  });

  group('WhatsAppMessageBuilder · corte de caja', () {
    test('arma el corte con los montos que calculó el servidor', () {
      final message = WhatsAppMessageBuilder.cashCut(cashCutDocument());

      expect(message, startsWith('» *CORTE DE CAJA* «'));
      expect(message, contains('• *Refaccionaria López*'));
      expect(message, contains('• Sucursal: *León Centro*'));
      expect(message, contains('• Terminal: *Caja 1*'));
      expect(message, contains('• Fondo inicial: *\$1,500.00*'));
      expect(message, contains('• Ventas en efectivo: *\$3,500.00*'));
      expect(message, contains('• Total esperado: *\$5,050.00*'));
      expect(message, contains('• Efectivo contado: *\$5,040.00*'));
      expect(message, contains('• Diferencia: *-\$10.00*'));
      expect(message, contains('» *Cobros por método* «'));
      expect(message, contains('Efectivo'));
      expect(message, contains('Tarjeta'));
      expect(message, endsWith('» Revisa el descuadre del turno. «'));
    });
  });

  group('WhatsAppMessageBuilder · enlace', () {
    test('agrega el prefijo de México a un teléfono de 10 dígitos', () {
      final link = WhatsAppMessageBuilder.link(
        phone: '477 111 2233',
        message: 'Hola',
      );

      expect(link, 'https://wa.me/524771112233?text=Hola');
    });

    test('respeta los teléfonos que ya traen lada del país', () {
      expect(
        WhatsAppMessageBuilder.link(phone: '524771112233', message: 'Hola'),
        'https://wa.me/524771112233?text=Hola',
      );
    });

    test('sin teléfono abre WhatsApp para elegir el contacto', () {
      expect(
        WhatsAppMessageBuilder.link(phone: null, message: 'Hola'),
        'https://wa.me/?text=Hola',
      );
    });

    test('codifica los saltos de línea del mensaje', () {
      final link = WhatsAppMessageBuilder.link(
        phone: '4771112233',
        message: 'Linea 1\nLinea 2',
      );

      expect(link, endsWith('text=Linea%201%0ALinea%202'));
    });
  });
}

