import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Estado del adaptador Bluetooth del teléfono.
enum PrinterAdapterStatus {
  unknown,
  unavailable,
  unauthorized,
  off,
  on;

  bool get isOn => this == PrinterAdapterStatus.on;
}

/// Dispositivo candidato para imprimir (emparejado, guardado o escaneado).
class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    this.isPaired = false,
    this.isSaved = false,
    this.rssi,
  });

  /// MAC/identificador del sistema operativo (`06:E5:28:3B:FD:E0`).
  final String id;
  final String name;

  /// Ya está emparejado con el teléfono (aparece sin escanear).
  final bool isPaired;

  /// Es la impresora que el usuario guardó en esta app.
  final bool isSaved;

  final int? rssi;

  String get label => name.trim().isEmpty ? id : name;

  PrinterDevice copyWith({bool? isSaved}) => PrinterDevice(
    id: id,
    name: name,
    isPaired: isPaired,
    isSaved: isSaved ?? this.isSaved,
    rssi: rssi,
  );
}

/// Error de impresión con un mensaje listo para mostrar en la UI.
///
/// El texto es propio de la app (no viene del servidor): describe un fallo del
/// teléfono o de la impresora, nunca una regla de negocio.
class PrinterException implements Exception {
  const PrinterException(this.message, {this.isConnectionLost = false});

  /// La impresora se desconectó a media impresión: la UI debe avisar y permitir
  /// reimprimir.
  const PrinterException.connectionLost()
    : message = 'Se perdió la conexión con la impresora.',
      isConnectionLost = true;

  /// Falta el permiso de Bluetooth del sistema (Android 12+).
  ///
  /// El plugin **solo** pide los permisos al escanear: si el usuario los niega
  /// (o la app se instaló y nadie los concedió), el listado de emparejadas
  /// falla con `SecurityException` del sistema. Se muestra este texto en lugar
  /// del error crudo del plugin.
  const PrinterException.missingPermission()
    : message =
          'La app necesita el permiso de Bluetooth (dispositivos cercanos) '
          'para buscar la impresora. Actívalo en los ajustes del teléfono.',
      isConnectionLost = false;

  final String message;
  final bool isConnectionLost;

  @override
  String toString() => message;
}

/// Impresora térmica Bluetooth por GATT (ESC/POS y etiquetas TSPL).
///
/// Réplica en Android de `resources/js/Composables/useBluetoothPrinter.js`:
/// busca la característica escribible del servicio, prefiere
/// `writeWithoutResponse` y envía los bytes en **bloques de 20 bytes con 25 ms
/// de pausa** (las térmicas baratas pierden datos si se envían de golpe).
///
/// La app **no** arma aquí ningún documento: recibe los bytes ya codificados
/// por el servidor (`commands_base64`) o por `EscPosBuilder` para el corte.
class BluetoothPrinterService {
  /// Tamaño de bloque probado con las impresoras soportadas.
  static const int chunkSize = 20;

  /// Pausa entre bloques.
  static const Duration chunkDelay = Duration(milliseconds: 25);

  /// UUIDs de servicio de las térmicas probadas (contrato §10).
  static const List<String> knownServiceUuids = <String>[
    '0000af30-0000-1000-8000-00805f9b34fb', // Phomemo (imagen)
    '49535343-fe7d-4ae5-8fa9-9fafd205e455', // Phomemo antiguo
    '00001101-0000-1000-8000-00805f9b34fb', // puerto serie
  ];

  static const Duration _scanTimeout = Duration(seconds: 8);
  static const Duration _connectTimeout = Duration(seconds: 15);

  final StreamController<void> _disconnections =
      StreamController<void>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  /// Se emite cuando la impresora se desconecta **estando en uso**.
  Stream<void> get onDisconnected => _disconnections.stream;

  /// Hay una característica de escritura lista.
  bool get isConnected =>
      _device != null && _characteristic != null && _device!.isConnected;

  String? get connectedDeviceName => _device?.platformName;

