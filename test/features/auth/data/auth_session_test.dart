import 'package:ezyventas_app/features/auth/data/models/auth_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Respuesta real de `POST /api/v1/auth/login`
/// (contrato §2 + `UserAccessContextService`).
Map<String, dynamic> loginFixture() => <String, dynamic>{
  'token': '14|Yb3kExampleTokenValue',
  'token_type': 'Bearer',
  'user': <String, dynamic>{
    'id': 7,
    'name': 'María López',
    'email': 'maria@negocio.com',
    'phone': '4771234567',
    'profile_photo_url': 'https://ezyventas2.test/profile-photos/user7.jpg',
    'is_active': true,
    'email_verified_at': '2025-01-10T10:00:00.000000Z',
    'branch_id': 2,
    'branch': <String, dynamic>{
      'id': 2,
      'name': 'Sucursal Centro',
      'timezone': 'America/Mexico_City',
    },
    'subscription': <String, dynamic>{
      'id': 15,
      'commercial_name': 'Refaccionaria López',
      'status': 'activo',
      'expires_at': '2026-10-18T00:00:00.000000Z',
    },
    'is_subscription_owner': false,
    'permissions': <String>[
      'pos.access',
      'pos.create_sale',
      'transactions.access',
      'services.orders.access',
    ],
  },
  'module_keys': <String>['module_pos', 'module_services'],
  'modules': <String>['Punto de Venta', 'Órdenes de Servicio'],
  'available_branches': <Map<String, dynamic>>[
    <String, dynamic>{'id': 1, 'name': 'Sucursal Norte', 'is_current': false},
    <String, dynamic>{'id': 2, 'name': 'Sucursal Centro', 'is_current': true},
  ],
  'active_session': null,
  'joinable_sessions': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 41,
      'cash_register': <String, dynamic>{'id': 3, 'name': 'Caja 1'},
      'opened_at': '2026-09-18T13:00:00.000000Z',
      'opener': <String, dynamic>{'id': 4, 'name': 'José Pérez'},
    },
  ],
  'available_cash_registers': <Map<String, dynamic>>[
    <String, dynamic>{'id': 5, 'name': 'Caja 2'},
  ],
};

void main() {
  group('AuthSession.fromJson', () {
    test('lee token, usuario, permisos, módulos y sucursales', () {
      final session = AuthSession.fromJson(loginFixture());
      final context = session.context;

      expect(session.isUsable, isTrue);
      expect(session.token, startsWith('14|'));
      expect(context.user.id, 7);
      expect(context.user.name, 'María López');
      expect(context.user.phone, '4771234567');
      expect(context.user.isActive, isTrue);
      expect(context.user.branch?.name, 'Sucursal Centro');
      expect(context.user.branch?.timezone, 'America/Mexico_City');
      expect(context.user.subscription?.commercialName, 'Refaccionaria López');
      expect(context.user.subscription?.status, 'activo');
      expect(context.user.isSubscriptionOwner, isFalse);
      expect(context.user.hasPhoto, isTrue);
      expect(context.user.isEmailVerified, isTrue);
      expect(context.user.permissions, contains('pos.create_sale'));
      expect(context.moduleKeys, <String>['module_pos', 'module_services']);
      expect(context.modules, hasLength(2));
    });

    test('available_branches incluye la sucursal activa', () {
      final context = AuthSession.fromJson(loginFixture()).context;

      expect(context.availableBranches, hasLength(2));
      expect(context.currentBranch?.id, 2);
      expect(context.currentBranch?.label, 'Sucursal Centro');
      expect(context.hasSingleBranch, isFalse);
      expect(context.businessName, 'Refaccionaria López');
    });

    test('sin sesión de caja activa pero con sesiones para unirse', () {
      final context = AuthSession.fromJson(loginFixture()).context;

      expect(context.activeSession, isNull);
      expect(context.hasActiveSession, isFalse);
      expect(context.joinableSessions, hasLength(1));
      expect(context.joinableSessions.first.id, 41);
      expect(context.joinableSessions.first.opener?.name, 'José Pérez');
      expect(context.availableCashRegisters.single.name, 'Caja 2');
    });

    test('acepta payloads parciales sin romperse', () {
      final session = AuthSession.fromJson(<String, dynamic>{
        'token': '1|abc',
        'user': <String, dynamic>{'id': 1, 'name': 'Soporte'},
      });

      expect(session.token, '1|abc');
      expect(session.context.user.name, 'Soporte');
      expect(session.context.user.email, '');
      expect(session.context.moduleKeys, isEmpty);
      expect(session.context.availableBranches, isEmpty);
      expect(session.context.hasSingleBranch, isTrue);
      expect(session.context.user.hasPhoto, isFalse);
      expect(session.context.user.isEmailVerified, isFalse);
    });
  });

  group('AuthSession.toJson (persistencia en el almacenamiento seguro)', () {
    test('el round trip conserva token, permisos y sucursal activa', () {
      final original = AuthSession.fromJson(loginFixture());
      final restored = AuthSession.fromJson(original.toJson());

      expect(restored.token, original.token);
      expect(restored.context.user.id, original.context.user.id);
      expect(
        restored.context.user.permissions,
        original.context.user.permissions,
      );
      expect(restored.context.moduleKeys, original.context.moduleKeys);
      expect(restored.context.currentBranch?.id, 2);
      expect(restored.context.joinableSessions, hasLength(1));
      expect(restored.context.availableCashRegisters.single.id, 5);
      expect(restored.context.user.emailVerifiedAt, isNotNull);
    });

    test('una sesión sin token no es utilizable', () {
      final session = AuthSession.fromJson(<String, dynamic>{
        'user': <String, dynamic>{'id': 3},
      });

      expect(session.isUsable, isFalse);
    });
  });

  group('ActiveCashSession (montos como texto o número)', () {
    test('normaliza opening_cash_balance y totals a double', () {
      final payload = <String, dynamic>{
        'token': '9|xyz',
        'user': <String, dynamic>{'id': 4, 'name': 'José Pérez'},
        'active_session': <String, dynamic>{
          'id': 41,
          'status': 'abierta',
          'opened_at': '2026-09-18T13:00:00.000000Z',
          'opening_cash_balance': '500.00',
          'cash_register': <String, dynamic>{'id': 3, 'name': 'Caja 1'},
          'opener': <String, dynamic>{'id': 4, 'name': 'José Pérez'},
          'users': <Map<String, dynamic>>[
            <String, dynamic>{'id': 4, 'name': 'José Pérez'},
            <String, dynamic>{'id': 9, 'name': 'Ana Ruiz'},
          ],
          'totals': <String, dynamic>{
            'cash': 120.5,
            'card': '80.00',
            'transfer': 0,
            'balance': 0,
          },
        },
      };

      final session = AuthSession.fromJson(payload).context.activeSession!;

      expect(session.isOpen, isTrue);
      expect(session.openingCashBalance, 500.0);
      expect(session.cashRegisterName, 'Caja 1');
      expect(session.opener?.name, 'José Pérez');
      expect(session.totals.cash, 120.5);
      expect(session.totals.card, 80.0);
      expect(session.totals.total, 200.5);
      expect(session.hasMultipleUsers, isTrue);
      expect(session.openedAt, isNotNull);
    });
  });
}
