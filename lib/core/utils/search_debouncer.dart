import 'dart:async';

import 'package:flutter/foundation.dart';

/// Debounce reutilizable para los buscadores de la app (catálogo, ventas,
/// clientes…). Evita una petición por tecla.
class SearchDebouncer {
  SearchDebouncer({this.delay = const Duration(milliseconds: 350)});

  final Duration delay;
  Timer? _timer;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() => _timer?.cancel();
}
