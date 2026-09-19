import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Formato es-MX en toda la app (seccion 10 del design system).
  Intl.defaultLocale = AppConfig.locale;
  await initializeDateFormatting(AppConfig.locale);

  runApp(const ProviderScope(child: EzyVentasApp()));
}