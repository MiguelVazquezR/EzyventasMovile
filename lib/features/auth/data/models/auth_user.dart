import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/json_reader.dart';
import 'branch_summary.dart';

/// Usuario autenticado tal como lo entrega `login` / `me`.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.profilePhotoUrl,
    required this.isActive,
    required this.emailVerifiedAt,
    required this.branchId,
    required this.branch,
    required this.subscription,
    required this.isSubscriptionOwner,
    required this.permissions,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: JsonReader.integerOr(json['id'], 0),
      name: JsonReader.stringOr(json['name'], ''),
      email: JsonReader.stringOr(json['email'], ''),
      phone: JsonReader.string(json['phone']),
      profilePhotoUrl: JsonReader.string(json['profile_photo_url']),
      isActive: JsonReader.boolean(json['is_active']),
      emailVerifiedAt: AppFormatters.parse(json['email_verified_at']),
      branchId: JsonReader.integer(json['branch_id']),
      branch: json['branch'] == null
          ? null
          : BranchSummary.fromJson(JsonReader.toMap(json['branch'])),
      subscription: json['subscription'] == null
          ? null
          : SubscriptionSummary.fromJson(JsonReader.toMap(json['subscription'])),
      isSubscriptionOwner: JsonReader.boolean(json['is_subscription_owner']),
      permissions: JsonReader.stringList(json['permissions']),
    );
  }

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? profilePhotoUrl;
  final bool isActive;
  final DateTime? emailVerifiedAt;
  final int? branchId;
  final BranchSummary? branch;
  final SubscriptionSummary? subscription;

  /// Propietario de la suscripción (usuario **sin** roles).
  final bool isSubscriptionOwner;

  /// Permisos efectivos calculados por el servidor (nunca hardcodeados).
  final List<String> permissions;

  bool get hasPhoto =>
      profilePhotoUrl != null && profilePhotoUrl!.trim().isNotEmpty;

  bool get isEmailVerified => emailVerifiedAt != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'profile_photo_url': profilePhotoUrl,
    'is_active': isActive,
    'email_verified_at': emailVerifiedAt?.toUtc().toIso8601String(),
    'branch_id': branchId,
    'branch': branch == null
        ? null
        : <String, dynamic>{
            'id': branch!.id,
            'name': branch!.name,
            'timezone': branch!.timezone,
          },
    'subscription': subscription?.toJson(),
    'is_subscription_owner': isSubscriptionOwner,
    'permissions': permissions,
  };
}
