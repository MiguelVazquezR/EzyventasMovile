import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';
import '../../../cash/data/models/active_cash_session.dart';

/// Falla de **contrato** del inicio: el servidor no envió una llave documentada
/// (§3b.2). El contrato promete que ninguna llave falta nunca, así que una
/// ausencia es un error que se reporta, no un `null` que se asume en silencio.
class DashboardContractError implements Exception {
  const DashboardContractError(this.field);

  /// Nombre literal de la llave que faltaba.
  final String field;

  String get message => 'La respuesta del inicio no trae el campo «$field».';

  @override
  String toString() => message;
}

/// Llaves documentadas de `GET /dashboard` (§3b.2).
const List<String> _dashboardKeys = <String>[
  'generated_at',
  'sales',
  'layaways',
  'orders',
  'receivables',
  'inventory',
  'service_orders',
  'cash_register',
];

void _requireKeys(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) {
      throw DashboardContractError(key);
    }
  }
}

/// Texto decimal del contrato: dos decimales y **sin** separador de miles
/// (`"4820.00"`), igual que lo envía el servidor.
String _decimal(double value) => value.toStringAsFixed(2);

/// `GET /dashboard` completo.
///
/// Cada bloque viaja en `null` cuando el usuario no tiene su permiso: **no** se
/// dibuja nada. `0` o lista vacía sí son datos («no hay nada pendiente»).
class MobileDashboard {
  const MobileDashboard({
    required this.generatedAt,
    this.sales,
    this.layaways,
    this.orders,
    this.receivables,
    this.inventory,
    this.serviceOrders,
    this.cashRegister = const CashRegisterState(hasOpenSession: false),
  });

  factory MobileDashboard.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, _dashboardKeys);

    final sales = json['sales'];
    final layaways = json['layaways'];
    final orders = json['orders'];
    final receivables = json['receivables'];
    final inventory = json['inventory'];
    final serviceOrders = json['service_orders'];

    return MobileDashboard(
      generatedAt: AppFormatters.parse(json['generated_at']),
      sales: sales == null
          ? null
          : SalesSummary.fromJson(JsonReader.toMap(sales)),
      layaways: layaways == null
          ? null
          : LayawaysSummary.fromJson(JsonReader.toMap(layaways)),
      orders: orders == null
          ? null
          : OrdersSummary.fromJson(JsonReader.toMap(orders)),
      receivables: receivables == null
          ? null
          : ReceivablesSummary.fromJson(JsonReader.toMap(receivables)),
      inventory: inventory == null
          ? null
          : InventorySummary.fromJson(JsonReader.toMap(inventory)),
      serviceOrders: serviceOrders == null
          ? null
          : ServiceOrdersSummary.fromJson(JsonReader.toMap(serviceOrders)),
      // `cash_register` viaja siempre (no tiene permiso propio).
      cashRegister: CashRegisterState.fromJson(
        JsonReader.toMap(json['cash_register']),
      ),
    );
  }

  /// Momento del cálculo (ISO-8601 UTC), para el «Actualizado …» de la cabecera.
  final DateTime? generatedAt;

  /// Venta del día, ticket promedio, ayer y tendencia (`dashboard.see_sales`).
  final SalesSummary? sales;

  /// Apartados y créditos por vencer (`dashboard.see_layaways`).
  final LayawaysSummary? layaways;

  /// Pedidos por entregar (`dashboard.see_orders`).
  final OrdersSummary? orders;

  /// Deuda de los clientes (`dashboard.see_outstanding_balances`).
  final ReceivablesSummary? receivables;

  /// Inventario y bajo stock (`dashboard.see_inventory_details`).
  final InventorySummary? inventory;

  /// Órdenes de servicio por estatus (`services.orders.access`).
  final ServiceOrdersSummary? serviceOrders;

  /// Estado de caja del usuario; siempre presente.
  final CashRegisterState cashRegister;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'generated_at': generatedAt?.toUtc().toIso8601String(),
    'sales': sales?.toJson(),
    'layaways': layaways?.toJson(),
    'orders': orders?.toJson(),
    'receivables': receivables?.toJson(),
    'inventory': inventory?.toJson(),
    'service_orders': serviceOrders?.toJson(),
    'cash_register': cashRegister.toJson(),
  };
}

