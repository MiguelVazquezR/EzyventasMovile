import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';
import '../../../sales/data/models/transaction_detail.dart';
import 'service_order_summary.dart';

/// Cliente de la orden (`customer` del detalle). `balance` es **texto decimal**
/// (negativo = debe, positivo = saldo a favor).
class ServiceOrderCustomer {
  const ServiceOrderCustomer({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.balance,
  });

  factory ServiceOrderCustomer.fromJson(Map<String, dynamic> json) =>
      ServiceOrderCustomer(
        id: JsonReader.integerOr(json['id'], 0),
        name: JsonReader.stringOr(json['name'], ''),
        phone: JsonReader.string(json['phone']),
        email: JsonReader.string(json['email']),
        balance: Money.toDouble(json['balance']),
      );

  /// `null` cuando la orden no tiene cliente registrado.
  static ServiceOrderCustomer? fromJsonOrNull(Object? value) {
    final map = JsonReader.toMap(value);

    return map.isEmpty ? null : ServiceOrderCustomer.fromJson(map);
  }

  final int id;
  final String name;
  final String? phone;
  final String? email;
  final double balance;

  /// Saldo a favor disponible para un anticipo con `use_balance`.
  bool get hasBalanceInFavor => balance > 0.01;

  bool get hasDebt => balance < -0.01;
}

/// Dirección del cliente (`customer_address`).
class ServiceOrderAddress {
  const ServiceOrderAddress({required this.street, required this.city});

  factory ServiceOrderAddress.fromJson(Map<String, dynamic> json) =>
      ServiceOrderAddress(
        street: JsonReader.string(json['street']),
        city: JsonReader.string(json['city']),
      );

  static ServiceOrderAddress? fromJsonOrNull(Object? value) {
    final map = JsonReader.toMap(value);

    return map.isEmpty ? null : ServiceOrderAddress.fromJson(map);
  }

  final String? street;
  final String? city;

  /// `Av. Hidalgo 120, León` (solo las partes capturadas).
  String? get label {
    final parts = <String>[
      street ?? '',
      city ?? '',
    ].where((part) => part.trim().isNotEmpty);

    return parts.isEmpty ? null : parts.join(', ');
  }
}

