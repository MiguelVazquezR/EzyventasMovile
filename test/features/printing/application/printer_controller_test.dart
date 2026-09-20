import 'dart:typed_data';

import 'package:ezyventas_app/core/printing/bluetooth_printer_service.dart';
import 'package:ezyventas_app/core/printing/printer_preferences.dart';
import 'package:ezyventas_app/features/printing/application/printer_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// AlmacÃ©n seguro en memoria: en las pruebas no hay canal nativo y asÃ­ la
/// impresora guardada es determinista.
class _MemorySecureStorage extends FlutterSecureStorage {
  _MemorySecureStorage();

  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _values.remove(key);
}

/// Servicio falso: reproduce lo que hace el plugin en el telÃ©fono (incluido el
/// `SecurityException` de Android 12+ cuando falta el permiso) sin tocar el
/// Bluetooth real.
class _FakePrinterService extends BluetoothPrinterService {
  _FakePrinterService({
    this.paired = const <PrinterDevice>[],
    this.scanned = const <PrinterDevice>[],
    this.pairedError,
    this.scanError,
    this.failPairedOnce = false,
  });

  /// Lo que devuelve el listado de emparejadas del telÃ©fono.
  List<PrinterDevice> paired;

  /// Lo que devuelve el escaneo BLE.
  List<PrinterDevice> scanned;

  /// Error de la primera lectura de emparejadas (permiso del sistema).
  Object? pairedError;

  /// Error del escaneo (el usuario negÃ³ los permisos).
  Object? scanError;

  /// El permiso se concede en el escaneo: el reintento sÃ­ responde.
  bool failPairedOnce;

  int pairedCalls = 0;
  int scanCalls = 0;

  @override
  Future<PrinterAdapterStatus> adapterStatus() async => PrinterAdapterStatus.on;

  @override
  Stream<PrinterAdapterStatus> get adapterStatusStream =>
      const Stream<PrinterAdapterStatus>.empty();

  @override
  Stream<void> get onDisconnected => const Stream<void>.empty();

  @override
  Future<List<PrinterDevice>> pairedDevices() async {
    pairedCalls++;

    final error = pairedError;

    if (error != null) {
      if (failPairedOnce) {
        pairedError = null;
      }

      throw error;
    }

    return paired;
  }

  @override
  Future<List<PrinterDevice>> scanForPrinters({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    scanCalls++;

    final error = scanError;

    if (error != null) {
      scanError = null;

      throw error;
    }

    return scanned;
  }
}

const PrinterDevice _pairedPrinter = PrinterDevice(
  id: 'DC:1D:30:67:05:AC',
  name: 'BY-480BT_05AC',
  isPaired: true,
);

const PrinterDevice _nearPrinter = PrinterDevice(
  id: 'AA:BB:CC:DD:EE:FF',
  name: 'MP80',
  rssi: -62,
);

/// Contenedor con el servicio y las preferencias ya dobles.
///
/// Espera a que `_bootstrap` (que arranca en un `microtask`) lea la impresora
/// guardada y el adaptador antes de devolver el contenedor: es el mismo patrÃ³n
/// de `account_controllers_test`.
Future<ProviderContainer> _containerWith(
  BluetoothPrinterService service, {
  SavedPrinter? savedPrinter,
}) async {
  final storage = _MemorySecureStorage();

  if (savedPrinter != null) {
    await storage.write(
      key: PrinterPreferences.deviceIdKey,
      value: savedPrinter.id,
    );
    await storage.write(
      key: PrinterPreferences.deviceNameKey,
      value: savedPrinter.name,
    );
  }

  final container = ProviderContainer(
    overrides: [
      bluetoothPrinterServiceProvider.overrideWithValue(service),
      printerPreferencesProvider.overrideWithValue(
        PrinterPreferences(storage: storage),
      ),
    ],
  );

  addTearDown(container.dispose);

  for (var attempt = 0; attempt < 20; attempt++) {
    container.read(printerControllerProvider);

    await Future<void>.delayed(Duration.zero);
  }

  return container;
}

void main() {
  group('PrinterController.loadDevices', () {
    test(
      'sin permiso la primera lectura falla, el escaneo lo pide y la lista '
      'queda completa',
      () async {
        final service = _FakePrinterService(
          pairedError: const PrinterException.missingPermission(),
          failPairedOnce: true,
          paired: const <PrinterDevice>[_pairedPrinter],
          scanned: const <PrinterDevice>[_nearPrinter],
        );
        final container = await _containerWith(service);

        await container
            .read(printerControllerProvider.notifier)
            .loadDevices();

        final state = container.read(printerControllerProvider);

        expect(service.scanCalls, 1);
        expect(service.pairedCalls, 2, reason: 'debe reintentar las emparejadas');
        expect(state.isBusy, isFalse);
        expect(state.isScanning, isFalse);
        expect(state.errorMessage, isNull);
        expect(
          state.devices.map((device) => device.label),
          orderedEquals(<String>['BY-480BT_05AC', 'MP80']),
        );
        expect(state.devices.first.isPaired, isTrue);
        expect(state.devices.first.isSaved, isFalse);
      },
    );

    test('permisos negados: se explica y no se queda cargando', () async {
      final service = _FakePrinterService(
        pairedError: const PrinterException.missingPermission(),
        scanError: const PrinterException.missingPermission(),
      );
      final container = await _containerWith(service);

      await container.read(printerControllerProvider.notifier).loadDevices();

      final state = container.read(printerControllerProvider);

      expect(state.devices, isEmpty);
      expect(state.isBusy, isFalse);
      expect(state.errorMessage, contains('permiso de Bluetooth'));
    });

    test('un fallo inesperado del plugin no rompe la bÃºsqueda', () async {
      final service = _FakePrinterService(
        pairedError: StateError('boom'),
        scanError: StateError('boom'),
      );
      final container = await _containerWith(service);

      await container.read(printerControllerProvider.notifier).loadDevices();

      final state = container.read(printerControllerProvider);

      expect(state.isBusy, isFalse);
      expect(state.errorMessage, contains('No se pudieron buscar impresoras'));
    });

    test('sin escaneo, el error de permisos se queda visible', () async {
      final service = _FakePrinterService(
        pairedError: const PrinterException.missingPermission(),
      );
      final container = await _containerWith(service);

      await container
          .read(printerControllerProvider.notifier)
          .loadDevices(scan: false);

      final state = container.read(printerControllerProvider);

      expect(service.scanCalls, 0);
      expect(state.errorMessage, contains('permiso de Bluetooth'));
      expect(state.isBusy, isFalse);
    });
  });

  group('PrinterController.printBytes', () {
    test('sin impresora elegida avisa y no lanza', () async {
      final service = _FakePrinterService();
      final container = await _containerWith(service);

      final printed = await container
          .read(printerControllerProvider.notifier)
          .printBytes(Uint8List.fromList(<int>[0x1B, 0x40]));

      expect(printed, isFalse);
      expect(
        container.read(printerControllerProvider).errorMessage,
        'Primero elige una impresora.',
      );
    });
  });
}
