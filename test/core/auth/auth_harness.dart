import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/features/auth/data/auth_repository.dart';
import 'package:ezyventas_app/features/auth/data/models/access_context.dart';
import 'package:ezyventas_app/features/auth/data/models/auth_session.dart';

/// Repositorio de autenticación falso: la pantalla no toca la red ni el
/// almacenamiento seguro.
///
/// Lo comparten las pruebas de pantallas que montan `AppScreenHeader` (que lee el
/// contexto de acceso para el chip de sucursal) sin querer un login real.
class FakeAuthRepository extends AuthRepository {
  FakeAuthRepository({required this.session})
    : super(api: ApiClient(), sessionStore: SessionStore());

  AuthSession session;

  @override
  Future<AuthSession?> readStoredSession() async => session;

  @override
  Future<AccessContext> fetchAccessContext() async => session.context;

  @override
  Future<void> saveSession(AuthSession next) async => session = next;

  @override
  Future<void> clearSession() async {}
}

/// Sesión falsa con los permisos, módulos y sucursal que entregaría el servidor.
///
/// [businessName] simula el `subscription.commercial_name` del negocio: sin él,
/// el nombre del negocio cae al de la sucursal (usuario sin suscripción).
AuthSession fakeSession({
  required List<String> permissions,
  required List<String> modules,
  String name = 'Miguel Osvaldo',
  bool isOwner = true,
  String? businessName,
}) => AuthSession.fromJson(<String, dynamic>{
  'token': '3|token-de-prueba',
  'user': <String, dynamic>{
    'id': 2,
    'name': name,
    'email': 'miguel@apontephone.com',
    'branch_id': 2,
    'branch': <String, dynamic>{
      'id': 2,
      'name': 'Melchor Ocampo',
      'timezone': 'America/Mexico_City',
    },
    'is_subscription_owner': isOwner,
    'subscription': businessName == null
        ? null
        : <String, dynamic>{
            'id': 7,
            'commercial_name': businessName,
            'status': 'activa',
            'expires_at': null,
          },
    'permissions': permissions,
  },
  'module_keys': modules,
  'modules': modules,
  'available_branches': <Map<String, dynamic>>[
    <String, dynamic>{'id': 2, 'name': 'Melchor Ocampo', 'is_current': true},
  ],
  'active_session': null,
  'joinable_sessions': <Map<String, dynamic>>[],
  'available_cash_registers': <Map<String, dynamic>>[],
});
