import 'package:ezyventas_app/features/cash/data/models/closed_cash_session.dart';
import 'package:ezyventas_app/features/printing/data/models/cash_cut_document.dart';

/// Fixtures compartidos por las pruebas de impresión (no es un archivo de
/// pruebas: no tiene `main()`).

/// Resumen real del turno (`GET /cash-register-sessions/{id}/summary`, §6.2).
Map<String, dynamic> summaryFixture() => <String, dynamic>{
  'session': <String, dynamic>{
    'id': 41,
    'status': 'abierta',
    'opened_at': '2026-09-18T13:00:00.000000Z',
    'cash_register': <String, dynamic>{'id': 3, 'name': 'Caja 1'},
    'opener': <String, dynamic>{'id': 4, 'name': 'Jos\u00E9 P\u00E9rez'},
    'users': <Map<String, dynamic>>[
      <String, dynamic>{'id': 7, 'name': 'Mar\u00EDa L\u00F3pez'},
    ],
    'opening_cash_balance': '1500.00',
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
    'counted_total': 5050.0,
    'difference': 0.0,
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
      'user': <String, dynamic>{'id': 7, 'name': 'Mar\u00EDa L\u00F3pez'},
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

/// Respuesta real del cierre (`PUT /cash-register-sessions/{id}`, §6.3).
Map<String, dynamic> closeResultFixture() => <String, dynamic>{
  'session': <String, dynamic>{
    'id': 41,
    'status': 'cerrada',
    'opened_at': '2026-09-18T13:00:00.000000Z',
    'closed_at': '2026-09-18T20:05:00.000000Z',
    'calculated_cash_total': 5050.0,
    'closing_cash_balance': 5040.0,
    'cash_difference': -10.0,
  },
  'summary': summaryFixture(),
  'message': 'Corte de caja realizado con éxito.',
};

/// Documento del corte listo para imprimir o enviar por WhatsApp.
CashCutDocument cashCutDocument() => CashCutDocument.fromCloseResult(
  result: CloseCashSessionResult.fromJson(closeResultFixture()),
  businessName: 'Refaccionaria López',
  branchName: 'León Centro',
);
