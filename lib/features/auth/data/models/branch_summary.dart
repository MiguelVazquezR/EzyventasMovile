import '../../../../core/utils/json_reader.dart';

/// Resumen de la sucursal activa del usuario.
class BranchSummary {
  const BranchSummary({
    required this.id,
    required this.name,
    required this.timezone,
  });

  factory BranchSummary.fromJson(Map<String, dynamic> json) => BranchSummary(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    timezone: JsonReader.string(json['timezone']),
  );

  final int id;
  final String name;

  /// Zona horaria de la sucursal (`America/Mexico_City`).
  final String? timezone;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'timezone': timezone,
  };
}

/// Estado de la suscripción del negocio.
class SubscriptionSummary {
  const SubscriptionSummary({
    required this.id,
    required this.commercialName,
    required this.status,
    required this.expiresAt,
  });

  factory SubscriptionSummary.fromJson(Map<String, dynamic> json) =>
      SubscriptionSummary(
        id: JsonReader.integer(json['id']),
        commercialName: JsonReader.stringOr(json['commercial_name'], ''),
        status: JsonReader.string(json['status']),
        expiresAt: json['expires_at'],
      );

  final int? id;
  final String commercialName;

  /// `activa` / `por_vencer` / `expirada` / `suspendida` (según el backend).
  final String? status;

  /// Fecha de vencimiento (ISO-8601) tal cual llega del servidor.
  final Object? expiresAt;

  bool get isActive => status == null || status == 'activa';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'commercial_name': commercialName,
    'status': status,
    'expires_at': expiresAt,
  };
}
