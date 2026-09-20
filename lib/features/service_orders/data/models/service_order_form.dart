import 'package:dio/dio.dart';

import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/evidence_image.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/uuid_generator.dart';
import 'service_order_detail.dart';
import 'service_order_item_draft.dart';

/// Tipo de descuento de la orden (`discount_type`).
enum ServiceOrderDiscountType {
  fixed('fixed', 'Monto fijo'),
  percentage('percentage', 'Porcentaje');

  const ServiceOrderDiscountType(this.value, this.label);

  final String value;
  final String label;

  static ServiceOrderDiscountType fromValue(String? value) =>
      value == 'percentage'
      ? ServiceOrderDiscountType.percentage
      : ServiceOrderDiscountType.fixed;
}

/// Tipo de comisión del técnico (`technician_commission_type`).
enum TechnicianCommissionType {
  percentage('percentage', 'Porcentaje'),
  fixed('fixed', 'Monto fijo');

  const TechnicianCommissionType(this.value, this.label);

  final String value;
  final String label;

  static TechnicianCommissionType fromValue(String? value) =>
      value == 'fixed' ? TechnicianCommissionType.fixed : percentage;
}

/// Datos del formulario de alta/edición de una orden de servicio.
///
/// El servidor es el que decide el folio, la venta vinculada, la deuda del
/// cliente y el stock; la app solo arma el payload con los mismos campos que el
/// formulario web (`01-contrato-api-v1.md` §9) y calcula los tres totales que el
/// contrato pide explícitamente (`subtotal`, `discount_amount`, `final_total`).
class ServiceOrderFormData {
  const ServiceOrderFormData({
    this.customerId,
    this.createCustomer = false,
    this.creditLimit = 0,
    this.customerName = '',
    this.customerEmail,
    this.customerPhone,
    this.addressStreet,
    this.addressCity,
    this.itemDescription = '',
    this.reportedProblems = '',
    this.promisedAt,
    this.assignTechnician = false,
    this.technicianName,
    this.commissionType = TechnicianCommissionType.percentage,
    this.commissionValue = 0,
    this.technicianDiagnosis,
    this.items = const <ServiceOrderItemDraft>[],
    this.discountType = ServiceOrderDiscountType.fixed,
    this.discountValue = 0,
    this.customFields = const <String, dynamic>{},
    this.evidence = const <EvidenceImage>[],
    this.deletedMediaIds = const <int>[],
  });

  /// Cliente existente (`null` = se captura a mano o se da de alta al vuelo).
  final int? customerId;

  /// `create_customer`: dar de alta al cliente dentro de la misma petición.
  final bool createCustomer;

  /// Obligatorio solo cuando [createCustomer] es `true`.
  final double creditLimit;

  final String customerName;
  final String? customerEmail;
  final String? customerPhone;
  final String? addressStreet;
  final String? addressCity;

  /// Equipo recibido (`item_description`, máx. 255).
  final String itemDescription;

  /// Fallas que reporta el cliente.
  final String reportedProblems;

  /// Promesa de entrega (se envía como `YYYY-MM-DD`).
  final DateTime? promisedAt;

  final bool assignTechnician;
  final String? technicianName;
  final TechnicianCommissionType commissionType;
  final double commissionValue;

  /// Diagnóstico del técnico (solo lo acepta `PUT`).
  final String? technicianDiagnosis;

  final List<ServiceOrderItemDraft> items;
  final ServiceOrderDiscountType discountType;
  final double discountValue;

  /// Valores de los campos personalizados (`custom_fields`).
  final Map<String, dynamic> customFields;

  /// Fotos nuevas (`initial_evidence_images[]`, máximo 5).
  final List<EvidenceImage> evidence;

  /// Evidencias existentes que se borran (`deleted_media_ids[]`, solo `PUT`).
  final List<int> deletedMediaIds;

  /// Suma de las líneas (`subtotal`).
  double get subtotal =>
      Money.round2(items.fold<double>(0, (sum, item) => sum + item.lineTotal));

  /// Descuento aplicado, nunca mayor al subtotal.
  double get discountAmount {
    if (discountValue <= 0) {
      return 0;
    }

    final raw = discountType == ServiceOrderDiscountType.fixed
        ? discountValue
        : subtotal * (discountValue / 100);
    final capped = raw > subtotal ? subtotal : raw;

    return Money.round2(capped);
  }

  /// `subtotal − discount_amount`.
  double get finalTotal => Money.round2(subtotal - discountAmount);

  /// Campos que el servidor exige para guardar (el botón se deshabilita hasta
  /// que estén completos; el servidor sigue validando).
  bool get isComplete {
    if (itemDescription.trim().isEmpty || reportedProblems.trim().isEmpty) {
      return false;
    }

    if (customerName.trim().isEmpty) {
      return false;
    }

    if (assignTechnician && (technicianName ?? '').trim().isEmpty) {
      return false;
    }

    return true;
  }
}

/// `multipart/form-data` exige `1`/`0` en los booleanos (Laravel no acepta la
/// cadena `"true"`); en JSON viaja el booleano real.
Object _boolField(bool value, {required bool multipart}) =>
    multipart ? (value ? 1 : 0) : value;

