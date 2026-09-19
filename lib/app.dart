import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';

/// Raíz de la aplicación.
///
/// Modo oscuro por defecto (la referencia visual), localización es-MX y
/// navegación por `go_router`.
class EzyVentasApp extends ConsumerWidget {
  const EzyVentasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'EzyVentas',
      debugShowCheckedModeBanner: false,
      theme: EzyTheme.light(),
      darkTheme: EzyTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('es', 'MX'),
      supportedLocales: const <Locale>[Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Evita que una escala de texto extrema rompa las filas de montos.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
