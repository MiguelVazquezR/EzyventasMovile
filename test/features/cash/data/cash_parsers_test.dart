import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/features/cash/data/models/cash_register_snapshot.dart';
import 'package:ezyventas_app/features/cash/data/models/cash_session_summary.dart';
import 'package:ezyventas_app/features/cash/data/models/closed_cash_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Payload real de `GET /cash-register-sessions/current` (contrato §6).
Map<String, dynamic> currentSessionFixture() => <String, dynamic>{
  'active_session': <String, dynamic>{
    'id': 41,
    'status': 'abierta',
    'opened_at': '2026-09-18T13:00:00.000000Z',
    'opening_cash_balance': '1500.00',
    'opening_bank_balances': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 2,
        'account_name': 'Cuenta principal',
        'bank_name': 'BBVA',
        'balance': 5000.0,
      },
    ],
    'cash_register': <String, dynamic>{'id': 3, 'name': 'Caja 1'},
    'opener': <String, dynamic>{'id': 4, 'name': 'José Pérez'},
    'users': <Map<String, dynamic>>[
      <String, dynamic>{'id': 7, 'name': 'María López'},
      <String, dynamic>{'id': 9, 'name': 'Luis Torres'},
    ],
    'totals': <String, dynamic>{
      'cash': 1250.5,
      'card': 800,
      'transfer': 0,
      'balance': 100,
    },
  },
  'joinable_sessions': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 42,
      'cash_register': <String, dynamic>{'id': 4, 'name': 'Caja 2'},
      'opened_at': '2026-09-18T14:00:00.000000Z',
      'opener': <String, dynamic>{'id': 5, 'name': 'Luis'},
    },
  ],
  'available_cash_registers': <Map<String, dynamic>>[
    <String, dynamic>{'id': 5, 'name': 'Caja 3'},
  ],
  'bank_accounts': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 2,
      'name': 'Cuenta principal - BBVA (...4471)',
      'bank_name': 'BBVA',
      'account_name': 'Cuenta principal',
      'balance': '5000.00',
    },
  ],
};