/// Línea de la orden (`items[]`) — mano de obra o refacción.
///
/// `unit_price` y `line_total` llegan como **texto decimal**; `quantity` es
/// numérico. `itemable_type` identifica el catálogo de origen:
/// `App\Models\Service`, `App\Models\ServiceVariant`, `App\Models\Product` o
/// `App\Models\ProductAttribute` (`null` = concepto libre).
class ServiceOrderItem {
  const ServiceOrderItem({
    required this.id,
    required this.description,
    required this.itemableType,
    required this.itemableId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory ServiceOrderItem.fromJson(Map<String, dynamic> json) =>
      ServiceOrderItem(
        id: JsonReader.integerOr(json['id'], 0),
        description: JsonReader.stringOr(json['description'], ''),
        itemableType: JsonReader.string(json['itemable_type']),
        itemableId: JsonReader.integer(json['itemable_id']),
        quantity: Money.toDouble(json['quantity'], fallback: 1),
        unitPrice: Money.toDouble(json['unit_price']),
        lineTotal: Money.toDouble(json['line_total']),
      );

  final int id;
  final String description;
  final String? itemableType;
  final int? itemableId;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  /// Refacción del inventario (descuenta stock al guardar).
  bool get isPart =>
      itemableType == ServiceOrderItemType.product ||
      itemableType == ServiceOrderItemType.productAttribute;

  /// Mano de obra del catálogo de servicios.
  bool get isService =>
      itemableType == ServiceOrderItemType.service ||
      itemableType == ServiceOrderItemType.serviceVariant;

  /// Concepto capturado a mano (no está en el catálogo).
  bool get isCustom => !isPart && !isService;

  /// Costo de la refacción (base del cálculo de comisión y utilidad, §8.5).
  double get partsCost => isPart ? lineTotal : 0;
}

/// Tipos `itemable_type` que usa el backend (`01-contrato-api-v1.md` §9).
class ServiceOrderItemType {
  const ServiceOrderItemType._();

  static const String product = 'App\\Models\\Product';
  static const String productAttribute = 'App\\Models\\ProductAttribute';
  static const String service = 'App\\Models\\Service';
  static const String serviceVariant = 'App\\Models\\ServiceVariant';

  /// Etiqueta corta para la lista de conceptos.
  static String labelOf(String? type) => switch (type) {
    product || productAttribute => 'Refacción',
    service || serviceVariant => 'Mano de obra',
    _ => 'Concepto',
  };
}


/// Evidencia fotográfica de la orden (`media.*`).
///
/// `thumb_url` cae al original mientras el servidor no genere la conversión
/// `thumb`; `size` viene en bytes.
class ServiceOrderMedia {
  const ServiceOrderMedia({
    required this.id,
    required this.fileName,
    required this.originalUrl,
    required this.thumbUrl,
    required this.size,
  });

  factory ServiceOrderMedia.fromJson(Map<String, dynamic> json) {
    final original = JsonReader.string(json['original_url']) ?? '';

    return ServiceOrderMedia(
      id: JsonReader.integerOr(json['id'], 0),
      fileName: JsonReader.stringOr(json['file_name'], ''),
      originalUrl: original,
      thumbUrl: JsonReader.string(json['thumb_url']) ?? original,
      size: JsonReader.integerOr(json['size'], 0),
    );
  }

  final int id;
  final String fileName;
  final String originalUrl;

  /// Miniatura (o la original si aún no existe la conversión).
  final String thumbUrl;

  /// Peso del archivo en bytes.
  final int size;

  /// `245 KB` / `1.4 MB`.
  String get sizeLabel {
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(size / 1024).round()} KB';
  }
}

/// Venta vinculada de la orden (`transaction`, `null` en órdenes antiguas).
///
/// `total`, `total_paid` y `remaining_due` son **número**; cada pago trae su
/// `amount` como **texto decimal**.
class ServiceOrderTransaction {
  const ServiceOrderTransaction({
    required this.id,
    required this.folio,
    required this.status,
    required this.total,
    required this.totalPaid,
    required this.remainingDue,
    required this.payments,
  });

  factory ServiceOrderTransaction.fromJson(Map<String, dynamic> json) =>
      ServiceOrderTransaction(
        id: JsonReader.integerOr(json['id'], 0),
        folio: JsonReader.stringOr(json['folio'], ''),
        status: JsonReader.stringOr(json['status'], ''),
        total: Money.toDouble(json['total']),
        totalPaid: Money.toDouble(json['total_paid']),
        remainingDue: Money.toDouble(json['remaining_due']),
        payments: JsonReader.toMapList(
          json['payments'],
        ).map(TransactionPayment.fromJson).toList(growable: false),
      );

  static ServiceOrderTransaction? fromJsonOrNull(Object? value) {
    final map = JsonReader.toMap(value);

    return map.isEmpty ? null : ServiceOrderTransaction.fromJson(map);
  }

  final int id;

  /// Folio de la venta vinculada (`OS-V-006`).
  final String folio;
  final String status;
  final double total;
  final double totalPaid;
  final double remainingDue;
  final List<TransactionPayment> payments;

  bool get isCancelled => status == 'cancelado' || status == 'reembolsado';

  bool get hasPendingAmount => remainingDue > 0.01 && !isCancelled;
}


/// Evento del historial de la orden (`activities`, últimos 20).
class ServiceOrderActivity {
  const ServiceOrderActivity({
    required this.id,
    required this.description,
    required this.event,
    required this.causerName,
    required this.createdAt,
  });

  factory ServiceOrderActivity.fromJson(Map<String, dynamic> json) {
    final causer = JsonReader.toMap(json['causer']);

    return ServiceOrderActivity(
      id: JsonReader.integer(json['id']),
      description: JsonReader.stringOr(json['description'], ''),
      event: JsonReader.string(json['event']),
      causerName: JsonReader.string(causer['name']),
      createdAt: AppFormatters.parse(json['created_at']),
    );
  }

