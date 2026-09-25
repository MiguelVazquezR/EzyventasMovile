import 'package:ezyventas_app/features/account/data/models/branch_switch_result.dart';
import 'package:ezyventas_app/features/account/data/models/notification_counters.dart';
import 'package:ezyventas_app/features/account/data/models/subscription_overview.dart';
import 'package:ezyventas_app/features/account/data/models/support_content.dart';
import 'package:ezyventas_app/features/account/data/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Payload real de `GET /notifications` (contrato §11b.2; `modules` desde el
/// 2026-09-20).
Map<String, dynamic> notificationsFixture() => <String, dynamic>{
  'expiring_debts': 3,
  'upcoming_deliveries': 2,
  'unread_updates': 5,
  'pending_orders': 1,
  'total': 11,
  'modules': <String, dynamic>{'online_store': true},
};

/// Payload real de `GET /support` (contrato §11b.3, capturado del servidor).
Map<String, dynamic> supportFixture() => <String, dynamic>{
  'title': 'Centro de soporte',
  'subtitle': 'Estamos aquí para ayudarte',
  'message':
      'Puedes solicitar soporte técnico, reportar algún error, sugerir mejoras '
      'al sistema o proponer nuevas funcionalidades. Con gusto lo evaluaremos.',
  'schedule': <Map<String, dynamic>>[
    <String, dynamic>{'label': 'Lunes a viernes', 'hours': '8:00 AM — 7:00 PM'},
    <String, dynamic>{'label': 'Sábados', 'hours': '9:00 AM — 3:00 PM'},
  ],
  'channels': <Map<String, dynamic>>[
    <String, dynamic>{
      'type': 'email',
      'label': 'Correo electrónico',
      'value': 'notificaciones@ezyventas.com',
      'url': 'mailto:notificaciones@ezyventas.com',
    },
    <String, dynamic>{
      'type': 'whatsapp',
      'label': 'WhatsApp',
      'value': '+52 33 2170 5650',
      'url': 'https://wa.me/5213321705650',
    },
  ],
  'help_topics': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'steps',
      'title': 'Primeros pasos',
      'description': 'Configura tu cuenta y realiza tu primera venta.',
    },
  ],
  'help_center_url': 'https://ezyventas2.test/centro-ayuda',
};

/// Payload real de `GET /profile` (usuario sin foto: `has_photo=false`).
Map<String, dynamic> profileFixture() => <String, dynamic>{
  'user': <String, dynamic>{
    'id': 2,
    'name': 'Jean Aponte',
    'email': 'jean@apontephone.com',
    'email_verified_at': '2025-10-08T09:13:51-06:00',
    'phone': '7531107389',
    'profile_photo_url':
        'https://ui-avatars.com/api/?name=J+A&color=7F9CF5&background=EBF4FF',
    'has_photo': false,
  },
  'context': <String, dynamic>{'module_keys': <String>['module_pos']},
};

/// Payload real de `GET /subscription` (solo propietario).
Map<String, dynamic> subscriptionFixture() => <String, dynamic>{
  'subscription': <String, dynamic>{
    'id': 2,
    'commercial_name': 'ApontePhone',
    'business_name': null,
    'status': 'activo',
    'tax_id': null,
    'contact_phone': '7531107389',
    'contact_email': 'apontephone@gmail.com',
    'address': <String, dynamic>{'text': null},
    'slug': 'apontephone',
  },
  'plan': <String, dynamic>{
    'modules': <Map<String, dynamic>>[
      <String, dynamic>{
        'key': 'module_pos',
        'name': 'Punto de Venta',
        'active': true,
      },
    ],
    'limits': <Map<String, dynamic>>[
      <String, dynamic>{
        'key': 'limit_branches',
        'name': 'Sucursales',
        'limit': 2,
        'used': 2,
      },
      <String, dynamic>{
        'key': 'limit_users',
        'name': 'Usuarios',
        'limit': 9,
        'used': null,
      },
    ],
  },
  'usage': <String, dynamic>{
    'branches': 2,
    'users': 7,
    'bank_accounts': 5,
    'products': 3,
    'cash_registers': 2,
    'print_templates': 7,
    'services': 1,
  },
  'status_data': <String, dynamic>{
    'label': 'Activa',
    'expires_at': '2026-10-30T00:00:00-06:00',
    'days_left': 40,
    'is_expired': false,
    'warning': null,
  },
  'pending_payment': null,
  'last_rejected_payment': null,
  'fiscal_document_url': null,
  // `total` es texto decimal y el pago no trae `id` (ver README).
  'history': <Map<String, dynamic>>[
    <String, dynamic>{
      'version': 12,
      'created_at': '2026-06-19T11:36:54-06:00',
      'total': '439.00',
      'payment': <String, dynamic>{
        'id': 412,
        'folio': null,
        'status': 'approved',
        'paid_at': '2026-06-19T11:36:54-06:00',
        'can_request_invoice': true,
      },
    },
  ],
};

