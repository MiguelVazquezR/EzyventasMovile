import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/paginated.dart';
import '../../../core/utils/evidence_image.dart';
import '../../../core/utils/json_reader.dart';
import '../../../core/utils/uuid_generator.dart';
import '../../pos/data/models/payment_draft.dart';
import 'models/service_order_detail.dart';
import 'models/service_order_filters.dart';
import 'models/service_order_form.dart';
import 'models/service_order_mutation_results.dart';
import 'models/service_order_summary.dart';

/// Órdenes de servicio: listado, detalle, alta/edición, estatus, diagnóstico,
/// anticipos y borrado.
///
/// El servidor decide el folio, la venta vinculada, la deuda del cliente, el
/// stock de las refacciones y el saldo; la app solo arma la petición y tipa la
/// respuesta. Los cuerpos con fotos viajan como `multipart/form-data` (igual que
/// la web) y los que no llevan fotos como JSON, para no convertir a texto los
/// números y booleanos del payload.
class ServiceOrdersRepository {
  ServiceOrdersRepository({required this.api});

  final ApiClient api;

  /// `GET /service-orders` — lista de trabajo de la sucursal del token.
  Future<Paginated<ServiceOrderSummary>> fetchServiceOrders({
    ServiceOrderFilters filters = const ServiceOrderFilters(),
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await api.getJson(
      ApiEndpoints.serviceOrders,
      query: <String, dynamic>{
        ...filters.toQuery(),
        'page': page,
        'per_page': perPage,
      },
    );

    return Paginated<ServiceOrderSummary>.fromJson(
      data,
      ServiceOrderSummary.fromJson,
    );
  }

  /// `GET /service-orders/{id}` — detalle completo (404 si es de otra sucursal).
  Future<ServiceOrderDetail> fetchServiceOrder(int serviceOrderId) async {
    final data = await api.getJson(ApiEndpoints.serviceOrder(serviceOrderId));

    return ServiceOrderDetail.fromJson(data);
  }


  /// `POST /service-orders` — alta con evidencias iniciales.
  ///
  /// Exige sesión de caja abierta de la sucursal (`422 session_required`).
  Future<ServiceOrderMutationResult> createServiceOrder({
    required ServiceOrderFormData form,
    required int sessionId,
  }) async {
    final hasPhotos = form.evidence.isNotEmpty;
    final fields = form.toFields(
      isUpdate: false,
      multipart: hasPhotos,
      sessionId: sessionId,
    );

    final data = hasPhotos
        ? await api.postMultipart(
            ApiEndpoints.serviceOrders,
            data: form.toMultipart(fields),
          )
        : await api.postJson(ApiEndpoints.serviceOrders, data: fields);

    return ServiceOrderMutationResult.fromJson(data);
  }

  /// `PUT /service-orders/{id}` — edición (stock por diferencia, deuda y venta).
  Future<ServiceOrderMutationResult> updateServiceOrder({
    required int serviceOrderId,
    required ServiceOrderFormData form,
  }) async {
    final hasPhotos = form.evidence.isNotEmpty;
    final fields = form.toFields(isUpdate: true, multipart: hasPhotos);

    final data = hasPhotos
        ? await api.postMultipart(
            ApiEndpoints.serviceOrder(serviceOrderId),
            method: 'PUT',
            data: form.toMultipart(fields),
          )
        : await api.putJson(
            ApiEndpoints.serviceOrder(serviceOrderId),
            data: fields,
          );

    return ServiceOrderMutationResult.fromJson(data);
  }

  /// `PATCH /service-orders/{id}/status`.
  ///
  /// El `422` trae el motivo real en `errors.status[0]` (estatus repetido o
  /// inválido): la UI lo lee de ahí.
  Future<ServiceOrderStatusResult> updateStatus({
    required int serviceOrderId,
    required String status,
    String? clientUuid,
  }) async {
    final data = await api.patchJson(
      ApiEndpoints.serviceOrderStatus(serviceOrderId),
      data: <String, dynamic>{
        'status': status,
        'client_uuid': clientUuid ?? UuidGenerator.v4(),
      },
    );

    return ServiceOrderStatusResult.fromJson(data);
  }

  /// `POST /service-orders/{id}/diagnosis` (multipart).
  ///
  /// Si [diagnosis] es `null`, el diagnóstico previo **se conserva**; con `''`
  /// se borra. Las fotos se agregan a la colección
  /// `closing-service-order-evidence`.
  Future<ServiceOrderMutationResult> saveDiagnosis({
    required int serviceOrderId,
    String? diagnosis,
    List<EvidenceImage> images = const <EvidenceImage>[],
  }) async {
    final form = FormData();

    form.fields.add(
      MapEntry<String, String>('client_uuid', UuidGenerator.v4()),
    );

    if (diagnosis != null) {
      form.fields.add(
        MapEntry<String, String>('technician_diagnosis', diagnosis),
      );
    }

    for (var index = 0; index < images.length; index++) {
      final image = images[index];

      form.files.add(
        MapEntry<String, MultipartFile>(
          'closing_evidence_images[$index]',
          MultipartFile.fromBytes(
            image.bytes,
            filename: image.fileName,
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ),
      );
    }

    final data = await api.postMultipart(
      ApiEndpoints.serviceOrderDiagnosis(serviceOrderId),
      data: form,
    );

    return ServiceOrderMutationResult.fromJson(data);
  }

  /// `POST /service-orders/{id}/ensure-transaction`.
  ///
  /// Crea la venta vinculada de las órdenes antiguas (devuelve el id existente
  /// si ya la tienen, sin duplicar).
  Future<int> ensureTransaction(int serviceOrderId) async {
    final data = await api.postJson(
      ApiEndpoints.serviceOrderEnsureTransaction(serviceOrderId),
    );

    return JsonReader.integerOr(data['transaction_id'], 0);
  }

  /// `POST /service-orders/{id}/payments` — anticipo de la orden.
  ///
  /// Mismo cuerpo que el abono de una venta; exige sesión de caja abierta
  /// (`422 session_required`).
  Future<ServiceOrderPaymentResult> addPayment({
    required int serviceOrderId,
    required int sessionId,
    bool useBalance = false,
    List<PaymentDraft> payments = const <PaymentDraft>[],
    String? clientUuid,
  }) async {
    final data = await api.postJson(
      ApiEndpoints.serviceOrderPayments(serviceOrderId),
      data: <String, dynamic>{
        'client_uuid': clientUuid ?? UuidGenerator.v4(),
        'cash_register_session_id': sessionId,
        'use_balance': useBalance,
        'payments': payments
            .where((payment) => payment.amount > 0)
            .map((payment) => payment.toJson())
            .toList(growable: false),
      },
    );

    return ServiceOrderPaymentResult.fromJson(data);
  }

  /// `DELETE /service-orders/{id}` — elimina la orden y su venta vinculada.
  /// Responde `204` sin cuerpo.
  Future<void> deleteServiceOrder(int serviceOrderId) async {
    await api.deleteJson(ApiEndpoints.serviceOrder(serviceOrderId));
  }
}
