import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Estado de la suscripción.
///
/// Los valores son los del enum del servidor (`App\Enums\SubscriptionStatus`):
/// `activo`, `expirado` y `suspendido`. La etiqueta visible siempre es la que
/// manda el servidor en `status_data.label`.
enum SubscriptionStatus {
  active(wire: 'activo'),
  expired(wire: 'expirado'),
  suspended(wire: 'suspendido'),
  unknown(wire: '');

  const SubscriptionStatus({required this.wire});

  final String wire;

  static SubscriptionStatus fromWire(String? value) {
    for (final status in SubscriptionStatus.values) {
      if (status.wire == value) {
        return status;
      }
    }

    return SubscriptionStatus.unknown;
  }
}

/// Estatus de un pago de la suscripción (`pending`, `approved`, `rejected`).
enum SubscriptionPaymentStatus {
  pending(wire: 'pending', label: 'Pendiente'),
  approved(wire: 'approved', label: 'Aprobado'),
  rejected(wire: 'rejected', label: 'Rechazado'),
  unknown(wire: '', label: 'Sin estatus');

  const SubscriptionPaymentStatus({required this.wire, required this.label});

  final String wire;
  final String label;

  static SubscriptionPaymentStatus fromWire(String? value) {
    for (final status in SubscriptionPaymentStatus.values) {
      if (status.wire == value) {
        return status;
      }
    }

    return SubscriptionPaymentStatus.unknown;
  }
}

/// Módulo del plan contratado.
class SubscriptionModule {
  const SubscriptionModule({
    required this.key,
    required this.name,
    required this.isActive,
  });

  factory SubscriptionModule.fromJson(Map<String, dynamic> json) =>
      SubscriptionModule(
        key: JsonReader.stringOr(json['key'], ''),
        name: JsonReader.stringOr(json['name'], ''),
        isActive: JsonReader.boolean(json['active']),
      );

  final String key;
  final String name;
  final bool isActive;
}

/// Límite del plan con su consumo.
///
/// `used` puede venir `null` cuando el servidor no sabe mapear el límite a un
/// contador de uso; en ese caso no se dibuja la barra de consumo.
class SubscriptionLimit {
  const SubscriptionLimit({
    required this.key,
    required this.name,
    required this.limit,
    required this.used,
  });

  factory SubscriptionLimit.fromJson(Map<String, dynamic> json) =>
      SubscriptionLimit(
        key: JsonReader.stringOr(json['key'], ''),
        name: JsonReader.stringOr(json['name'], ''),
        limit: JsonReader.integerOr(json['limit'], 0),
        used: JsonReader.integer(json['used']),
      );

  final String key;
  final String name;
  final int limit;
  final int? used;

  /// `2 de 3`; `null` si el servidor no informó el consumo.
  String? get usageLabel => used == null ? null : '$used de $limit';

  /// Proporción consumida (0..1) para la barra de progreso.
  double get usageRatio {
    if (used == null || limit <= 0) {
      return 0;
    }

    return (used! / limit).clamp(0, 1).toDouble();
  }

  bool get isAtLimit => used != null && limit > 0 && used! >= limit;
}

/// Contadores de uso de la suscripción (números, no texto).
class SubscriptionUsage {
  const SubscriptionUsage({
    this.branches = 0,
    this.users = 0,
    this.bankAccounts = 0,
    this.products = 0,
    this.cashRegisters = 0,
    this.printTemplates = 0,
    this.services = 0,
  });

  factory SubscriptionUsage.fromJson(Map<String, dynamic> json) =>
      SubscriptionUsage(
        branches: JsonReader.integerOr(json['branches'], 0),
        users: JsonReader.integerOr(json['users'], 0),
        bankAccounts: JsonReader.integerOr(json['bank_accounts'], 0),
        products: JsonReader.integerOr(json['products'], 0),
        cashRegisters: JsonReader.integerOr(json['cash_registers'], 0),
        printTemplates: JsonReader.integerOr(json['print_templates'], 0),
        services: JsonReader.integerOr(json['services'], 0),
      );

  final int branches;
  final int users;
  final int bankAccounts;
  final int products;
  final int cashRegisters;
  final int printTemplates;
  final int services;

  /// Filas etiqueta-valor del bloque informativo del plan.
  List<(String, int)> get rows => <(String, int)>[
    ('Sucursales', branches),
    ('Usuarios', users),
    ('Cuentas bancarias', bankAccounts),
    ('Productos', products),
    ('Cajas registradoras', cashRegisters),
    ('Plantillas de impresión', printTemplates),
    ('Servicios', services),
  ];
}

/// Datos del estado de la suscripción (`status_data`).
///
/// La etiqueta la decide el servidor ("Activa", "Por vencer", "Expirada").
class SubscriptionStatusData {
  const SubscriptionStatusData({
    required this.label,
    required this.expiresAt,
    required this.daysLeft,
    required this.isExpired,
    required this.warning,
  });

