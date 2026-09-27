import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Barra de acciones anclada al pie de la pantalla (§4, §8).
///
/// Deja las acciones principales siempre a la vista sobre el fondo del panel,
/// con borde superior de 1 px y el área segura del sistema respetada. Una barra
/// dentro de una hoja pasa su propio [backgroundColor] para fundirse con el
/// lienzo de esa hoja en vez de pintar un panel encima.
class EzyActionBar extends StatelessWidget {
  const EzyActionBar({
    super.key,
    this.children = const <Widget>[],
    this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 12),
    this.showTopBorder = true,
    this.backgroundColor,
  });

  /// Acciones apiladas en vertical con 8 px de separación (botones a lo ancho).
  final List<Widget> children;

  /// Contenido libre; alternativa a [children].
  final Widget? child;

  final EdgeInsetsGeometry padding;
  final bool showTopBorder;

  /// Fondo de la barra; por defecto, el `panel` del tema.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    final content =
        child ??
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              children[i],
            ],
          ],
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? surfaces.panel,
        border: showTopBorder
            ? Border(top: BorderSide(color: surfaces.border))
            : null,
      ),
      child: SafeArea(
        top: false,
        child: Padding(padding: padding, child: content),
      ),
    );
  }
}
