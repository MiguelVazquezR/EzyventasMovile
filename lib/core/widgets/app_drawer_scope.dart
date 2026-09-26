import 'package:flutter/material.dart';

/// Etiqueta del disparador del menú lateral (hamburguesa de las cabeceras).
const String appDrawerOpenTooltip = 'Abrir menú';

/// Puente entre el cascarón y las pantallas que viven dentro de él.
///
/// El `Drawer` cuelga del `Scaffold` del cascarón, pero cada pestaña monta su
/// **propio** `Scaffold` (el POS, por ejemplo, para colgar del pie la barra del
/// carrito), así que `Scaffold.of(context).openDrawer()` desde una pantalla
/// abriría un menú que no existe: ese `Scaffold` de dentro no tiene ninguno. Este
/// `InheritedWidget` entrega la acción del cascarón a cualquier descendiente.
///
/// Una pantalla que se monte **fuera** del cascarón (una prueba de widget, el
/// alta de una orden, que es de pantalla completa) no encuentra el `scope`: en
/// ese caso no se pinta ningún disparador y el menú tampoco hace falta, porque no
/// hay pestañas que cambiar.
class AppDrawerScope extends InheritedWidget {
  const AppDrawerScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  /// Abre el menú lateral del cascarón.
  final VoidCallback openDrawer;

  /// Acción para abrir el menú, o `null` si la pantalla no vive en el cascarón.
  static VoidCallback? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppDrawerScope>()?.openDrawer;

  @override
  bool updateShouldNotify(covariant AppDrawerScope oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}