  factory SubscriptionStatusData.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatusData(
        label: JsonReader.stringOr(json['label'], ''),
        expiresAt: AppFormatters.parse(json['expires_at']),
        daysLeft: JsonReader.integer(json['days_left']),
        isExpired: JsonReader.boolean(json['is_expired']),
        warning: JsonReader.string(json['warning']),
      );

  const SubscriptionStatusData.empty()
    : label = '',
      expiresAt = null,
      daysLeft = null,
      isExpired = false,
      warning = null;

  final String label;
  final DateTime? expiresAt;
  final int? daysLeft;
  final bool isExpired;

  /// Banner de suscripción por vencer/expirada (`subscriptionWarning` web).
  final String? warning;

  /// Vence en 7 días o menos y todavía no expiró.
  bool get isExpiringSoon =>
      !isExpired && warning != null && (daysLeft ?? 0) <= 7;

  bool get isWarning => isExpired || isExpiringSoon;

  /// `Vence el 18 oct 2026 (quedan 30 días)`.
  String? get expiresLabel {
    if (expiresAt == null) {
      return null;
    }

    final date = AppFormatters.date(expiresAt);
    final days = daysLeft;

    if (days == null || days <= 0) {
      return 'Vence el $date';
    }

    return 'Vence el $date (quedan $days días)';
  }
}

/// Pago de la suscripción (`pending_payment`, `last_rejected_payment`).
///
/// `amount` llega como **número** (el servicio lo serializa con `(float)`).
class SubscriptionPayment {
  const SubscriptionPayment({
    required this.id,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.folio,
    required this.createdAt,
  });

  factory SubscriptionPayment.fromJson(Map<String, dynamic> json) =>
      SubscriptionPayment(
        id: JsonReader.integerOr(json['id'], 0),
        amount: Money.toDouble(json['amount']),
        status: SubscriptionPaymentStatus.fromWire(
          JsonReader.string(json['status']),
        ),
        paymentMethod: JsonReader.string(json['payment_method']),
        folio: JsonReader.string(json['folio']),
        createdAt: AppFormatters.parse(json['created_at']),
      );

  final int id;
  final double amount;
  final SubscriptionPaymentStatus status;
  final String? paymentMethod;
  final String? folio;
  final DateTime? createdAt;

  String get amountLabel => Money.format(amount);
}

/// Pago dentro del historial de versiones del plan.
class SubscriptionHistoryPayment {
  const SubscriptionHistoryPayment({
    required this.id,
    required this.folio,
    required this.status,
    required this.paidAt,
    required this.canRequestInvoice,
  });

  factory SubscriptionHistoryPayment.fromJson(Map<String, dynamic> json) =>
      SubscriptionHistoryPayment(
        // El historial real **no** incluye el id del pago (ver README,
        // discrepancias): se lee de forma tolerante para cuando el servidor lo
        // agregue, y la acción "Solicitar factura" solo aparece si llega.
        id: JsonReader.integer(json['id']),
        folio: JsonReader.string(json['folio']),
        status: SubscriptionPaymentStatus.fromWire(
          JsonReader.string(json['status']),
        ),
        paidAt: AppFormatters.parse(json['paid_at']),
        canRequestInvoice: JsonReader.boolean(json['can_request_invoice']),
      );

  /// Id del pago (`null` mientras el servidor no lo incluya en el historial).
  final int? id;

  final String? folio;
  final SubscriptionPaymentStatus status;
  final DateTime? paidAt;

  /// El servidor habilita la acción "Solicitar factura" solo en pagos aprobados
  /// sin factura pedida.
  final bool canRequestInvoice;

  /// Se puede llamar `POST /subscription/payments/{id}/request-invoice`.
  bool get isInvoiceRequestable => canRequestInvoice && id != null && id! > 0;
}

/// Una versión del plan con su pago.
///
/// `total` es **texto decimal** (`"439.00"`) y `version` es la posición de la
/// versión (1 = la más antigua), como documenta el contrato §11b.5.
class SubscriptionHistoryEntry {
  const SubscriptionHistoryEntry({
    required this.version,
    required this.createdAt,
    required this.total,
    required this.payment,
  });

  factory SubscriptionHistoryEntry.fromJson(Map<String, dynamic> json) =>
      SubscriptionHistoryEntry(
        version: JsonReader.integerOr(json['version'], 0),
        createdAt: AppFormatters.parse(json['created_at']),
        total: Money.toNullableDouble(json['total']),
        payment: json['payment'] == null
            ? null
            : SubscriptionHistoryPayment.fromJson(
                JsonReader.toMap(json['payment']),
              ),
      );

  final int version;
  final DateTime? createdAt;

  /// Monto de la versión en texto decimal (`"439.00"` → `439.0`).
  final double? total;

