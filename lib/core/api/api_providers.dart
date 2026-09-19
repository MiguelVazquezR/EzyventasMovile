import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_store.dart';
import 'api_client.dart';

/// Almacenamiento seguro de la sesión (token + contexto).
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Cliente HTTP compartido por todos los repositorios.
///
/// El token se lee del almacenamiento seguro en cada petición, así que el
/// usuario nunca ve una petición sin `Authorization`.
final apiClientProvider = Provider<ApiClient>((ref) {
  final sessionStore = ref.watch(sessionStoreProvider);

  return ApiClient(readToken: sessionStore.readToken);
});
