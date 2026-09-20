import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/utils/evidence_image.dart';
import '../../../core/utils/json_reader.dart';
import 'models/branch_switch_result.dart';
import 'models/notification_counters.dart';
import 'models/subscription_overview.dart';
import 'models/support_content.dart';
import 'models/user_profile.dart';

/// Cuenta: sucursal, notificaciones, soporte, perfil y suscripción.
///
/// Todas las reglas (permiso `system.branches.switch`, propietario de la
/// suscripción, unicidad del correo, verificación por código, contraseña actual)
/// las aplica el servidor. Aquí solo se arma la petición y se tipa la respuesta;
/// el `message` de cada error se muestra tal cual (regla 6 del encargo).
class AccountRepository {
  AccountRepository({required this.api});

  final ApiClient api;

  /// `GET /notifications` — los cinco contadores de la campana.
  ///
  /// El servidor **siempre** devuelve los cinco (en `0` si el usuario no tiene
  /// acceso a ventas).
  Future<NotificationCounters> fetchNotifications() async {
    final data = await api.getJson(ApiEndpoints.notifications);

    return NotificationCounters.fromJson(data);
  }

  /// `GET /support` — contenido del Centro de soporte (`config/support.php`).
  Future<SupportContent> fetchSupport() async {
    final data = await api.getJson(ApiEndpoints.support);

    return SupportContent.fromJson(data);
  }

  /// `PUT /branch/switch/{branchId}` — cambia la sucursal del usuario.
  ///
  /// La sucursal va en la URL (sin body) y el usuario solo puede moverse dentro
  /// de su suscripción (`403 branch_out_of_scope`).
  Future<BranchSwitchResult> switchBranch(int branchId) async {
    final data = await api.putJson(ApiEndpoints.switchBranch(branchId));

    return BranchSwitchResult.fromJson(data);
  }

  /// `GET /profile` — datos personales del usuario autenticado.
  ///
  /// La respuesta también trae `context`; la app **no** lo aplica aquí porque el
  /// contexto de sesión se refresca con `GET /auth/me` (una sola fuente).
  Future<UserProfile> fetchProfile() async {
    final data = await api.getJson(ApiEndpoints.profile);

    return UserProfile.fromJson(JsonReader.toMap(data['user']));
  }

  /// `PUT /profile` — nombre, correo y (opcional) foto.
  ///
  /// Con foto viaja como `multipart/form-data` (máx. 1 MB, contrato §11b.4); sin
  /// foto como JSON, para no convertir a texto los campos del payload. Si el
  /// correo cambia, el servidor envía el código de verificación
  /// (`email_verification_sent: true`).
  Future<ProfileUpdateResult> updateProfile({
    required String name,
    required String email,
    EvidenceImage? photo,
  }) async {
    final image = photo;

    if (image == null) {
      final data = await api.putJson(
        ApiEndpoints.profile,
        data: <String, dynamic>{
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
        },
      );

      return ProfileUpdateResult.fromJson(data);
    }

    final form = FormData()
      ..fields.add(MapEntry<String, String>('name', name.trim()))
      ..fields.add(
        MapEntry<String, String>('email', email.trim().toLowerCase()),
      )
      ..files.add(
        MapEntry<String, MultipartFile>(
          'photo',
          MultipartFile.fromBytes(
            image.bytes,
            filename: image.fileName,
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ),
      );

    final data = await api.postMultipart(
      ApiEndpoints.profile,
      method: 'PUT',
      data: form,
    );

    return ProfileUpdateResult.fromJson(data);
  }

  /// `DELETE /profile/photo` — elimina la foto de perfil.
  Future<ProfilePhotoDeleteResult> deleteProfilePhoto() async {
    final data = await api.deleteJson(ApiEndpoints.profilePhoto);

    return ProfilePhotoDeleteResult.fromJson(data);
  }

  /// `PUT /profile/password` — cambio de contraseña.
  ///
  /// Si la contraseña actual no coincide, el servidor responde
  /// `422 invalid_current_password` y la app muestra ese `message`.
  Future<AccountMessageResult> updatePassword({
    required String currentPassword,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = await api.putJson(
      ApiEndpoints.profilePassword,
      data: <String, dynamic>{
        'current_password': currentPassword,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );

    return AccountMessageResult.fromJson(data);
  }

  /// `POST /profile/logout-other-devices` — cierra las demás sesiones.
  ///
  /// La contraseña confirma la acción; el token de **este** teléfono sigue vivo.
  Future<AccountMessageResult> logoutOtherDevices(String password) async {
    final data = await api.postJson(
      ApiEndpoints.logoutOtherDevices,
      data: <String, dynamic>{'password': password},
    );

    return AccountMessageResult.fromJson(data);
  }

  /// `GET /subscription` — solo el propietario (los empleados reciben `403`).
  Future<SubscriptionOverview> fetchSubscription() async {
    final data = await api.getJson(ApiEndpoints.subscription);

    return SubscriptionOverview.fromJson(data);
  }

  /// `PUT /subscription` — datos generales (solo propietario).
  Future<AccountMessageResult> updateSubscription(
    Map<String, dynamic> payload,
  ) async {
    final data = await api.putJson(ApiEndpoints.subscription, data: payload);

    return AccountMessageResult.fromJson(data);
  }

  /// `POST /subscription/documents` (multipart) — constancia de situación
  /// fiscal. El servidor acepta `pdf,jpg,jpeg,png,webp` de 2 MB; esta app envía
  /// la constancia como **imagen** (el stack aprobado no trae selector de
  /// archivos, ver README).
  Future<AccountMessageResult> uploadFiscalDocument(
    EvidenceImage document,
  ) async {
    final form = FormData()
      ..files.add(
        MapEntry<String, MultipartFile>(
          'fiscal_document',
          MultipartFile.fromBytes(
            document.bytes,
            filename: document.fileName,
            contentType: DioMediaType('image', 'jpeg'),
          ),
        ),
      );

    final data = await api.postMultipart(
      ApiEndpoints.subscriptionDocuments,
      data: form,
    );

    return AccountMessageResult.fromJson(data);
  }

  /// `POST /subscription/payments/{paymentId}/request-invoice`.
  ///
  /// Solo pagos aprobados sin factura pedida (`403 payment_not_approved`).
  Future<AccountMessageResult> requestInvoice(int paymentId) async {
    final data = await api.postJson(
      ApiEndpoints.requestSubscriptionInvoice(paymentId),
    );

    return AccountMessageResult.fromJson(data);
  }
}
