import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_providers.dart';

/// Modo de tema de la app.
///
/// El modo **oscuro es el predeterminado**; el cambio a claro se guarda en las
/// preferencias locales del dispositivo (almacenamiento seguro, sin añadir
/// dependencias extra para una sola bandera).
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    Future<void>.microtask(_restore);

    return ThemeMode.dark;
  }

  Future<void> _restore() async {
    final raw = await ref.read(sessionStoreProvider).readThemeMode();
    final restored = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => null,
    };

    if (restored != null && restored != state) {
      state = restored;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(sessionStoreProvider).saveThemeMode(mode.name);
  }

  /// Alterna entre oscuro y claro.
  Future<void> toggle() =>
      setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}
