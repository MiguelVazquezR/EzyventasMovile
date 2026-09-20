import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Impresora guardada de este dispositivo (id GATT + nombre visible).
class SavedPrinter {
  const SavedPrinter({required this.id, required this.name});

  /// Identificador que usa el sistema operativo: MAC en Android.
  final String id;

  /// Nombre con el que el usuario la reconoce.
  final String name;

  bool get isUsable => id.trim().isNotEmpty;

  String get label => name.trim().isEmpty ? id : name;
}

/// Preferencias de impresión del dispositivo.
///
/// Guarda la impresora emparejada (para reconectar sin volver a escanear) y la
/// plantilla elegida por tipo de documento. Se usa `flutter_secure_storage`
/// porque el stack aprobado **no** incluye `shared_preferences` y ya está en la
/// app para la sesión y el tema.
class PrinterPreferences {
  PrinterPreferences({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String deviceIdKey = 'ezyventas.printer_device_id';
  static const String deviceNameKey = 'ezyventas.printer_device_name';
  static const String templateKeyPrefix = 'ezyventas.printer_template.';

  final FlutterSecureStorage _storage;

  /// Impresora guardada, o `null` si el usuario nunca ha conectado una.
  ///
  /// Si el almacén seguro no responde (keystore reiniciado en Android, pruebas
  /// de widget) se devuelve `null` en lugar de romper la hoja de impresión.
  Future<SavedPrinter?> readPrinter() async {
    try {
      final id = (await _storage.read(key: deviceIdKey))?.trim() ?? '';

      if (id.isEmpty) {
        return null;
      }

      final name = (await _storage.read(key: deviceNameKey))?.trim() ?? '';

      return SavedPrinter(id: id, name: name);
    } on Object {
      return null;
    }
  }

  Future<void> savePrinter(SavedPrinter printer) async {
    try {
      await _storage.write(key: deviceIdKey, value: printer.id);
      await _storage.write(key: deviceNameKey, value: printer.name);
    } on Object {
      // Sin preferencias la impresora se elige de nuevo la próxima vez.
    }
  }

  Future<void> clearPrinter() async {
    try {
      await _storage.delete(key: deviceIdKey);
      await _storage.delete(key: deviceNameKey);
    } on Object {
      // Nada que borrar.
    }
  }

  /// Plantilla elegida para un tipo (`ticket_venta`, `etiqueta`, ...).
  Future<int?> readTemplateId(String type) async {
    try {
      final raw = await _storage.read(key: '$templateKeyPrefix$type');

      return int.tryParse(raw ?? '');
    } on Object {
      return null;
    }
  }

  Future<void> saveTemplateId(String type, int templateId) async {
    try {
      await _storage.write(key: '$templateKeyPrefix$type', value: '$templateId');
    } on Object {
      // La selección se pierde solo para esta sesión.
    }
  }
}
