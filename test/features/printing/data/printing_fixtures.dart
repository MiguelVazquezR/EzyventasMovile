import 'package:ezyventas_app/features/printing/data/models/cash_cut_receipt.dart';

/// Fixtures compartidos por las pruebas de impresión (no es un archivo de
/// pruebas: no tiene `main()`).

/// Texto ESC/POS del **corte incorporado** del servidor.
///
/// Es exactamente lo que arma `CashRegisterCutTemplate` +
/// `PrintEncoderService::buildEscPosRawText`: `ESC @`, el detalle línea por
/// línea con `ESC a n`, el pie de marca y el corte de papel.
String cashCutRawText() => <String>[
  '\x1B@',
  '\x1Ba\x00CORTE DE CAJA\n',
  '\x1Ba\x00Caja: Caja 1\n',
  '\x1Ba\x00Folio: CORTE-41\n',
  '\x1Ba\x00Cajero: José Pérez\n',
  '\x1Ba\x00Apertura: 18/09/2026 13:00\n',
  '\x1Ba\x00Cierre: 18/09/2026 20:05\n',
  '\x1Ba\x00----------------\n',
  '\x1Ba\x00Fondo inicial: 1,500.00\n',
  '\x1Ba\x00Ventas efectivo: 3,500.00\n',
  '\x1Ba\x00Ingresos: 200.00\n',
  '\x1Ba\x00Retiros: 150.00\n',
  '\x1Ba\x00Esperado en caja: 5,050.00\n',
  '\x1Ba\x00Contado: 5,040.00\n',
  '\x1Ba\x00Diferencia: -10.00\n',
  '\x1Ba\x00----------------\n',
  '\x1Ba\x00Tarjeta: 1,200.00\n',
  '\x1Ba\x00Transferencia: 300.00\n',
  '\x1Ba\x00Saldo a favor: 0.00\n',
  '\x1Ba\x00Total ventas: 4,850.00\n',
  '\x1Ba\x00Ventas: 12  Pagos: 14\n',
  '\x1Ba\x00Notas: Faltante por un cambio mal dado.\n',
  '\x1Ba\x01\x1BE\x01\n** ezyventas.com **\n\x1BE\x00\x1Ba\x00\n\n\n',
  '\x1DV\x00\x00',
].join();

/// Resumen del turno (`GET /cash-register-sessions/{id}/summary`, §6.2) con las
/// cifras del cierre.
Map<String, dynamic> cutSummaryFixture() => <String, dynamic>{
  'session': <String, dynamic>{
    'id': 41,
    'status': 'cerrada',
    'opened_at': '2026-09-18T13:00:00.000000Z',
    'closed_at': '2026-09-18T20:05:00.000000Z',
    'cash_register': <String, dynamic>{'id': 3, 'name': 'Caja 1'},
    'opener': <String, dynamic>{'id': 4, 'name': 'José Pérez'},
    'users': <Map<String, dynamic>>[
      <String, dynamic>{'id': 7, 'name': 'María López'},
    ],
    'opening_cash_balance': '1500.00',
    'cash_difference': -10.0,
    'totals': <String, dynamic>{
      'cash': 3500,
      'card': 1200,
      'transfer': 300,
      'balance': 0,
    },
  },
  'cash': <String, dynamic>{
    'opening': 1500.0,
    'cash_sales': 3500.0,
    'inflows': 200.0,
    'outflows': 150.0,
    'expected_total': 5050.0,
    'counted_total': 5040.0,
    'difference': -10.0,
  },
  'payments_by_method': <String, dynamic>{
    'efectivo': 3500.0,
    'tarjeta': 1200.0,
    'transferencia': 300.0,
    'saldo': 0.0,
  },
  'cash_movements': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 88,
      'type': 'egreso',
      'amount': '150.00',
      'description': 'Compra de bolsas',
      'user': <String, dynamic>{'id': 7, 'name': 'María López'},
      'created_at': '2026-09-18T15:20:00.000000Z',
    },
  ],
  'bank_accounts': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 2,
      'account_name': 'Cuenta principal',
      'bank_name': 'BBVA',
      'initial_balance': 5000.0,
      'received': 1200.0,
      'spent': 0.0,
      'transferred_in': 0.0,
      'transferred_out': 300.0,
      'final_balance': 5900.0,
    },
  ],
  'counts': <String, dynamic>{'transactions': 12, 'payments': 14},
};

/// Respuesta real de `GET /cash-register-sessions/{id}/receipt` (§6.3) con la
/// plantilla **incorporada** del servidor (`template.builtin = true`,
/// `template.id = null`).
Map<String, dynamic> cashCutReceiptFixture() => <String, dynamic>{
  'session': <String, dynamic>{
    'id': 41,
    'status': 'cerrada',
    'opened_at': '2026-09-18T13:00:00.000000Z',
    'closed_at': '2026-09-18T20:05:00.000000Z',
    'cash_register': 'Caja 1',
  },
  'summary': cutSummaryFixture(),
  'template': <String, dynamic>{
    'id': null,
    'name': 'Corte de caja',
    'builtin': true,
  },
  'operations': <Map<String, dynamic>>[
    <String, dynamic>{
      'nombre': 'TextoSegunPaginaDeCodigos',
      'argumentos': <Object>[0, 'cp850', cashCutRawText()],
    },
  ],
  'unsupported_operations': <String>[],
  'warnings': <String>[],
  'paperWidth': '80mm',
  'feedLines': 3,
};

/// El mismo comprobante ya tipado.
CashCutReceipt cashCutReceipt() =>
    CashCutReceipt.fromJson(cashCutReceiptFixture());