/// `sales`: KPIs del día con la misma fuente que el dashboard web.
class SalesSummary {
  const SalesSummary({
    required this.todayTotal,
    required this.todayCount,
    required this.averageTicket,
    required this.yesterdayTotal,
    required this.weeklyTrend,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const <String>[
      'today_total',
      'today_count',
      'average_ticket',
      'yesterday_total',
      'weekly_trend',
    ]);

    return SalesSummary(
      todayTotal: Money.toDouble(json['today_total']),
      todayCount: JsonReader.integerOr(json['today_count'], 0),
      averageTicket: Money.toDouble(json['average_ticket']),
      yesterdayTotal: Money.toDouble(json['yesterday_total']),
      weeklyTrend: JsonReader.toMapList(
        json['weekly_trend'],
      ).map(WeeklyTrendDay.fromJson).toList(growable: false),
    );
  }

  /// Venta del día (`subtotal - descuento + impuesto`).
  final double todayTotal;

  /// Ventas válidas del día (sin `cancelado` ni `cambiado`).
  final int todayCount;

  /// `today_total / today_count` (`0.00` sin ventas).
  final double averageTicket;

  /// Venta de ayer; solo se pinta como comparación, no se recalcula nada.
  final double yesterdayTotal;

  /// **Siempre 7** elementos, de lunes a domingo de la semana en curso.
  final List<WeeklyTrendDay> weeklyTrend;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'today_total': _decimal(todayTotal),
    'today_count': todayCount,
    'average_ticket': _decimal(averageTicket),
    'yesterday_total': _decimal(yesterdayTotal),
    'weekly_trend': weeklyTrend
        .map((day) => day.toJson())
        .toList(growable: false),
  };
}

/// Un día de `sales.weekly_trend` (índice 0 = lunes).
class WeeklyTrendDay {
  const WeeklyTrendDay({required this.day, required this.total});

  factory WeeklyTrendDay.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const <String>['day', 'total']);

    return WeeklyTrendDay(
      day: JsonReader.stringOr(json['day'], ''),
      total: Money.toDouble(json['total']),
    );
  }

  /// Abreviatura corta que envía el servidor (`"lun."`).
  final String day;

  final double total;

  bool get hasSales => total > 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'day': day,
    'total': _decimal(total),
  };
}

/// `layaways`: apartados y créditos por vencer (ventana por defecto, 3 días).
class LayawaysSummary {
  const LayawaysSummary({required this.expiringCount});

  factory LayawaysSummary.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const <String>['expiring_count']);

    return LayawaysSummary(
      expiringCount: JsonReader.integerOr(json['expiring_count'], 0),
    );
  }

  final int expiringCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'expiring_count': expiringCount,
  };
}

/// `orders`: pedidos con entrega vencida o próxima (misma ventana).
class OrdersSummary {
  const OrdersSummary({required this.upcomingDeliveriesCount});

  factory OrdersSummary.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const <String>['upcoming_deliveries_count']);

    return OrdersSummary(
      upcomingDeliveriesCount: JsonReader.integerOr(
        json['upcoming_deliveries_count'],
        0,
      ),
    );
  }

  final int upcomingDeliveriesCount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'upcoming_deliveries_count': upcomingDeliveriesCount,
  };
}

/// `receivables`: saldo a favor del negocio (deuda de los clientes).
class ReceivablesSummary {
  const ReceivablesSummary({required this.totalCustomerDebt});

  factory ReceivablesSummary.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const <String>['total_customer_debt']);

    return ReceivablesSummary(
      totalCustomerDebt: Money.toDouble(json['total_customer_debt']),
    );
  }

  final double totalCustomerDebt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total_customer_debt': _decimal(totalCustomerDebt),
  };
}

/// `inventory`: KPIs de stock y la lista corta para pedir al proveedor.
class InventorySummary {
  const InventorySummary({
    required this.totalItems,
    required this.healthyStockCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalCost,
    required this.totalSaleValue,
    required this.lowStockProducts,
  });