  /// Estado del adaptador (comprobando antes el soporte del dispositivo).
  ///
  /// Si el plugin nativo no responde (pruebas de widget o un teléfono sin BLE)
  /// se devuelve `unavailable` en lugar de propagar el error.
  Future<PrinterAdapterStatus> adapterStatus() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        return PrinterAdapterStatus.unavailable;
      }

      return _mapAdapterState(FlutterBluePlus.adapterStateNow);
    } on Object {
      return PrinterAdapterStatus.unavailable;
    }
  }

  /// Cambios del adaptador (encendido/apagado) mientras la app está abierta.
  Stream<PrinterAdapterStatus> get adapterStatusStream =>
      FlutterBluePlus.adapterState.map(_mapAdapterState);

  /// Enciende el Bluetooth (Android pide confirmación del sistema).
  Future<void> turnOnAdapter() => FlutterBluePlus.turnOn();

  /// Impresoras ya emparejadas con el teléfono.
  ///
  /// `bondedDevices` **no** pide permisos (el plugin solo los pide al escanear),
  /// así que en Android 12+ sin `BLUETOOTH_CONNECT` concedido el sistema lanza
  /// `SecurityException`: se traduce a [PrinterException.missingPermission] para
  /// que la hoja de impresión lo pueda explicar.
  Future<List<PrinterDevice>> pairedDevices() async {
    try {
      await _ensureSupported();

      final devices = await FlutterBluePlus.bondedDevices;

      return devices
          .map(
            (device) => PrinterDevice(
              id: device.remoteId.str,
              name: device.platformName,
              isPaired: true,
            ),
          )
          .toList(growable: false);
    } on FlutterBluePlusException catch (error) {
      throw _mapPluginError(error);
    }
  }

  /// Escaneo BLE (las emparejadas no se anuncian, por eso se listan aparte).
  ///
  /// Es la llamada que **pide** los permisos de Android 12+ (`startScan`): si el
  /// usuario los niega, el sistema devuelve el error de permiso y aquí se
  /// convierte en [PrinterException.missingPermission].
  Future<List<PrinterDevice>> scanForPrinters({
    Duration timeout = _scanTimeout,
  }) async {
    try {
      await _ensureSupported();

      // Un escaneo anterior dejaría resultados mezclados.
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      final found = <String, PrinterDevice>{};

      await FlutterBluePlus.startScan(timeout: timeout);

      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final name = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : result.advertisementData.advName;

          if (name.trim().isEmpty) {
            continue;
          }

          found[result.device.remoteId.str] = PrinterDevice(
            id: result.device.remoteId.str,
            name: name,
            rssi: result.rssi,
          );
        }
      });

      await Future<void>.delayed(timeout);
      await subscription.cancel();
      await FlutterBluePlus.stopScan();

      return found.values.toList(growable: false);
    } on FlutterBluePlusException catch (error) {
      throw _mapPluginError(error);
    }
  }

  /// Conecta con [device] y deja lista la característica de escritura.
  Future<void> connect(PrinterDevice device) async {
    await _ensureSupported();
    await disconnect();

    final target = BluetoothDevice.fromId(device.id);

    try {
      await target.connect(timeout: _connectTimeout);
    } on FlutterBluePlusException catch (error) {
      throw PrinterException(
        'No se pudo conectar con la impresora: ${error.description}',
      );
    }

    final List<BluetoothService> services;

    try {
      services = await target.discoverServices();
    } on FlutterBluePlusException catch (error) {
      // Sin permiso de Bluetooth (o si el dispositivo no tiene GATT) el
      // descubrimiento de servicios es lo primero que falla.
      await _safeDisconnect(target);
      throw _mapPluginError(error);
    }

    final characteristic = _writableCharacteristic(services);

    if (characteristic == null) {
      await _safeDisconnect(target);
      throw const PrinterException(
        'La impresora no tiene una característica de escritura compatible.',
      );
    }

    _device = target;
    _characteristic = characteristic;
    _connectionSubscription = target.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _forgetDevice(notify: true);
      }
    });
  }

  /// Envía los bytes ya codificados (ESC/POS o TSPL) a la impresora.
  ///
  /// Si la impresora se desconecta en medio del envío lanza
  /// [PrinterException.connectionLost] para que la UI avise y permita
  /// reimprimir el ticket completo (nunca queda un ticket a medias sin aviso).
  Future<void> write(Uint8List bytes) async {
    final characteristic = _characteristic;
    final device = _device;

    if (characteristic == null || device == null) {
      throw const PrinterException('Impresora Bluetooth no conectada.');
    }

    final withoutResponse = characteristic.properties.writeWithoutResponse;

    for (var offset = 0; offset < bytes.length; offset += chunkSize) {
      if (device.isDisconnected) {
        _forgetDevice(notify: true);
        throw const PrinterException.connectionLost();
      }

      final end = offset + chunkSize > bytes.length
          ? bytes.length
          : offset + chunkSize;

      try {
        await characteristic.write(
          Uint8List.sublistView(bytes, offset, end),
          withoutResponse: withoutResponse,
        );
      } on FlutterBluePlusException {
        _forgetDevice(notify: true);
        throw const PrinterException.connectionLost();
      }

      // Pausa obligatoria: sin ella las térmicas BT pierden datos.
      await Future<void>.delayed(chunkDelay);
    }
  }

  /// Cierra la conexión a petición del usuario (sin avisar de desconexión).
  Future<void> disconnect() async {
    final device = _device;

    // Se corta primero la escucha: así la desconexión no se reporta como una
    // pérdida de conexión a media impresión.
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _forgetDevice(notify: false);

    if (device != null) {
      await _safeDisconnect(device);
    }
  }

  /// Libera los recursos (al cerrar la app o en las pruebas).
  void dispose() {
    _connectionSubscription?.cancel();
    unawaited(_disconnections.close());
  }

  // --- Búsqueda de la característica y utilidades --------------------------

  /// Característica escribible: primero los servicios conocidos y
  /// `writeWithoutResponse`, igual que el composable de la web.
  static BluetoothCharacteristic? _writableCharacteristic(
    List<BluetoothService> services,
  ) {
    final ordered = <BluetoothService>[
      ...services.where((service) => _isKnownService(service.uuid.str)),
      ...services.where((service) => !_isKnownService(service.uuid.str)),
    ];

    BluetoothCharacteristic? withResponse;

    for (final service in ordered) {
      for (final characteristic in service.characteristics) {
        if (characteristic.properties.writeWithoutResponse) {
          return characteristic;
        }

        if (characteristic.properties.write && withResponse == null) {
          withResponse = characteristic;
        }
      }
    }

    return withResponse;
  }

  static bool _isKnownService(String uuid) =>
      knownServiceUuids.contains(uuid.toLowerCase());

  /// Traduce un error del plugin al mensaje que ve el usuario.
  ///
  /// Los fallos de permiso (Android 12+) llevan el texto de la app; el resto
  /// conserva la descripción de Android para poder diagnosticar en el teléfono.
  static PrinterException _mapPluginError(FlutterBluePlusException error) {
    final description = (error.description ?? error.toString()).toLowerCase();

    if (description.contains('permission') ||
        description.contains('securityexception')) {
      return const PrinterException.missingPermission();
    }

    return PrinterException(
      'No se pudo usar el Bluetooth del teléfono: '
      '${error.description ?? error}',
    );
  }

  static PrinterAdapterStatus _mapAdapterState(BluetoothAdapterState state) =>
      switch (state) {
        BluetoothAdapterState.on => PrinterAdapterStatus.on,
        BluetoothAdapterState.turningOff ||
        BluetoothAdapterState.off => PrinterAdapterStatus.off,
        BluetoothAdapterState.unauthorized =>
          PrinterAdapterStatus.unauthorized,
        BluetoothAdapterState.unavailable => PrinterAdapterStatus.unavailable,
        BluetoothAdapterState.unknown ||
        BluetoothAdapterState.turningOn => PrinterAdapterStatus.unknown,
      };

  /// Sin soporte BLE no tiene sentido seguir: se avisa antes de tocar el GATT.
  static Future<void> _ensureSupported() async {
    if (!await FlutterBluePlus.isSupported) {
      throw const PrinterException(
        'Este dispositivo no soporta Bluetooth de baja energía.',
      );
    }
  }

  static Future<void> _safeDisconnect(BluetoothDevice device) async {
    try {
      if (device.isConnected) {
        await device.disconnect();
      }
    } on FlutterBluePlusException {
      // La impresora ya no responde: la app solo limpia su estado.
    }
  }

  /// Olvida la impresora activa y avisa si la conexión se perdió en uso.
  void _forgetDevice({bool notify = false}) {
    final hadDevice = _characteristic != null;
    _device = null;
    _characteristic = null;

    if (notify && hadDevice && !_disconnections.isClosed) {
      _disconnections.add(null);
    }
  }
}

