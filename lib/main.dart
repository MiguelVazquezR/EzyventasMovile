import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  _allowLocalServerImages();

  // Formato es-MX en toda la app (seccion 10 del design system).
  Intl.defaultLocale = AppConfig.locale;
  await initializeDateFormatting(AppConfig.locale);

  runApp(const ProviderScope(child: EzyVentasApp()));
}

/// Acepta el certificado autofirmado del servidor local **también** en las
/// imágenes.
///
/// `ApiClient` resuelve el certificado autofirmado con su propio cliente Dio,
/// pero `Image.network` usa el `HttpClient` interno del motor: sin este hook
/// todas las imágenes del servidor (productos, evidencias de órdenes, foto de
/// perfil) fallaban en el teléfono contra el servidor local, aunque la API
/// respondiera bien. Flutter expone [debugNetworkImageHttpClientProvider] para
/// inyectar el cliente y **solo aplica en builds de debug**: en release el
/// certificado se valida siempre (igual que en la API).
void _allowLocalServerImages() {
  if (!kDebugMode || !AppConfig.allowBadCertificate) {
    return;
  }

  debugNetworkImageHttpClientProvider = () {
    final client = HttpClient()..autoUncompress = false;
    client.badCertificateCallback = (certificate, host, port) => true;

    return client;
  };
}