  factory InventorySummary.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const <String>[
      'total_items',
      'healthy_stock_count',
      'low_stock_count',
      'out_of_stock_count',
      'total_cost',
      'total_sale_value',
      'low_stock_products',
    ]);

    return InventorySummary(
      totalItems: JsonReader.integerOr(json['total_items'], 0),
      healthyStockCount: JsonReader.integerOr(json['healthy_stock_count'], 0),
      lowStockCount: JsonReader.integerOr(json['low_stock_count'], 0),
      outOfStockCount: JsonReader.integerOr(json['out_of_stock_count'], 0),
      totalCost: Money.toDouble(json['total_cost']),
      totalSaleValue: Money.toDouble(json['total_sale_value']),
      lowStockProducts: JsonReader.toMapList(
        json['low_stock_products'],
      ).map(LowStockProduct.fromJson).toList(growable: false),
    );
  }

  /// Artículos con stock registrado en la sucursal (variante = 1).
  final int totalItems;

  /// Artículos por arriba del mínimo configurado.
  final int healthyStockCount;

  /// `0 < stock ≤ min_stock`.
  final int lowStockCount;

  /// `stock ≤ 0`.
  final int outOfStockCount;

  final double totalCost;
  final double totalSaleValue;

  /// Hasta 5 filas; el `id` puede repetirse si el bajo stock es de variantes.
  final List<LowStockProduct> lowStockProducts;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total_items': totalItems,
    'healthy_stock_count': healthyStockCount,
    'low_stock_count': lowStockCount,
    'out_of_stock_count': outOfStockCount,
    'total_cost': _decimal(totalCost),
    'total_sale_value': _decimal(totalSaleValue),
    'low_stock_products': lowStockProducts
        .map((product) => product.toJson())
        .toList(growable: false),
  };
}

/// Fila de `inventory.low_stock_products`.
class LowStockProduct {
  const LowStockProduct({
    required this.id,
    required this.name,
    this.sku,
    required this.currentStock,
    required this.minStock,
  });

  factory LowStockProduct.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const <String>[
      'id',
      'name',
      'sku',
      'current_stock',
      'min_stock',
    ]);

    return LowStockProduct(
      id: JsonReader.integerOr(json['id'], 0),
      name: JsonReader.stringOr(json['name'], ''),
      sku: JsonReader.string(json['sku']),
      currentStock: Money.toDouble(json['current_stock']),
      minStock: Money.toDouble(json['min_stock']),
    );
  }

  final int id;
  final String name;

  /// Código del artículo; puede venir `null`.
  final String? sku;

  final double currentStock;
  final double minStock;

  bool get isOutOfStock => currentStock <= 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'sku': sku,
    'current_stock': currentStock,
    'min_stock': minStock,
  };
}

/// `service_orders`: órdenes de servicio de la sucursal por estatus.
class ServiceOrdersSummary {
  const ServiceOrdersSummary({required this.total, required this.byStatus});

  /// Estatus del enum de órdenes, en el orden del flujo (`cancelado` al final).
  static const List<String> statusKeys = <String>[
    'pendiente',
    'en_progreso',
    'esperando_refaccion',
    'terminado',
    'entregado',
    'cancelado',
  ];

  factory ServiceOrdersSummary.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const <String>['total', 'by_status']);

    final byStatus = JsonReader.toMap(json['by_status']);

    return ServiceOrdersSummary(
      total: JsonReader.integerOr(json['total'], 0),
      // La API promete las 6 llaves; si llegara a faltar una, cuenta como 0.
      byStatus: <String, int>{
        for (final status in statusKeys)
          status: JsonReader.integerOr(byStatus[status], 0),
      },
    );
  }

  /// Histórico completo de la sucursal (no solo las abiertas).
  final int total;

  /// Las 6 llaves del enum con su conteo.
  final Map<String, int> byStatus;

  int countFor(String status) => byStatus[status] ?? 0;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'total': total,
    'by_status': byStatus,
  };
}

/// `cash_register`: turno del usuario; viaja siempre (no tiene permiso propio).
class CashRegisterState {
  const CashRegisterState({required this.hasOpenSession, this.session});

  factory CashRegisterState.fromJson(Map<String, dynamic> json) {
    _requireKeys(json, const <String>['has_open_session', 'session']);

    final session = json['session'];

    return CashRegisterState(
      hasOpenSession: JsonReader.boolean(json['has_open_session']),
      session: session == null
          ? null
          : ActiveCashSession.fromJson(JsonReader.toMap(session)),
    );
  }

  final bool hasOpenSession;

  /// Mismo objeto `session` de la caja (§6); `null` sin turno abierto.
  final ActiveCashSession? session;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'has_open_session': hasOpenSession,
    'session': session == null
        ? null
        : <String, dynamic>{
            'id': session!.id,
            'status': session!.status,
            'opened_at': session!.openedAt?.toIso8601String(),
            'opening_cash_balance': session!.openingCashBalance,
          },
  };
}
