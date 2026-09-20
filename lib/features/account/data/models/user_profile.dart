import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';

/// Perfil del usuario autenticado (`GET /profile`, contrato §11b.4).
///
/// `has_photo` es el campo que decide si hay foto: `profile_photo_url` puede
/// traer el avatar generado por el servidor aunque el usuario no haya subido una.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerifiedAt,
    required this.phone,
    required this.profilePhotoUrl,
    required this.hasPhoto,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    email: JsonReader.stringOr(json['email'], ''),
    emailVerifiedAt: AppFormatters.parse(json['email_verified_at']),
    phone: JsonReader.string(json['phone']),
    profilePhotoUrl: JsonReader.string(json['profile_photo_url']),
    hasPhoto: JsonReader.boolean(json['has_photo']),
  );

  final int id;
  final String name;
  final String email;
  final DateTime? emailVerifiedAt;
  final String? phone;

  /// URL de la foto (o del avatar generado por el servidor).
  final String? profilePhotoUrl;

  /// `true` solo si el usuario subió una foto propia.
  final bool hasPhoto;

  bool get isEmailVerified => emailVerifiedAt != null;

  /// Foto que debe pintarse: la subida por el usuario, no el avatar generado.
  String? get realPhotoUrl {
    if (!hasPhoto) {
      return null;
    }

    final url = profilePhotoUrl?.trim();

    return (url == null || url.isEmpty) ? null : url;
  }

  /// `true` si el correo escrito cambia el actual (dispara el código OTP).
  bool changesEmail(String candidate) =>
      candidate.trim().toLowerCase() != email.trim().toLowerCase();
}

/// Resultado de `PUT /profile`.
class ProfileUpdateResult {
  const ProfileUpdateResult({
    required this.profile,
    required this.emailVerificationSent,
    required this.message,
  });

  factory ProfileUpdateResult.fromJson(Map<String, dynamic> json) =>
      ProfileUpdateResult(
        profile: UserProfile.fromJson(JsonReader.toMap(json['user'])),
        emailVerificationSent: JsonReader.boolean(
          json['email_verification_sent'],
        ),
        message: JsonReader.stringOr(json['message'], ''),
      );

  final UserProfile profile;

  /// `true` cuando cambió el correo: el servidor mandó el código de verificación.
  final bool emailVerificationSent;

  /// `message` del servidor (ya viene en español).
  final String message;
}

/// Resultado de `DELETE /profile/photo`.
class ProfilePhotoDeleteResult {
  const ProfilePhotoDeleteResult({
    required this.profile,
    required this.message,
  });

  factory ProfilePhotoDeleteResult.fromJson(Map<String, dynamic> json) =>
      ProfilePhotoDeleteResult(
        profile: UserProfile.fromJson(JsonReader.toMap(json['user'])),
        message: JsonReader.stringOr(json['message'], ''),
      );

  final UserProfile profile;
  final String message;
}

/// Respuesta de los endpoints que solo devuelven `message`
/// (`PUT /profile/password`, `POST /profile/logout-other-devices`,
/// `PUT /subscription`, `POST /subscription/documents`,
/// `POST /subscription/payments/{id}/request-invoice`).
class AccountMessageResult {
  const AccountMessageResult({required this.message, this.extra = const <String, dynamic>{}});

  factory AccountMessageResult.fromJson(Map<String, dynamic> json) =>
      AccountMessageResult(
        message: JsonReader.stringOr(json['message'], ''),
        extra: json,
      );

  /// Texto del servidor (ya en español).
  final String message;

  /// Cuerpo completo, por si el endpoint devuelve datos extra
  /// (`fiscal_document_url` en `POST /subscription/documents`).
  final Map<String, dynamic> extra;

  /// URL del documento fiscal actualizado, si la respuesta la trae.
  String? get fiscalDocumentUrl => JsonReader.string(extra['fiscal_document_url']);
}