/// Payload real de `PUT /branch/switch/{id}` (contexto recalculado).
Map<String, dynamic> branchSwitchFixture() => <String, dynamic>{
  'branch': <String, dynamic>{'id': 3, 'name': 'Guacamayas.Comercial'},
  'message': 'Cambiado a la sucursal: Guacamayas.Comercial',
  'context': <String, dynamic>{
    'user': <String, dynamic>{
      'id': 2,
      'name': 'Jean Aponte',
      'email': 'jean@apontephone.com',
      'is_active': true,
      'branch_id': 3,
      'branch': <String, dynamic>{
        'id': 3,
        'name': 'Guacamayas.Comercial',
        'timezone': 'America/Mexico_city',
      },
      'is_subscription_owner': true,
      'permissions': <String>['pos.access', 'system.branches.switch'],
    },
    'module_keys': <String>['module_pos'],
    'modules': <String>['Punto de Venta'],
    'available_branches': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 3,
        'name': 'Guacamayas.Comercial',
        'is_current': true,
      },
      <String, dynamic>{'id': 2, 'name': 'Melchor Ocampo', 'is_current': false},
    ],
    'active_session': null,
    'joinable_sessions': <Map<String, dynamic>>[],
    'available_cash_registers': <Map<String, dynamic>>[
      <String, dynamic>{'id': 3, 'name': 'Caja principal'},
    ],
  },
};

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `DateFormat` de es-MX lanza
    // `LocaleDataException` al formatear fechas.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  test('notificaciones: los cinco contadores con su total', () {
    final counters = NotificationCounters.fromJson(notificationsFixture());

    expect(counters.expiringDebts, 3);
    expect(counters.upcomingDeliveries, 2);
    expect(counters.unreadUpdates, 5);
    expect(counters.pendingOrders, 1);
    expect(counters.total, 11);
    expect(counters.isEmpty, isFalse);
    expect(counters.countFor(NotificationCategory.upcomingDeliveries), 2);
    expect(counters.categoriesWithItems.length, 4);
  });

  test('notificaciones: contadores vacíos y sin categorías', () {
    final counters = NotificationCounters.fromJson(<String, dynamic>{
      'expiring_debts': 0,
      'upcoming_deliveries': 0,
      'unread_updates': 0,
      'pending_orders': 0,
      'total': 0,
    });

    expect(counters.isEmpty, isTrue);
    expect(counters.categoriesWithItems, isEmpty);
  });

  test('notificaciones: la caché local conserva el mismo cuerpo', () {
    final counters = NotificationCounters.fromJson(notificationsFixture());
    final again = NotificationCounters.fromJson(counters.toJson());

    expect(again.total, counters.total);
    expect(again.expiringDebts, counters.expiringDebts);
  });

  test('notificaciones: los módulos contratados ocultan su contador', () {
    final counter = NotificationCounters.fromJson(<String, dynamic>{
      'expiring_debts': 0,
      'upcoming_deliveries': 0,
      'unread_updates': 0,
      'pending_orders': 0,
      'total': 0,
      'modules': <String, dynamic>{'online_store': false},
    });

    expect(counter.modules.onlineStore, isFalse);
    expect(
      counter.isCategoryVisible(NotificationCategory.pendingOrders),
      isFalse,
    );
    expect(counter.visibleCategories, isNot(contains(NotificationCategory.pendingOrders)));
    // El resto de contadores sigue visible.
    expect(counter.visibleCategories, contains(NotificationCategory.expiringDebts));
  });

  test('notificaciones: sin `modules` no se esconde nada', () {
    // Tolerancia a un servidor que todavía no manda la bandera.
    final counter = NotificationCounters.fromJson(<String, dynamic>{
      'pending_orders': 2,
      'total': 2,
    });

    expect(counter.modules.onlineStore, isTrue);
    expect(counter.visibleCategories, contains(NotificationCategory.pendingOrders));
  });

  test('soporte: canales, horario, temas y centro de ayuda', () {
    final support = SupportContent.fromJson(supportFixture());

    expect(support.title, 'Centro de soporte');
    expect(support.subtitle, 'Estamos aquí para ayudarte');
    expect(support.schedule.length, 2);
    expect(
      support.schedule.first.display,
      'Lunes a viernes · 8:00 AM — 7:00 PM',
    );
    expect(support.channels.length, 2);
    expect(support.channels.first.type, 'email');
    expect(support.channels.first.url, startsWith('mailto:'));
    expect(support.channels.last.url, startsWith('https://wa.me/'));
    expect(support.channels.last.display, contains('+52 33 2170 5650'));
    expect(support.helpTopics.single.title, 'Primeros pasos');
    expect(support.helpCenterUrl, endsWith('/centro-ayuda'));
  });

  test('perfil: has_photo decide la foto (no el avatar generado)', () {
    final profile = UserProfile.fromJson(
      profileFixture()['user']! as Map<String, dynamic>,
    );

    expect(profile.name, 'Jean Aponte');
    expect(profile.phone, '7531107389');
    expect(profile.hasPhoto, isFalse);
    expect(
      profile.realPhotoUrl,
      isNull,
      reason: 'sin foto propia no se pinta el avatar de ui-avatars',
    );
    expect(profile.isEmailVerified, isTrue);
    expect(profile.changesEmail('JEAN@apontephone.com'), isFalse);
    expect(profile.changesEmail('otro@negocio.com'), isTrue);
  });

  test('suscripción: dinero en texto, estatus y consumo del plan', () {
    final overview = SubscriptionOverview.fromJson(subscriptionFixture());

    expect(overview.subscription.commercialName, 'ApontePhone');
    expect(overview.subscription.status, SubscriptionStatus.active);
    expect(overview.statusData.label, 'Activa');
    expect(overview.statusData.isExpired, isFalse);
    expect(overview.statusData.isWarning, isFalse);
    expect(overview.statusData.expiresLabel, contains('quedan 40 días'));

    // `history[].total` llega como texto decimal.
    final entry = overview.history.single;
    expect(entry.total, 439.0);
    expect(entry.amountLabel, r'$439.00');
    expect(entry.payment?.status, SubscriptionPaymentStatus.approved);
    expect(entry.canRequestInvoice, isTrue);
    // El historial ya trae el id del pago (D1, 2026-09-20): es el que exige
    // `POST /subscription/payments/{paymentId}/request-invoice`.
    expect(entry.payment?.id, 412);
    expect(
      entry.payment?.isInvoiceRequestable,
      isTrue,
      reason: 'el pago está aprobado, sin factura pedida y con id',
    );

    final branches = overview.plan.limits.first;
    expect(branches.usageLabel, '2 de 2');
    expect(branches.isAtLimit, isTrue);

    final users = overview.plan.limits.last;
    expect(users.used, isNull);
    expect(users.usageLabel, isNull);
    expect(users.isAtLimit, isFalse);

    expect(overview.usage.products, 3);
    expect(overview.hasFiscalDocument, isFalse);
  });

  test('cambio de sucursal: aplica el contexto que devuelve el servidor', () {
    final result = BranchSwitchResult.fromJson(branchSwitchFixture());

    expect(result.branchId, 3);
    expect(result.branchName, 'Guacamayas.Comercial');
    expect(result.message, 'Cambiado a la sucursal: Guacamayas.Comercial');
    expect(result.context.currentBranch?.id, 3);
    expect(result.context.currentBranch?.isCurrent, isTrue);
    expect(result.context.availableCashRegisters.single.name, 'Caja principal');
    expect(result.context.hasActiveSession, isFalse);
  });

  test('suscripción por vencer: warning del servidor', () {
    final json = subscriptionFixture();
    json['status_data'] = <String, dynamic>{
      'label': 'Por vencer',
      'expires_at': '2026-09-24T00:00:00-06:00',
      'days_left': 4,
      'is_expired': false,
      'warning':
          'Tu suscripción vence en 4 día(s). Renuévala para no perder acceso.',
    };

    final overview = SubscriptionOverview.fromJson(json);

    expect(overview.statusData.isExpiringSoon, isTrue);
    expect(overview.statusData.isWarning, isTrue);
    expect(overview.statusData.warning, contains('vence en 4 día(s)'));
  });

  test('suscripción expirada: estado rojo y fecha sin días restantes', () {
    final json = subscriptionFixture();
    json['subscription'] = <String, dynamic>{
      'id': 2,
      'commercial_name': 'ApontePhone',
      'business_name': null,
      'status': 'expirado',
      'tax_id': null,
      'contact_phone': null,
      'contact_email': null,
      'address': <String, dynamic>{'text': null},
      'slug': 'apontephone',
    };
    json['status_data'] = <String, dynamic>{
      'label': 'Expirada',
      'expires_at': '2025-10-30T00:00:00-06:00',
      'days_left': 0,
      'is_expired': true,
      'warning': 'Tu suscripción expiró. Renuévala para seguir operando.',
    };

    final overview = SubscriptionOverview.fromJson(json);

    expect(overview.subscription.status, SubscriptionStatus.expired);
    expect(overview.statusData.isExpired, isTrue);
    expect(overview.statusData.expiresLabel, 'Vence el 30 oct 2025');
  });
}

