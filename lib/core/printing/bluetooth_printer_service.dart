import 'dart:async';

import 'package:flutter/foundation.dart';
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
/// Busca la característica escribible del servicio, prefiere el envío **con
/// respuesta** (cada bloque lo confirma la impresora) y trocea el documento en
/// bloques del tamaño que permite el **MTU negociado**.
///
/// El contrato §10 describe el procedimiento de la web (`useBluetoothPrinter.js`:
/// bloques de 20 bytes con 25 ms de pausa ≈ 800 B/s). Eso vale para el *Web
/// Bluetooth* del navegador, pero en Android el MTU negociado es mayor, así que
/// 20 bytes por bloque condenaban a ~11 s cualquier documento con imagen: el
/// ticket de la plantilla real, que lleva el logo del negocio rasterizado como
/// bitmap ESC/POS (`GS v 0`), mide ~8.7 KB. Con bloques del tamaño del MTU
/// (`245 B` medidos con la MP210) y ACK, el mismo ticket sale en **3.4 s**
/// (36 bloques) en vez de ~11 s. Lo que queda es la latencia de cada ACK
/// (~94 ms), que baja si se pide un intervalo de conexión más corto.
///
/// La app **no** arma aquí ningún documento: recibe los bytes ya codificados
/// por el servidor (`commands_base64`) o por `PrintOperationsEncoder` (las
/// `operations` del corte y de la etiqueta).
class BluetoothPrinterService {
  /// MTU que se pide al conectar (Android).
  ///
  /// Es el máximo que anuncian los módulos de las térmicas; Android suele
  /// negociar 517 por su cuenta, pero pedirlo explícitamente lo garantiza en
  /// teléfonos que se quedan en el mínimo (23 → bloques de 20 bytes).
  static const int preferredMtu = 512;

  /// Tope del bloque útil (`MTU - 3`), incluso si el MTU negociado es mayor.
  static const int maxChunkSize = 512;

  /// Bloque útil cuando el MTU no se puede leer (mínimo BLE, `23 - 3`).
  static const int fallbackChunkSize = 20;

  /// Pausa entre bloques **sin** respuesta.
  ///
  /// Con `write` (con respuesta) el propio ACK marca el ritmo y el control de
  /// flujo lo da el enlace; solo hace falta cuando la característica únicamente
  /// admite `writeWithoutResponse` (las térmicas baratas pierden datos si se
  /// envían de golpe).
  static const Duration chunkDelay = Duration(milliseconds: 10);

  /// Bloque útil para un MTU negociado: `MTU - 3` (la cabecera ATT), acotado.
  ///
  /// Android negocia 517 con las térmicas probadas (`512` útiles); si el teléfono
  /// se queda en el mínimo BLE (23) el bloque vuelve a 20 bytes, que es el
  /// procedimiento del contrato §10.
  static int chunkSizeFor(int? mtu) {
    if (mtu == null || mtu <= 23) {
      return fallbackChunkSize;
    }

    final usable = mtu - 3;

    return usable > maxChunkSize ? maxChunkSize : usable;
  }

  /// Bloques `(inicio, fin)` en los que se parte un documento de [length] bytes.
  ///
  /// Es puro a propósito: así se prueba que el envío no pierde ni repite bytes
  /// (y que el último bloque va corto) sin necesidad de una impresora conectada.
  static List<(int, int)> chunkRanges(int length, int chunkSize) {
    if (chunkSize <= 0) {
      throw ArgumentError.value(chunkSize, 'chunkSize', 'debe ser > 0');
    }

    final ranges = <(int, int)>[];

    for (var start = 0; start < length; start += chunkSize) {
      final end = start + chunkSize > length ? length : start + chunkSize;

      ranges.add((start, end));
    }

    return ranges;
  }

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

    // MTU grande (Android): de él sale el tamaño de bloque del envío. Se pide
    // explícitamente porque hay teléfonos que se quedan en el mínimo BLE (23) y
    // con 20 bytes por bloque un ticket con el logo tardaría ~11 s.
    try {
      await target.requestMtu(preferredMtu);
    } on FlutterBluePlusException {
      // La impresora (o el teléfono) no aceptan el MTU pedido: se sigue con el
      // negociado, que `mtuNow` ya refleja.
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

    debugPrint(
      '[printer] conectada "${device.label}" mtu=${target.mtuNow} '
      'bloque=${chunkSizeFor(target.mtuNow)} B '
      'conRespuesta=${characteristic.properties.write} '
      'sinRespuesta=${characteristic.properties.writeWithoutResponse}',
    );

    _connectionSubscription = target.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _forgetDevice(notify: true);
      }
    });
  }

  /// Envía los bytes ya codificados (ESC/POS o TSPL) a la impresora.
  ///
  /// Trocea el documento en bloques de `MTU - 3` bytes: cada bloque se escribe
  /// **con respuesta** siempre que la característica lo permita (el ACK marca el
  /// ritmo y garantiza que no se pierde nada), y si la impresora solo admite
  /// `writeWithoutResponse` se deja la pausa de [chunkDelay] para no desbordar su
  /// búfer. Un ticket con el logo del negocio pasa de ~11 s a **3.4 s** medidos
  /// (36 bloques de 245 B con ACK).
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

    // Con respuesta siempre que se pueda: el ACK da control de flujo (nada de
    // pausas artificiales) y el enlace marca el ritmo de cada bloque.
    final withoutResponse =
        characteristic.properties.writeWithoutResponse &&
        !characteristic.properties.write;

    final chunkSize = chunkSizeFor(device.mtuNow);
    final started = DateTime.now();

    for (final (start, end) in chunkRanges(bytes.length, chunkSize)) {
      if (device.isDisconnected) {
        _forgetDevice(notify: true);
        throw const PrinterException.connectionLost();
      }

      try {
        await characteristic.write(
          Uint8List.sublistView(bytes, start, end),
          withoutResponse: withoutResponse,
        );
      } on FlutterBluePlusException {
        _forgetDevice(notify: true);
        throw const PrinterException.connectionLost();
      }

      if (withoutResponse) {
        // Sin ACK no hay control de flujo: la pausa evita perder bloques.
        await Future<void>.delayed(chunkDelay);
      }
    }

    final elapsed = DateTime.now().difference(started);

    debugPrint(
      '[printer] ${bytes.length} bytes en '
      '${(bytes.length / chunkSize).ceil()} bloques de $chunkSize '
      '(mtu=${device.mtuNow}, sinRespuesta=$withoutResponse) en '
      '${elapsed.inMilliseconds} ms',
    );
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

