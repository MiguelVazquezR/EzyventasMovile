import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'barcode_scanner_screen.dart';

/// Abre el escáner de códigos y devuelve lo leído (`null` si se cierra).
typedef ScannerLauncher = Future<String?> Function(BuildContext context);

/// Lanzador del escáner que usa la app.
///
/// Es un proveedor y no una llamada directa para que las pruebas puedan
/// sustituirlo por un doble sin cámara (la pantalla del escáner tiene su propia
/// costura, `BarcodeScannerScreen.previewBuilder`, para probarse sola).
final scannerLauncherProvider = Provider<ScannerLauncher>(
  (ref) => showBarcodeScanner,
);
