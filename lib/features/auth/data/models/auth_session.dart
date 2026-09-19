import '../../../../core/utils/json_reader.dart';
import 'access_context.dart';

/// Sesión persistida: token de Sanctum + contexto de acceso.
///
/// Se guarda completa en `flutter_secure_storage` para que la app arranque con
/// permisos, módulos y sucursal antes de que responda `GET /auth/me`.
class AuthSession {
  const AuthSession({required this.token, required this.context});

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: JsonReader.stringOr(json['token'], ''),
    context: AccessContext.fromJson(json),
  );

  final String token;
  final AccessContext context;

  bool get isUsable => token.isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    ...context.toJson(),
  };
}