  final int? id;
  final String description;
  final String? event;

  /// Quién hizo el cambio (`null` si el usuario fue eliminado).
  final String? causerName;
  final DateTime? createdAt;
}

/// Definición de un campo personalizado de la orden
/// (`custom_field_definitions`, `module = service_orders`).
class ServiceOrderCustomFieldDefinition {
  const ServiceOrderCustomFieldDefinition({
    required this.key,
    required this.name,
    required this.type,
    required this.options,
    required this.isRequired,
  });

  factory ServiceOrderCustomFieldDefinition.fromJson(
    Map<String, dynamic> json,
  ) => ServiceOrderCustomFieldDefinition(
    key: JsonReader.stringOr(json['key'], ''),
    name: JsonReader.stringOr(json['name'], ''),
    type: JsonReader.stringOr(json['type'], 'text'),
    options: JsonReader.stringList(json['options']),
    isRequired: JsonReader.boolean(json['is_required']),
  );

  final String key;
  final String name;

  /// `text`, `number`, `switch` (o el tipo que devuelva el servidor).
  final String type;

  /// Opciones cuando el campo es una lista (puede venir vacía).
  final List<String> options;
  final bool isRequired;

  bool get isSwitch => type == 'switch';
  bool get isNumber => type == 'number';
}


/// Detalle completo de una orden (`GET /service-orders/{id}`, contrato §9).
///
/// Reutiliza [ServiceOrderSummary] para los campos del listado y añade el
/// cliente, los conceptos, las evidencias, la venta vinculada y el historial.
class ServiceOrderDetail {
  const ServiceOrderDetail({
    required this.summary,
    required this.customer,
    required this.customerEmail,
    required this.customerAddress,
    required this.reportedProblems,
    required this.technicianDiagnosis,
    required this.technicianCommissionType,
    required this.technicianCommissionValue,
    required this.discountType,
    required this.discountValue,
    required this.customFields,
    required this.customFieldDefinitions,
    required this.items,
    required this.initialEvidence,
    required this.closingEvidence,
    required this.transaction,
    required this.activities,
  });

  factory ServiceOrderDetail.fromJson(Map<String, dynamic> json) {
    final media = JsonReader.toMap(json['media']);

    return ServiceOrderDetail(
      summary: ServiceOrderSummary.fromJson(json),
      customer: ServiceOrderCustomer.fromJsonOrNull(json['customer']),
      customerEmail: JsonReader.string(json['customer_email']),
      customerAddress: ServiceOrderAddress.fromJsonOrNull(
        json['customer_address'],
      ),
      reportedProblems: JsonReader.stringOr(json['reported_problems'], ''),
      technicianDiagnosis: JsonReader.string(json['technician_diagnosis']),
      technicianCommissionType: JsonReader.string(
        json['technician_commission_type'],
      ),
      technicianCommissionValue: Money.toDouble(
        json['technician_commission_value'],
      ),
      discountType: JsonReader.stringOr(json['discount_type'], 'fixed'),
      discountValue: Money.toDouble(json['discount_value']),
      customFields: JsonReader.toMap(json['custom_fields']),
      customFieldDefinitions: JsonReader.toMapList(
        json['custom_field_definitions'],
      ).map(ServiceOrderCustomFieldDefinition.fromJson).toList(growable: false),
      items: JsonReader.toMapList(
        json['items'],
      ).map(ServiceOrderItem.fromJson).toList(growable: false),
      initialEvidence: JsonReader.toMapList(
        media['initial_service_order_evidence'],
      ).map(ServiceOrderMedia.fromJson).toList(growable: false),
      closingEvidence: JsonReader.toMapList(
        media['closing_service_order_evidence'],
      ).map(ServiceOrderMedia.fromJson).toList(growable: false),
      transaction: ServiceOrderTransaction.fromJsonOrNull(json['transaction']),
      activities: JsonReader.toMapList(
        json['activities'],
      ).map(ServiceOrderActivity.fromJson).toList(growable: false),
    );
  }

