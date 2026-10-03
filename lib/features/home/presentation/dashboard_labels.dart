/// Textos visibles del inicio (español, sentence case).
///
/// Un solo lugar para el microcopy de las tres pantallas, igual que
/// `AccountLabels` / `SalesLabels` en sus módulos. Nada de texto suelto en los
/// widgets y **nunca** texto inventado para reemplazar el `message` del
/// servidor: los errores se pintan tal cual llegan.
class DashboardLabels {
  const DashboardLabels._();

  // Cabecera
  static const String title = 'Inicio';
  static const String loading = 'Cargando el resumen…';
  static String updatedAt(String time) => 'Actualizado $time';

  // Venta de hoy
  static const String todaySalesTitle = 'Venta de hoy';
  static const String yesterday = 'Ayer';
  static String salesCount(int count) =>
      count == 1 ? '1 venta' : '$count ventas';
  static String averageTicket(String amount) => 'Ticket promedio $amount';
  static const String weeklyTrendTitle = 'Tendencia semanal';
  static const String weeklyTrendSubtitle = 'Lunes a domingo de esta semana';

  // Tarjetas de alerta
  static const String expiringLayawaysTitle = 'Apartados por vencer';
  static String windowHint(int days) =>
      days == 1 ? 'Vencidos o de hoy' : 'Vencidos o en $days días';
  static const String upcomingDeliveriesTitle = 'Pedidos por entregar';
  static String deliveriesHint(int days) =>
      days == 1 ? 'Entregas vencidas o de hoy' : 'Entregas vencidas o en $days días';
  static const String receivablesTitle = 'Saldo por cobrar';
  static const String receivablesHint = 'Lo que te deben los clientes';
  static const String lowStockTitle = 'Stock crítico';
  static String lowStockHint(int low, int out) =>
      out == 0 ? '$low en bajo stock' : '$low en bajo stock · $out agotados';

  // Inventario
  static const String inventoryTitle = 'Inventario';
  static String inventoryItems(int total) => '$total artículos con stock';
  static const String inventoryHealthy = 'Stock suficiente';
  static const String inventoryLow = 'Bajo stock';
  static const String inventoryOut = 'Agotados';
  static const String inventoryCost = 'Valor al costo';
  static const String inventorySaleValue = 'Valor a precio de venta';
  static const String inventoryLowList = 'Para pedir al proveedor';
  static const String inventoryEmpty = 'Ningún artículo por debajo del mínimo.';
  static String stockOf(String current, String min) => '$current de $min';

  // Órdenes de servicio
  static const String serviceOrdersTitle = 'Órdenes de servicio';
  static String serviceOrdersTotal(int total) => '$total en total';

  // Caja
  static const String cashTitle = 'Caja';
  static const String cashOpenStatus = 'Turno abierto';
  static const String cashClosedStatus = 'Sin turno abierto';
  static String cashOpenedAt(String time) => 'Abierto a las $time';
  static const String cashOpenedBy = 'Abierto por';
  static const String cashViewAction = 'Ver caja';
  static const String cashOpenAction = 'Abrir caja';
  static const String cashEmptyHint =
      'Abre un turno antes de cobrar en el punto de venta.';
  static const String cashTotal = 'Total del turno';
  static const String cashCash = 'Efectivo';
  static const String cashCard = 'Tarjeta';
  static const String cashTransfer = 'Transferencia';

  // Listado: apartados y créditos por vencer
  static const String expiringLayawaysListTitle = 'Apartados y créditos';
  static const String expiringLayawaysEmptyTitle = 'Nada por vencer';
  static const String expiringLayawaysListEmpty =
      'No hay apartados ni créditos por vencer en esta ventana.';
  static const String layawayTypeApartado = 'Apartado';
  static const String layawayTypeCredito = 'Crédito';
  static const String expiresOn = 'Vence';
  static const String dueToday = 'Vence hoy';
  static String dueInDays(int days) =>
      days == 1 ? 'Vence mañana' : 'Vence en $days días';
  static String overdueBy(int days) {
    final elapsed = days.abs();
    return elapsed == 1 ? 'Vencido hace 1 día' : 'Vencido hace $elapsed días';
  }

  // Listado: pedidos por entregar
  static const String upcomingDeliveriesListTitle = 'Pedidos por entregar';
  static const String upcomingDeliveriesEmptyTitle = 'Ninguna entrega pendiente';
  static const String upcomingDeliveriesListEmpty =
      'No hay entregas vencidas ni programadas en esta ventana.';
  static const String deliveryDate = 'Entrega';
  static const String deliveryToday = 'Entrega hoy';
  static String deliveryInDays(int days) =>
      days == 1 ? 'Entrega mañana' : 'Entrega en $days días';
  static String deliveryOverdueBy(int days) {
    final elapsed = days.abs();
    return elapsed == 1
        ? 'Entrega vencida hace 1 día'
        : 'Entrega vencida hace $elapsed días';
  }

  // Filas compartidas por los dos listados
  static const String customer = 'Cliente';
  static const String phone = 'Teléfono';
  static const String shippingAddress = 'Dirección';
  static const String notes = 'Nota';
  static const String totalAmount = 'Total';
  static const String paidAmount = 'Abonado';
  static const String pendingAmount = 'Por cobrar';
  static const String noPhone = 'Sin teléfono';
  static const String closeWindow = 'Volver';

  // Filtro de la ventana (1-30 días; por defecto 3)
  static const List<int> dayOptions = <int>[1, 3, 7, 15, 30];
  static String dayOption(int days) => days == 1 ? '1 día' : '$days días';
  static String windowTitle(int days) =>
      days == 1 ? 'Próximo 1 día' : 'Próximos $days días';
}
