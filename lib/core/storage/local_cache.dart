import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Caché local mínima (llave → JSON) sobre el almacenamiento seguro.
///
/// Se usa para lo que la app debe recordar entre arranques sin conexión: los
/// contadores de notificaciones (§9b.5: "sin conexión se muestra el último valor
/// cacheado"). No guarda datos de negocio: folios, saldos y ventas siempre vienen
/// del servidor.
class LocalCache {
  LocalCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String notificationsKey = 'ezyventas.cache.notifications';

  final FlutterSecureStorage _storage;

  Map<String, dynamic>? _notifications;
  bool _notificationsLoaded = false;

  /// Último `GET /notifications` guardado (`null` si nunca se ha cargado).
  Future<Map<String, dynamic>?> readNotifications() async {
    if (_notificationsLoaded) {
      return _notifications;
    }

    _notificationsLoaded = true;
    final raw = await _storage.read(key: notificationsKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      _notifications = decoded is Map
          ? decoded.map((key, value) => MapEntry('$key', value))
          : null;
    } on FormatException {
      _notifications = null;
    }

    return _notifications;
  }

  Future<void> saveNotifications(Map<String, dynamic> counters) async {
    _notifications = counters;
    _notificationsLoaded = true;
    await _storage.write(
      key: notificationsKey,
      value: jsonEncode(counters),
    );
  }

  /// Limpia la caché del usuario (al cerrar sesión).
  Future<void> clear() async {
    _notifications = null;
    _notificationsLoaded = true;
    await _storage.delete(key: notificationsKey);
  }
}

/// Caché local compartida por la app.
final localCacheProvider = Provider<LocalCache>((ref) => LocalCache());
