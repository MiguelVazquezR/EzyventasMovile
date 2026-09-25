/// Rutas de la API `/api/v1`.
///
/// Verificadas contra `routes/api/v1/*.php` del backend (nunca se escribe una
/// ruta a mano dentro de un widget o repositorio).
class ApiEndpoints {
  const ApiEndpoints._();

  // Autenticación
  static const String login = '/auth/login';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';

  // Catálogo
  static const String products = '/catalog/products';
  static String product(int id) => '/catalog/products/$id';
  static const String categories = '/catalog/categories';
  static const String services = '/catalog/services';

  // Clientes
  static const String customers = '/customers';
  static String customer(int id) => '/customers/$id';

  // Caja y bancos
  static const String currentCashRegisterSession =
      '/cash-register-sessions/current';
  static const String cashRegisterSessions = '/cash-register-sessions';
  static const String rejoinOrStartCashRegisterSession =
      '/cash-register-sessions/rejoin-or-start';
  static String joinCashRegisterSession(int id) =>
      '/cash-register-sessions/$id/join';
  static String leaveCashRegisterSession(int id) =>
      '/cash-register-sessions/$id/leave';
  static String cashRegisterSessionSummary(int id) =>
      '/cash-register-sessions/$id/summary';

  /// El corte listo para (re)imprimir, también el de un turno cerrado (§6.3).
  static String cashRegisterSessionReceipt(int id) =>
      '/cash-register-sessions/$id/receipt';

  static String closeCashRegisterSession(int id) =>
      '/cash-register-sessions/$id';
  static const String bankAccounts = '/bank-accounts';

  // Punto de venta
  static const String checkout = '/pos/checkout';
  static const String layaway = '/pos/layaway';
  static const String storeOrder = '/pos/store-order';

  // Ventas
  static const String transactions = '/transactions';
  static String transaction(int id) => '/transactions/$id';
  static String transactionCancel(int id) => '/transactions/$id/cancel';
  static String transactionRefund(int id) => '/transactions/$id/refund';
  static String transactionPayments(int id) => '/transactions/$id/payments';
  static String transactionPayment(int id, int paymentId) =>
      '/transactions/$id/payments/$paymentId';

  // Órdenes de servicio
  static const String serviceOrders = '/service-orders';

  /// Definiciones de campos personalizados del módulo (§9), para dibujar el
  /// formulario de alta antes de que exista la orden.
  static const String serviceOrderCustomFields = '/service-orders/custom-fields';

  static String serviceOrder(int id) => '/service-orders/$id';
  static String serviceOrderStatus(int id) => '/service-orders/$id/status';
  static String serviceOrderDiagnosis(int id) => '/service-orders/$id/diagnosis';
  static String serviceOrderPayments(int id) => '/service-orders/$id/payments';
  static String serviceOrderEnsureTransaction(int id) =>
      '/service-orders/$id/ensure-transaction';

  // Impresión y WhatsApp
  static const String printTemplates = '/print/templates';
  static const String printBluetoothPayload = '/print/bluetooth-payload';
  static const String printPayload = '/print/payload';
  static const String printTicketHtml = '/print/ticket-html';
  static const String printWhatsappTicket = '/print/whatsapp-ticket';

  // Cuenta
  static const String notifications = '/notifications';
  static const String support = '/support';
  static String switchBranch(int branchId) => '/branch/switch/$branchId';
  static const String profile = '/profile';
  static const String profilePhoto = '/profile/photo';
  static const String profilePassword = '/profile/password';
  static const String logoutOtherDevices = '/profile/logout-other-devices';
  static const String subscription = '/subscription';
  static const String subscriptionDocuments = '/subscription/documents';
  static String requestSubscriptionInvoice(int paymentId) =>
      '/subscription/payments/$paymentId/request-invoice';
}