  final ServiceOrderSummary summary;

  /// Cliente registrado (`null` = orden de mostrador).
  final ServiceOrderCustomer? customer;
  final String? customerEmail;
  final ServiceOrderAddress? customerAddress;

  /// Fallas que reporta el cliente.
  final String reportedProblems;

  /// Diagnóstico del técnico (`null` mientras no se capture).
  final String? technicianDiagnosis;

  /// `percentage` o `fixed` (`null` si la orden no tiene técnico asignado).
  final String? technicianCommissionType;
  final double technicianCommissionValue;

  /// `fixed` o `percentage`.
  final String discountType;
  final double discountValue;

  /// `{ "pin_desbloqueo": "1234" }`.
  final Map<String, dynamic> customFields;
  final List<ServiceOrderCustomFieldDefinition> customFieldDefinitions;
  final List<ServiceOrderItem> items;

  /// Fotos tomadas al recibir el equipo.
  final List<ServiceOrderMedia> initialEvidence;

  /// Fotos del diagnóstico / cierre.
  final List<ServiceOrderMedia> closingEvidence;

  /// Venta vinculada (`OS-V-###`), `null` en órdenes antiguas.
  final ServiceOrderTransaction? transaction;
  final List<ServiceOrderActivity> activities;

  // --- Atajos del listado y cálculos informativos del técnico (§8.5) ------

  int get id => summary.id;
  String get folio => summary.folio;
  String get status => summary.status;
  String get itemDescription => summary.itemDescription;
  double get subtotal => summary.subtotal;
  double get discountAmount => summary.discountAmount;
  double get finalTotal => summary.finalTotal;
  double get totalPaid => summary.totalPaid;
  double get amountDue => summary.amountDue;
  bool get hasTransaction => summary.hasTransaction;
  DateTime? get receivedAt => summary.receivedAt;
  DateTime? get promisedAt => summary.promisedAt;
  String? get technicianName => summary.technicianName;
  bool get isCancelled => summary.isCancelled;
  String get customerLabel => summary.customerLabel;
  int? get promiseDaysLeft => summary.promiseDaysLeft;

  /// Saldo real por cobrar: el de la venta vinculada si ya existe.
  double get pendingAmount {
    final linked = transaction;

    return linked == null ? amountDue : linked.remainingDue;
  }

  bool get hasTechnician => (technicianName ?? '').trim().isNotEmpty;

  /// La comisión del técnico es un porcentaje de la mano de obra.
  bool get commissionIsPercentage => technicianCommissionType == 'percentage';

  /// Se puede registrar un anticipo (exige venta vinculada y saldo pendiente).
  bool get canReceivePayment => pendingAmount > 0.01 && !isCancelled;

  /// Una orden cancelada no se edita, diagnostica ni cobra.
  bool get isEditable => !isCancelled;

  /// Todas las evidencias juntas (iniciales + de cierre).
  List<ServiceOrderMedia> get allEvidence =>
      <ServiceOrderMedia>[...initialEvidence, ...closingEvidence];

  /// Costo de las refacciones usadas (§8.5).
  double get partsCost =>
      Money.round2(items.fold<double>(0, (sum, item) => sum + item.partsCost));

  /// Comisión del técnico: porcentaje sobre la mano de obra o monto fijo.
  double get technicianCommission {
    final type = technicianCommissionType;

    if (type == null || type.isEmpty) {
      return 0;
    }

    if (type == 'fixed') {
      return Money.round2(technicianCommissionValue);
    }

    final labor = finalTotal - partsCost;
    final base = labor > 0 ? labor : 0;

    return Money.round2(base * (technicianCommissionValue / 100));
  }

  /// `final_total − (comisión + refacciones)`.
  double get netProfit =>
      Money.round2(finalTotal - (technicianCommission + partsCost));
}