String? _blankToNull(String? value) {
  final trimmed = value?.trim();

  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Cuerpo de la petición con las claves exactas del contrato.
extension ServiceOrderFormPayload on ServiceOrderFormData {
  /// [multipart] usa claves con corchetes (`items[0][quantity]`); en JSON los
  /// objetos van anidados. [sessionId] solo se envía al crear la orden y
  /// [isUpdate] habilita `deleted_media_ids` y `technician_diagnosis`.
  Map<String, dynamic> toFields({
    required bool isUpdate,
    required bool multipart,
    int? sessionId,
    String? clientUuid,
  }) {
    final fields = <String, dynamic>{
      'customer_name': customerName.trim(),
      'customer_email': _blankToNull(customerEmail),
      'customer_phone': _blankToNull(customerPhone),
      'item_description': itemDescription.trim(),
      'reported_problems': reportedProblems.trim(),
      'assign_technician': _boolField(assignTechnician, multipart: multipart),
      'subtotal': subtotal,
      'discount_type': discountType.value,
      'discount_value': discountValue,
      'discount_amount': discountAmount,
      'final_total': finalTotal,
      'client_uuid': clientUuid ?? UuidGenerator.v4(),
    };

    if ((customerId ?? 0) > 0) {
      fields['customer_id'] = customerId;
    }

    if (!isUpdate) {
      // `create_customer` es obligatorio al crear la orden (contrato §9) y
      // `credit_limit` solo cuando se da de alta al cliente.
      fields['create_customer'] = _boolField(
        createCustomer,
        multipart: multipart,
      );

      if (createCustomer) {
        fields['credit_limit'] = creditLimit;
      }
    }

    final street = _blankToNull(addressStreet);
    final city = _blankToNull(addressCity);

    if (street != null || city != null) {
      if (multipart) {
        if (street != null) {
          fields['customer_address[street]'] = street;
        }
        if (city != null) {
          fields['customer_address[city]'] = city;
        }
      } else {
        fields['customer_address'] = <String, dynamic>{
          'street': ?street,
          'city': ?city,
        };
      }
    }

    if (promisedAt != null) {
      fields['promised_at'] = AppFormatters.apiDate(promisedAt!);
    }

    if (assignTechnician) {
      fields['technician_name'] = _blankToNull(technicianName);
      fields['technician_commission_type'] = commissionType.value;
      fields['technician_commission_value'] = commissionValue;
    }

    if (items.isNotEmpty) {
      if (multipart) {
        for (var index = 0; index < items.length; index++) {
          fields.addAll(items[index].toMultipartFields(index));
        }
      } else {
        fields['items'] = items
            .map((item) => item.toJson())
            .toList(growable: false);
      }
    }

    if (customFields.isNotEmpty) {
      final nested = <String, dynamic>{};

      customFields.forEach((key, value) {
        final stored = value is bool
            ? _boolField(value, multipart: multipart)
            : value;

        if (multipart) {
          fields['custom_fields[$key]'] = stored;
        } else {
          nested[key] = stored;
        }
      });

      if (nested.isNotEmpty) {
        fields['custom_fields'] = nested;
      }
    }

    if (isUpdate) {
      if (technicianDiagnosis != null) {
        fields['technician_diagnosis'] = technicianDiagnosis;
      }

      if (deletedMediaIds.isNotEmpty) {
        if (multipart) {
          for (var index = 0; index < deletedMediaIds.length; index++) {
            fields['deleted_media_ids[$index]'] = deletedMediaIds[index];
          }
        } else {
          fields['deleted_media_ids'] = deletedMediaIds;
        }
      }
    } else if (sessionId != null) {
      fields['cash_register_session_id'] = sessionId;
    }

    return fields;
  }

  /// `FormData` con las fotos adjuntas (`initial_evidence_images[]`).
  FormData toMultipart(Map<String, dynamic> fields) {
    final form = FormData.fromMap(fields);

    for (var index = 0; index < evidence.length; index++) {
      final image = evidence[index];

      form.files.add(
        MapEntry<String, MultipartFile>(
          'initial_evidence_images[$index]',
          MultipartFile.fromBytes(
            image.bytes,
            filename: image.fileName,
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ),
      );
    }

    return form;
  }
}

/// Precarga el formulario con una orden existente (edición).
ServiceOrderFormData formDataFromDetail(ServiceOrderDetail detail) =>
    ServiceOrderFormData(
      customerId: detail.customer?.id,
      customerName: detail.customerLabel,
      customerEmail: detail.customerEmail,
      customerPhone: detail.customer?.phone,
      addressStreet: detail.customerAddress?.street,
      addressCity: detail.customerAddress?.city,
      itemDescription: detail.itemDescription,
      reportedProblems: detail.reportedProblems,
      promisedAt: detail.promisedAt,
      assignTechnician: detail.hasTechnician,
      technicianName: detail.technicianName,
      commissionType: TechnicianCommissionType.fromValue(
        detail.technicianCommissionType,
      ),
      commissionValue: detail.technicianCommissionValue,
      technicianDiagnosis: detail.technicianDiagnosis,
      items: detail.items
          .map(ServiceOrderItemDraft.fromItem)
          .toList(growable: false),
      discountType: ServiceOrderDiscountType.fromValue(detail.discountType),
      discountValue: detail.discountValue,
      customFields: detail.customFields,
    );
