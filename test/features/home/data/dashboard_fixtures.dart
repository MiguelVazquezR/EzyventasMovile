/// Fixtures del inicio: los JSON de §3b.2, §3b.3 y §3b.4 del contrato.
///
/// Son copias literales de la documentación para que el parseo se pruebe contra
/// el contrato y no contra una invención del cliente.
library;

/// `GET /dashboard` de un propietario con turno abierto (§3b.2).
Map<String, dynamic> ownerDashboardJson() => <String, dynamic>{
  'generated_at': '2026-10-03T18:54:02.467728Z',
  'sales': <String, dynamic>{
    'today_total': '4820.00',
    'today_count': 12,
    'average_ticket': '401.67',
    'yesterday_total': '3910.00',
    'weekly_trend': <Map<String, dynamic>>[
      <String, dynamic>{'day': 'lun.', 'total': '2100.00'},
      <String, dynamic>{'day': 'mar.', 'total': '3050.00'},
      <String, dynamic>{'day': 'mié.', 'total': '0.00'},
      <String, dynamic>{'day': 'jue.', 'total': '1780.00'},
      <String, dynamic>{'day': 'vie.', 'total': '4400.00'},
      <String, dynamic>{'day': 'sáb.', 'total': '4820.00'},
      <String, dynamic>{'day': 'dom.', 'total': '0.00'},
    ],
  },
  'layaways': <String, dynamic>{'expiring_count': 2},
  'orders': <String, dynamic>{'upcoming_deliveries_count': 3},
  'receivables': <String, dynamic>{'total_customer_debt': '1250.00'},
  'inventory': <String, dynamic>{
    'total_items': 214,
    'healthy_stock_count': 168,
    'low_stock_count': 39,
    'out_of_stock_count': 7,
    'total_cost': '185400.00',
    'total_sale_value': '312750.00',
    'low_stock_products': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 88,
        'name': 'Filtro de aceite HF-204',
        'sku': 'FLT-204',
        'current_stock': 2,
        'min_stock': 5,
      },
      <String, dynamic>{
        'id': 142,
        'name': 'Bujía iridium CR8E',
        'sku': 'BUJ-CR8E',
        'current_stock': 1,
        'min_stock': 4,
      },
    ],
  },
  'service_orders': <String, dynamic>{
    'total': 26,
    'by_status': <String, dynamic>{
      'pendiente': 4,
      'en_progreso': 3,
      'esperando_refaccion': 2,
      'terminado': 1,
      'entregado': 15,
      'cancelado': 1,
    },
  },
  'cash_register': <String, dynamic>{
    'has_open_session': true,
    'session': <String, dynamic>{
      'id': 41,
      'status': 'abierta',
      'opened_at': '2026-10-03T13:00:00-06:00',
      'opening_cash_balance': 1500,
      'opening_bank_balances': <Map<String, dynamic>>[],
      'cash_register': <String, dynamic>{'id': 1, 'name': 'Caja 1'},
      'opener': <String, dynamic>{'id': 4, 'name': 'José Pérez'},
      'users': <Map<String, dynamic>>[
        <String, dynamic>{'id': 4, 'name': 'José Pérez'},
      ],
      'totals': <String, dynamic>{
        'cash': 2760,
        'card': 800,
        'transfer': 0,
        'balance': 0,
      },
    },
  },
};

/// `GET /dashboard` de un empleado sin permisos del inicio: los bloques que no
/// puede ver viajan en `null` y `cash_register` sigue presente (§3b.1).
Map<String, dynamic> employeeDashboardJson() => <String, dynamic>{
  'generated_at': '2026-10-03T18:54:02.467728Z',
  'sales': null,
  'layaways': null,
  'orders': null,
  'receivables': null,
  'inventory': null,
  'service_orders': null,
  'cash_register': <String, dynamic>{
    'has_open_session': false,
    'session': null,
  },
};

/// `GET /dashboard/expiring-layaways` (§3b.3).
Map<String, dynamic> expiringLayawaysJson() => <String, dynamic>{
  'days': 3,
  'data': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 812,
      'folio': 'A-0142',
      'type': 'apartado',
      'status': 'apartado',
      'customer_id': 57,
      'customer_name': 'Ana Ramírez',
      'customer_phone': '4771112233',
      'total_amount': '1850.00',
      'total_paid': '500.00',
      'pending_amount': '1350.00',
      'expiration_date': '2026-10-03',
      'days_remaining': 0,
      'is_overdue': false,
    },
    <String, dynamic>{
      'id': 798,
      'folio': 'C-0087',
      'type': 'credito',
      'status': 'pendiente',
      'customer_id': 12,
      'customer_name': 'Refaccionaria del Valle',
      'customer_phone': null,
      'total_amount': '2400.00',
      'total_paid': '400.00',
      'pending_amount': '2000.00',
      'expiration_date': '2026-09-30',
      'days_remaining': -3,
      'is_overdue': true,
    },
  ],
};

/// `GET /dashboard/upcoming-deliveries` (§3b.4).
Map<String, dynamic> upcomingDeliveriesJson() => <String, dynamic>{
  'days': 3,
  'data': <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 815,
      'folio': 'P-0228',
      'status': 'por_entregar',
      'customer_id': null,
      'customer_name': 'Cliente invitado',
      'customer_phone': null,
      'shipping_address': null,
      'notes': null,
      'total_amount': '980.00',
      'total_paid': '0.00',
      'pending_amount': '980.00',
      'delivery_date': '2026-10-03T00:00:00.000000Z',
      'days_remaining': 0,
      'is_today': true,
      'is_overdue': false,
    },
    <String, dynamic>{
      'id': 830,
      'folio': 'P-0231',
      'status': 'por_entregar',
      'customer_id': 57,
      'customer_name': 'Ana Ramírez',
      'customer_phone': '4771112233',
      'shipping_address': 'Av. Reforma 220, col. Centro',
      'notes': 'Entregar después de las 6 pm',
      'total_amount': '3150.00',
      'total_paid': '1000.00',
      'pending_amount': '2150.00',
      'delivery_date': '2026-10-04T00:00:00.000000Z',
      'days_remaining': 1,
      'is_today': false,
      'is_overdue': false,
    },
  ],
};