  final SubscriptionHistoryPayment? payment;

  /// El historial no incluye el id del pago de la suscripción: la acción
  /// "Solicitar factura" solo se ofrece cuando el servidor la habilita.
  bool get canRequestInvoice => payment?.canRequestInvoice ?? false;

  String get amountLabel => Money.format(total);
}

/// Datos generales de la suscripción (`subscription` del payload).
class SubscriptionDetail {
  const SubscriptionDetail({
    required this.id,
    required this.commercialName,
    required this.businessName,
    required this.status,
    required this.taxId,
    required this.contactPhone,
    required this.contactEmail,
    required this.address,
    required this.slug,
  });

  factory SubscriptionDetail.fromJson(Map<String, dynamic> json) =>
      SubscriptionDetail(
        id: JsonReader.integerOr(json['id'], 0),
        commercialName: JsonReader.stringOr(json['commercial_name'], ''),
        businessName: JsonReader.string(json['business_name']),
        status: SubscriptionStatus.fromWire(JsonReader.string(json['status'])),
        taxId: JsonReader.string(json['tax_id']),
        contactPhone: JsonReader.string(json['contact_phone']),
        contactEmail: JsonReader.string(json['contact_email']),
        address: JsonReader.string(JsonReader.toMap(json['address'])['text']),
        slug: JsonReader.string(json['slug']),
      );

  final int id;
  final String commercialName;
  final String? businessName;
  final SubscriptionStatus status;
  final String? taxId;
  final String? contactPhone;
  final String? contactEmail;

  /// Dirección como texto (`address.text`).
  final String? address;

  final String? slug;

  /// Cuerpo de `PUT /subscription` con los campos del contrato §11b.5.
  Map<String, dynamic> toUpdatePayload({
    String? commercialName,
    String? businessName,
    String? contactPhone,
    String? address,
  }) => <String, dynamic>{
    'commercial_name': commercialName ?? this.commercialName,
    'business_name': businessName ?? this.businessName,
    'contact_phone': contactPhone ?? this.contactPhone,
    'address': address ?? this.address,
  };
}

/// Plan contratado (módulos y límites).
class SubscriptionPlan {
  const SubscriptionPlan({required this.modules, required this.limits});

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      SubscriptionPlan(
        modules: JsonReader.toMapList(
          json['modules'],
        ).map(SubscriptionModule.fromJson).toList(growable: false),
        limits: JsonReader.toMapList(
          json['limits'],
        ).map(SubscriptionLimit.fromJson).toList(growable: false),
      );

  const SubscriptionPlan.empty()
    : modules = const <SubscriptionModule>[],
      limits = const <SubscriptionLimit>[];

  final List<SubscriptionModule> modules;
  final List<SubscriptionLimit> limits;
}

/// Pantalla completa de suscripción (`GET /subscription`, solo propietario).
class SubscriptionOverview {
  const SubscriptionOverview({
    required this.subscription,
    required this.plan,
    required this.usage,
    required this.statusData,
    required this.pendingPayment,
    required this.lastRejectedPayment,
    required this.fiscalDocumentUrl,
    required this.history,
  });

  factory SubscriptionOverview.fromJson(Map<String, dynamic> json) =>
      SubscriptionOverview(
        subscription: SubscriptionDetail.fromJson(
          JsonReader.toMap(json['subscription']),
        ),
        plan: SubscriptionPlan.fromJson(JsonReader.toMap(json['plan'])),
        usage: SubscriptionUsage.fromJson(JsonReader.toMap(json['usage'])),
        statusData: SubscriptionStatusData.fromJson(
          JsonReader.toMap(json['status_data']),
        ),
        pendingPayment: json['pending_payment'] == null
            ? null
            : SubscriptionPayment.fromJson(
                JsonReader.toMap(json['pending_payment']),
              ),
        lastRejectedPayment: json['last_rejected_payment'] == null
            ? null
            : SubscriptionPayment.fromJson(
                JsonReader.toMap(json['last_rejected_payment']),
              ),
        fiscalDocumentUrl: JsonReader.string(json['fiscal_document_url']),
        history: JsonReader.toMapList(
          json['history'],
        ).map(SubscriptionHistoryEntry.fromJson).toList(growable: false),
      );

  final SubscriptionDetail subscription;
  final SubscriptionPlan plan;
  final SubscriptionUsage usage;
  final SubscriptionStatusData statusData;
  final SubscriptionPayment? pendingPayment;
  final SubscriptionPayment? lastRejectedPayment;

  /// Constancia de situación fiscal subida (`POST /subscription/documents`).
  final String? fiscalDocumentUrl;

  /// Versiones del plan, de la más reciente a la más antigua.
  final List<SubscriptionHistoryEntry> history;

  bool get hasFiscalDocument =>
      fiscalDocumentUrl != null && fiscalDocumentUrl!.trim().isNotEmpty;
}
