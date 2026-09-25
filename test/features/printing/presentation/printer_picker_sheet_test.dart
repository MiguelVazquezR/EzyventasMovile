import 'package:ezyventas_app/core/printing/bluetooth_printer_service.dart';
import 'package:ezyventas_app/core/printing/printer_preferences.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_list_tile.dart';
import 'package:ezyventas_app/features/printing/application/printer_controller.dart';
import 'package:ezyventas_app/features/printing/presentation/widgets/printer_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Almacén seguro en memoria: en las pruebas no hay canal nativo.
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

/// Servicio falso: reproduce lo que el plugin devuelve en el teléfono (incluido
/// el `SecurityException` de Android 12+ cuando falta el permiso) sin tocar el
/// Bluetooth real.
class _FakePrinterService extends BluetoothPrinterService {
  _FakePrinterService({
    this.paired = const <PrinterDevice>[],
    this.scanned = const <PrinterDevice>[],
    this.pairedError,
    this.scanError,
  });

  /// Lo que devuelve el listado de emparejadas del teléfono.
  List<PrinterDevice> paired;

  /// Lo que devuelve el escaneo BLE.
  List<PrinterDevice> scanned;

  /// Error de la lectura de emparejadas (permiso del sistema).
  Object? pairedError;

  /// Error del escaneo (el usuario negó los permisos).
  Object? scanError;

  int pairedCalls = 0;
  int scanCalls = 0;

  /// Dispositivo al que se conectó la app (`null` = ninguno).
  String? connectedId;

  @override
  bool get isConnected => connectedId != null;

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
      throw error;
    }

    return scanned;
  }

  @override
  Future<void> connect(PrinterDevice device) async {
    connectedId = device.id;
  }

  @override
  Future<void> disconnect() async {
    connectedId = null;
  }
}

/// Impresora emparejada del teléfono (aparece sin escanear).
const PrinterDevice _pairedPrinter = PrinterDevice(
  id: 'DC:1D:30:67:05:AC',
  name: 'BY-480BT_05AC',
  isPaired: true,
);

/// Impresora que se anuncia cerca durante el escaneo BLE.
const PrinterDevice _nearPrinter = PrinterDevice(
  id: 'AA:BB:CC:DD:EE:FF',
  name: 'MP80',
  rssi: -62,
);

/// Sondea hasta que el widget exista: la lista la llena el controlador en un
/// `microtask` y los indicadores de progreso nunca se asientan (con
/// `pumpAndSettle` la prueba colgaría).
Future<void> _pumpUntil(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));

  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 100));
      return;
    }

    await tester.pump(const Duration(milliseconds: 50));
  }

  fail('No apareció $finder');
}

/// Monta el selector de impresora como lo abre la hoja de impresión.
Future<ProviderContainer> _pumpPicker(
  WidgetTester tester,
  _FakePrinterService service,
) async {
  final container = ProviderContainer(
    overrides: [
      bluetoothPrinterServiceProvider.overrideWithValue(service),
      printerPreferencesProvider.overrideWithValue(
        PrinterPreferences(storage: _MemorySecureStorage()),
      ),
    ],
  );
  addTearDown(container.dispose);

  // Pantalla alta: la hoja (0.7 del alto) deja ver la lista y el botón.
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPrinterPickerSheet(context),
                child: const Text('Abrir selector'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.text('Abrir selector'));
  await _pumpUntil(tester, find.byType(EzySheetHeader));

  return container;
}

void main() {
  testWidgets('lista las emparejadas y las que se anuncian cerca', (
    tester,
  ) async {
    final service = _FakePrinterService(
      paired: const <PrinterDevice>[_pairedPrinter],
      scanned: const <PrinterDevice>[_nearPrinter],
    );

    await _pumpPicker(tester, service);
    await _pumpUntil(tester, find.text('BY-480BT_05AC'));

    // Cabecera de hoja del design system, con su cierre.
    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Elegir impresora');
    expect(find.byTooltip('Cerrar'), findsOneWidget);
    expect(find.widgetWithText(EzyButton, 'Buscar de nuevo'), findsOneWidget);

    // Cada impresora es una fila del design system (cuadro del icono, nombre,
    // datos del dispositivo y chevron), sin contenedores propios.
    final tiles = find.byType(EzyListTile);
    expect(tiles, findsNWidgets(2));
    expect(tester.widget<EzyListTile>(tiles.at(0)).title, 'BY-480BT_05AC');
    expect(tester.widget<EzyListTile>(tiles.at(1)).title, 'MP80');
    expect(tester.widget<EzyListTile>(tiles.at(0)).icon, Icons.bluetooth);
    expect(
      tester.widget<EzyListTile>(tiles.at(0)).subtitle,
      contains('emparejada'),
    );
    expect(tester.widget<EzyListTile>(tiles.at(1)).subtitle, contains('dBm'));
    expect(tester.widget<EzyListTile>(tiles.at(0)).showDivider, isTrue);
    expect(tester.widget<EzyListTile>(tiles.at(1)).showDivider, isFalse);
  });

  testWidgets('elegir una impresora conecta y cierra la hoja', (tester) async {
    final service = _FakePrinterService(
      paired: const <PrinterDevice>[_pairedPrinter],
      scanned: const <PrinterDevice>[_nearPrinter],
    );

    final container = await _pumpPicker(tester, service);
    await _pumpUntil(tester, find.text('MP80'));

    await tester.tap(find.text('MP80'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(service.connectedId, _nearPrinter.id);
    expect(container.read(printerControllerProvider).connectedName, 'MP80');
    // La conexión se guarda para reconectar sin volver a escanear (hallazgo 23).
    expect(
      container.read(printerControllerProvider).savedPrinter?.id,
      _nearPrinter.id,
    );
    expect(
      find.byType(EzySheetHeader),
      findsNothing,
      reason: 'La hoja debía cerrarse al conectar',
    );
  });

  testWidgets('sin permiso lo explica y el botón vuelve a buscar', (
    tester,
  ) async {
    final service = _FakePrinterService(
      pairedError: const PrinterException.missingPermission(),
      scanError: const PrinterException.missingPermission(),
    );

    await _pumpPicker(tester, service);
    await _pumpUntil(tester, find.textContaining('permiso de Bluetooth'));

    expect(find.text('Sin impresoras'), findsOneWidget);
    expect(find.widgetWithText(EzyListTile, 'MP80'), findsNothing);

    // El permiso se concede en el teléfono y se vuelve a buscar desde la hoja.
    service.pairedError = null;
    service.scanError = null;
    service.paired = const <PrinterDevice>[_pairedPrinter];

    await tester.tap(find.widgetWithText(EzyButton, 'Buscar de nuevo'));
    await tester.pump();
    await _pumpUntil(tester, find.text('BY-480BT_05AC'));

    expect(find.widgetWithText(EzyListTile, 'BY-480BT_05AC'), findsOneWidget);
    expect(find.text('Sin impresoras'), findsNothing);
  });
}
