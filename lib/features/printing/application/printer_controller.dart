import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/printing/bluetooth_printer_service.dart';
import '../../../core/printing/printer_preferences.dart';

/// Preferencias de impresión del dispositivo (impresora y plantilla elegida).
final printerPreferencesProvider = Provider<PrinterPreferences>(
  (ref) => PrinterPreferences(),
);

/// Servicio Bluetooth compartido por toda la app.
final bluetoothPrinterServiceProvider = Provider<BluetoothPrinterService>(
  (ref) {
    final service = BluetoothPrinterService();

    ref.onDispose(service.dispose);

    return service;
  },
);

/// Estado de la impresora del teléfono.
class PrinterState {
  const PrinterState({
    this.isSupported = true,
    this.adapter = PrinterAdapterStatus.unknown,
    this.savedPrinter,
    this.isConnected = false,
    this.connectedName,
    this.isBusy = false,
    this.isScanning = false,
    this.devices = const <PrinterDevice>[],
    this.errorMessage,
    this.notice,
  });

  /// El teléfono soporta Bluetooth de baja energía.
  final bool isSupported;

  /// Estado del adaptador Bluetooth.
  final PrinterAdapterStatus adapter;

  /// Impresora guardada de este dispositivo (reconecta sin volver a escanear).
  final SavedPrinter? savedPrinter;

  final bool isConnected;
  final String? connectedName;

  /// Conexión, escaneo o envío en curso.
  final bool isBusy;
  final bool isScanning;

  /// Dispositivos emparejados + encontrados en el escaneo.
  final List<PrinterDevice> devices;

  final String? errorMessage;
  final String? notice;

  bool get isAdapterOn => adapter.isOn;

  bool get hasSavedPrinter => savedPrinter?.isUsable ?? false;

  /// `Impresora conectada: MP80`, `El Bluetooth está apagado`, ...
  String get statusLabel {
    if (isConnected) {
      return 'Impresora conectada: ${connectedName ?? savedPrinter?.label ?? '—'}';
    }

    return switch (adapter) {
      PrinterAdapterStatus.on => 'Sin impresora conectada',
      PrinterAdapterStatus.off => 'El Bluetooth está apagado',
      PrinterAdapterStatus.unauthorized =>
        'La app no tiene permiso para usar Bluetooth',
      PrinterAdapterStatus.unavailable =>
        'Este dispositivo no soporta Bluetooth',
      PrinterAdapterStatus.unknown ||
      PrinterAdapterStatus.unavailable => 'Comprobando el Bluetooth',
    };
  }

  PrinterState copyWith({
    bool? isSupported,
    PrinterAdapterStatus? adapter,
    SavedPrinter? savedPrinter,
    bool? isConnected,
    String? connectedName,
    bool? isBusy,
    bool? isScanning,
    List<PrinterDevice>? devices,
    String? errorMessage,
    String? notice,
    bool clearError = false,
    bool clearNotice = false,
    bool clearConnectedName = false,
    bool clearSavedPrinter = false,
  }) {
    return PrinterState(
      isSupported: isSupported ?? this.isSupported,
      adapter: adapter ?? this.adapter,
      savedPrinter: clearSavedPrinter
          ? null
          : (savedPrinter ?? this.savedPrinter),
      isConnected: isConnected ?? this.isConnected,
      connectedName: clearConnectedName
          ? null
          : (connectedName ?? this.connectedName),
      isBusy: isBusy ?? this.isBusy,
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
    );
  }
}

/// Controlador de la impresora Bluetooth.
///
/// Mantiene el estado del adaptador, la impresora guardada y la conexión. El
/// envío de bytes lo hace [BluetoothPrinterService] en bloques de 20 bytes con
/// 25 ms de pausa; si la impresora se desconecta a media impresión el estado
/// queda desconectado y la UI ofrece reimprimir.
final printerControllerProvider =
    NotifierProvider<PrinterController, PrinterState>(PrinterController.new);

class PrinterController extends Notifier<PrinterState> {
  StreamSubscription<PrinterAdapterStatus>? _adapterSubscription;
  StreamSubscription<void>? _disconnectionSubscription;

  BluetoothPrinterService get _service =>
      ref.read(bluetoothPrinterServiceProvider);

  PrinterPreferences get _preferences => ref.read(printerPreferencesProvider);

  @override
  PrinterState build() {
    Future<void>.microtask(_bootstrap);

    ref.onDispose(() {
      _adapterSubscription?.cancel();
      _disconnectionSubscription?.cancel();
    });

    return const PrinterState();
  }

  /// Lee la impresora guardada y escucha el adaptador y las desconexiones.
  Future<void> _bootstrap() async {
    final saved = await _preferences.readPrinter();
    final status = await _service.adapterStatus();

    state = state.copyWith(
      savedPrinter: saved,
      adapter: status,
      isSupported: status != PrinterAdapterStatus.unavailable,
    );

    _adapterSubscription ??= _service.adapterStatusStream.listen(
      (adapter) {
        state = state.copyWith(adapter: adapter);
      },
      onError: (Object _) {},
    );

    _disconnectionSubscription ??= _service.onDisconnected.listen(
      (_) {
        state = state.copyWith(
          isConnected: false,
          clearConnectedName: true,
          notice: 'Se perdió la conexión con la impresora.',
        );
      },
      onError: (Object _) {},
    );
  }

