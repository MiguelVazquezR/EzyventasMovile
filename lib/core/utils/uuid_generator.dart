import 'dart:math';

/// Generador de `client_uuid` (UUID v4) para las escrituras idempotentes.
///
/// Se implementa aquí para no añadir una dependencia extra: el contrato solo
/// exige un UUID v4 válido (`client_uuid`), que el servidor usa para no duplicar
/// la operación si la petición se repite.
class UuidGenerator {
  UuidGenerator._();

  static final Random _random = Random.secure();

  /// Devuelve un UUID v4 en formato canónico (`xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`).
  static String v4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40; // versión 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