/// Payload real de `GET /cash-register-sessions/{id}/summary` (contrato §6.2).
Map<String, dynamic> summaryFixture() => <String, dynamic>{
  'session': <String, dynamic>{
    'id': 41,
    'status': 'abierta',
    'opened_at': '2026-09-18T13:00:00.000000Z',
    'cash_register': <String, dynamic>{'id': 3, 'name': 'Caja 1'},
    'opener': <String, dynamic>{'id': 4, 'name': 'José Pérez'},
    'users': <Map<String, dynamic>>[
      <String, dynamic>{'id': 7, 'name': 'María López'},
    ],
    'opening_cash_balance': '1500.00',
    'closing_cash_balance': null,
    'calculated_cash_total': null,
    'cash_difference': null,
    'notes': null,
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
    'counted_total': null,
    'difference': null,
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

void main() {
  group('CashRegisterSnapshot', () {
    test('lee el turno, los turnos a los que unirse y las cuentas', () {
      final snapshot = CashRegisterSnapshot.fromJson(currentSessionFixture());

      expect(snapshot.hasActiveSession, isTrue);
      expect(snapshot.canStartShift, isTrue);
      expect(snapshot.canJoinShift, isTrue);
      expect(snapshot.isBlocked, isFalse);

      final session = snapshot.activeSession!;
      expect(session.id, 41);
      expect(session.isOpen, isTrue);
      expect(session.openingCashBalance, 1500.0);
      expect(session.cashRegisterName, 'Caja 1');
      expect(session.opener!.name, 'José Pérez');
      expect(session.hasMultipleUsers, isTrue);
      expect(session.totals.cash, 1250.5);
      expect(session.totals.total, 2150.5);

      // Snapshot bancario declarado al abrir: número en el contrato real.
      expect(session.openingBankBalances.single.balance, 5000.0);
      expect(
        session.openingBankBalances.single.label,
        'Cuenta principal · BBVA',
      );

      expect(snapshot.joinableSessions.single.cashRegister!.name, 'Caja 2');
      expect(snapshot.availableCashRegisters.single.name, 'Caja 3');
      expect(snapshot.bankAccounts.single.name, contains('BBVA'));
      expect(snapshot.bankAccounts.single.balance, 5000.0);
    });

    test('sin turno queda bloqueado cuando no hay terminales ni turnos', () {
      final snapshot = CashRegisterSnapshot.fromJson(<String, dynamic>{
        'active_session': null,
        'joinable_sessions': <Object>[],
        'available_cash_registers': <Object>[],
        'bank_accounts': <Object>[],
      });

      expect(snapshot.hasActiveSession, isFalse);
      expect(snapshot.canStartShift, isFalse);
      expect(snapshot.canJoinShift, isFalse);
      expect(snapshot.isBlocked, isTrue);
    });
  });

  group('CashSessionSummary', () {
    test('lee el corte con las fórmulas del servidor', () {
      final summary = CashSessionSummary.fromJson(summaryFixture());

      expect(summary.opening, 1500.0);
      expect(summary.cashSales, 3500.0);
      expect(summary.inflows, 200.0);
      expect(summary.outflows, 150.0);
      expect(summary.expectedTotal, 5050.0);
      expect(summary.countedTotal, isNull);
      expect(summary.isClosed, isFalse);

      expect(summary.payments.cash, 3500.0);
      expect(summary.payments.card, 1200.0);
      expect(summary.payments.transfer, 300.0);
      expect(summary.payments.total, 5000.0);

      final movement = summary.cashMovements.single;
      expect(movement.isInflow, isFalse);
      expect(movement.label, 'Egreso');
      expect(movement.amount, 150.0);

      expect(summary.bankAccounts.single.hasMovement, isTrue);
      expect(summary.bankAccounts.single.finalBalance, 5900.0);
      expect(summary.transactionsCount, 12);
      expect(summary.paymentsCount, 14);
    });

    test('calcula la diferencia en vivo del arqueo', () {
      final summary = CashSessionSummary.fromJson(summaryFixture());

      // Contado = esperado → sin diferencia (verde).
      expect(summary.differenceFor(5050), 0.0);
      // Faltante de 10 (negativo = falta dinero).
      expect(summary.differenceFor(5040), -10.0);
      // Sobrante de 5.50.
      expect(summary.differenceFor(5055.5), 5.5);
    });
  });

  group('CloseCashSessionResult', () {
    test('lee el corte cerrado y su resumen definitivo', () {
      final summary = summaryFixture();
      summary['session'] = <String, dynamic>{
        ...summary['session']! as Map<String, dynamic>,
        'status': 'cerrada',
        'closing_cash_balance': '5040.00',
        'calculated_cash_total': '5050.00',
        'cash_difference': '-10.00',
      };
      summary['cash'] = <String, dynamic>{
        'opening': 1500.0,
        'cash_sales': 3500.0,
        'inflows': 200.0,
        'outflows': 150.0,
        'expected_total': 5050.0,
        'counted_total': 5040.0,
        'difference': -10.0,
      };

      final result = CloseCashSessionResult.fromJson(<String, dynamic>{
        'session': <String, dynamic>{
          'id': 41,
          'status': 'cerrada',
          'closed_at': '2026-09-18T20:05:00.000000Z',
          'calculated_cash_total': 5050.0,
          'closing_cash_balance': 5040.0,
          'cash_difference': -10.0,
        },
        'summary': summary,
        'message': 'Corte de caja realizado con éxito.',
      });

      expect(result.session.status, 'cerrada');
      expect(result.session.closedAt, isNotNull);
      expect(result.session.calculatedCashTotal, 5050.0);
      expect(result.session.closingCashBalance, 5040.0);
      expect(result.session.hasDifference, isTrue);
      expect(result.summary.isClosed, isTrue);
      expect(result.summary.countedTotal, 5040.0);
      expect(result.summary.difference, -10.0);
      expect(result.message, 'Corte de caja realizado con éxito.');
    });
  });

  group('cash_register_in_use', () {
    test('conserva session_id y opened_by para ofrecer unirse', () {
      final error = ApiException.fromResponse(409, <String, dynamic>{
        'code': 'cash_register_in_use',
        'message':
            'Parece que otro usuario abrió caja antes que tú. Puedes unirte a la sesión.',
        'session_id': 42,
        'cash_register': <String, dynamic>{'id': 4, 'name': 'Caja 2'},
        'opened_by': <String, dynamic>{'id': 5, 'name': 'Luis Torres'},
      });

      expect(error.code, 'cash_register_in_use');
      expect(error.detailInt('session_id'), 42);
      expect(error.detailMap('cash_register')['name'], 'Caja 2');
      expect(error.detailMap('opened_by')['name'], 'Luis Torres');
    });

    test('session_required no trae datos extra y conserva el message', () {
      final error = ApiException.fromResponse(422, <String, dynamic>{
        'code': 'session_required',
        'message': 'Necesitas una sesión de caja abierta para registrar ventas.',
      });

      expect(error.detailInt('session_id'), isNull);
      expect(
        error.message,
        'Necesitas una sesión de caja abierta para registrar ventas.',
      );
    });
  });
}