  /// Vuelve a comprobar el adaptador (al abrir la hoja de impresión).
  Future<void> refresh() => _bootstrap();

  /// Recarga la lista: emparejadas primero y, si se pide, escaneo BLE.
  ///
  /// En Android 12+ el permiso de "dispositivos cercanos" lo pide Android al
  /// **escanear**, no al leer las emparejadas: por eso, si esa primera lectura
  /// falla, se escanea (lo que dispara el diálogo del sistema) y se reintenta
  /// la lista de emparejadas. Así el usuario ve las dos fuentes sin quedarse
  /// con la hoja cargando (ver hallazgo 23 del README).
  Future<void> loadDevices({bool scan = true}) async {
    state = state.copyWith(isBusy: true, isScanning: scan, clearError: true);

    final savedId = state.savedPrinter?.id;
    final found = <String, PrinterDevice>{};

    void add(PrinterDevice device) => found.putIfAbsent(
      device.id,
      () => device.copyWith(isSaved: device.id == savedId),
    );

    String? errorMessage;

    try {
      for (final device in await _service.pairedDevices()) {
        add(device);
      }
    } on PrinterException catch (error) {
      errorMessage = error.message;
    } on Object catch (error) {
      errorMessage = 'No se pudieron listar las impresoras emparejadas: $error';
    }

    if (scan) {
      try {
        for (final device in await _service.scanForPrinters()) {
          add(device);
        }

        // El escaneo (que es lo que pide los permisos) funcionó: la lista ya
        // es utilizable.
        errorMessage = null;

        // Se reintenta la lista de emparejadas para que el usuario vea también
        // las suyas; si sigue sin permiso, se muestran las del escaneo.
        try {
          for (final device in await _service.pairedDevices()) {
            add(device);
          }
        } on Object {
          // Nada que avisar: la pantalla ya lista lo que se anuncia cerca.
        }
      } on PrinterException catch (error) {
        errorMessage = error.message;
      } on Object catch (error) {
        errorMessage = 'No se pudieron buscar impresoras: $error';
      }
    }

    state = state.copyWith(
      // Emparejadas (las del teléfono) primero, como antes de reintentar la
      // lista tras el escaneo; después las que se anuncian cerca.
      devices: <PrinterDevice>[
        ...found.values.where((device) => device.isPaired),
        ...found.values.where((device) => !device.isPaired),
      ],
      errorMessage: errorMessage,
      isBusy: false,
      isScanning: false,
    );
  }

  /// Conecta (y recuerda) una impresora elegida por el usuario.
  Future<bool> connectTo(PrinterDevice device) async {
    state = state.copyWith(isBusy: true, clearError: true);

    try {
      await _service.connect(device);

      final saved = SavedPrinter(id: device.id, name: device.label);
      await _preferences.savePrinter(saved);

      state = state.copyWith(
        isConnected: true,
        connectedName: device.label,
        savedPrinter: saved,
        isBusy: false,
        notice: 'Impresora conectada.',
      );

      return true;
    } on PrinterException catch (error) {
      state = state.copyWith(
        errorMessage: error.message,
        isConnected: false,
        clearConnectedName: true,
        isBusy: false,
      );

      return false;
    }
  }

  /// Reconecta con la impresora guardada, sin volver a escanear.
  Future<bool> connectSaved() async {
    final saved = state.savedPrinter;

    if (saved == null || !saved.isUsable) {
      state = state.copyWith(errorMessage: 'Primero elige una impresora.');

      return false;
    }

    return connectTo(PrinterDevice(id: saved.id, name: saved.label));
  }

  /// Olvida la impresora guardada y cierra la conexión.
  Future<void> forgetPrinter() async {
    await _service.disconnect();
    await _preferences.clearPrinter();

    state = state.copyWith(
      clearSavedPrinter: true,
      isConnected: false,
      clearConnectedName: true,
      notice: 'Impresora olvidada.',
    );
  }

  /// Desconecta sin olvidar el dispositivo (para elegir otra impresora).
  Future<void> disconnect() async {
    await _service.disconnect();

    state = state.copyWith(isConnected: false, clearConnectedName: true);
  }

  /// Enciende el Bluetooth del teléfono (Android pide confirmación).
  Future<void> turnOnAdapter() async {
    try {
      await _service.turnOnAdapter();
    } on Object {
      state = state.copyWith(
        errorMessage: 'Enciende el Bluetooth desde los ajustes del teléfono.',
      );
    }
  }

  /// Envía bytes a la impresora, reconectando la guardada si hace falta.
  ///
  /// Devuelve `false` (sin lanzar) cuando no se pudo imprimir: el `message` del
  /// error ya quedó en [PrinterState.errorMessage].
  Future<bool> printBytes(Uint8List bytes) async {
    state = state.copyWith(isBusy: true, clearError: true);

    if (!_service.isConnected && !await connectSaved()) {
      state = state.copyWith(isBusy: false);

      return false;
    }

    try {
      await _service.write(bytes);

      state = state.copyWith(
        isBusy: false,
        notice: 'Ticket enviado a la impresora.',
      );

      return true;
    } on PrinterException catch (error) {
      state = state.copyWith(
        errorMessage: error.message,
        isConnected: false,
        clearConnectedName: true,
        isBusy: false,
      );

      return false;
    }
  }

  void consumeError() => state = state.copyWith(clearError: true);

  void consumeNotice() => state = state.copyWith(clearNotice: true);
}

