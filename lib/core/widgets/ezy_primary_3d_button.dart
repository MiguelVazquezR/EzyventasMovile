import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// CTA primario con relieve 3D (§6 del rediseño del carrito, §8 del cobro y §8
/// del editor de línea).
///
/// Va a mano y no con `FilledButton` porque el diseño pide un bisel de tres
/// caras —filo claro arriba, base oscura abajo— que un `ButtonStyle` no sabe
/// pintar: degradado vertical, bisel físico y dos sombras compuestas (la base
/// sólida pegada al borde inferior y el glow de marca que lo despega del lienzo).
/// Al mantenerlo pulsado el contenido baja 4 px y el relieve se apaga.
///
/// **Por qué el bisel no vive en el mismo `BoxDecoration` que el degradado.** Un
/// `Border` con colores distintos por lado dentro de una caja con `borderRadius`
/// dispara la aserción «A borderRadius can only be given on borders with uniform
/// colors.». La aserción no solo avisa: en las compilaciones de depuración corta
/// el `paint` del `DecoratedBox` **antes de pintar a su hijo**, así que el botón
/// salía con su cara naranja y **sin la etiqueta ni el icono** (los que sí se
/// veían eran los estados apagados, cuya caja no tiene bisel). Por eso el bisel
/// va en un `DecoratedBox` interior —sin radio, que es lo que la aserción exige—
/// y las esquinas las redondea el `ClipRRect` de fuera.
class EzyPrimary3dButton extends StatefulWidget {
  const EzyPrimary3dButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.isLoading = false,
    this.height = 56,
    this.widthFactor = 1,
    this.maxWidth = 340,
    this.labelFontSize = 14,
    this.anchorKey,
  });

  /// Texto del CTA (`Finalizar compra`, `Finalizar venta`, `Guardar cambios`).
  final String label;

  /// Acción del botón; `null` lo deja apagado (cara del sistema, sin sombras,
  /// sin toque y sin hundido).
  final VoidCallback? onPressed;

  /// Icono a la izquierda de la etiqueta.
  final IconData? icon;

  /// Icono a la derecha (el chevron del menú del carrito).
  final IconData? trailingIcon;

  /// La acción está en curso: el contenido se cambia por el spinner.
  final bool isLoading;

  /// Alto fijo del botón (56 px el CTA de cobro, 52 el del carrito).
  final double height;

  /// Fracción del ancho disponible que ocupa el botón.
  final double widthFactor;

  /// Tope de ancho: en tablet el botón no se estira de más.
  final double maxWidth;

  final double labelFontSize;

  /// Llave del recuadro del botón, para quien tenga que anclarle algo (el menú
  /// emergente del carrito se pega a su borde superior).
  final GlobalKey? anchorKey;

  /// Radio de las esquinas del botón.
  static const double radius = 16;

  /// Caras del degradado: filo iluminado, marca al centro y base con profundidad.
  static const List<Color> gradientColors = <Color>[
    Color(0xFFFB9E2E),
    EzyColors.primary,
    Color(0xFFC95B00),
  ];

  /// Bisel físico: 1 px claro arriba, base oscura de 2 px abajo y canto tenue a
  /// los lados (`Colors.white` al 40 % y al 12 %).
  static const Border bevel = Border(
    top: BorderSide(color: Color(0x66FFFFFF)),
    bottom: BorderSide(color: Color(0xFF944000), width: 2),
    left: BorderSide(color: Color(0x1FFFFFFF)),
    right: BorderSide(color: Color(0x1FFFFFFF)),
  );

  /// Relieve del botón: sombra sólida pegada al borde inferior y glow de marca.
  static const List<BoxShadow> relief = <BoxShadow>[
    BoxShadow(color: Color(0xFF853700), offset: Offset(0, 4)),
    // `EzyColors.primary` al 45 %: el halo que despega el botón del lienzo.
    BoxShadow(color: Color(0x73F68C0F), offset: Offset(0, 8), blurRadius: 20),
  ];

  /// Filo tipográfico (`Colors.black38`): la etiqueta blanca se lee sobre el
  /// naranja sin glow.
  static const List<Shadow> labelShadow = <Shadow>[
    Shadow(color: Color(0x61000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// Cara del botón: el 3D con la acción disponible y el gris del sistema cuando
  /// no hay nada que cerrar.
  ///
  /// Apagado no lleva sombras: un botón que no se puede tocar no se despega del
  /// lienzo. La etiqueta se queda en el tono apagado de la superficie, legible
  /// en claro y en oscuro (el naranja al 50 % del diseño dejaba el texto blanco
  /// sin contraste en el tema claro).
  static BoxDecoration face({
    required bool enabled,
    required bool pressed,
    required EzySurfaces surfaces,
  }) {
    if (!enabled) {
      return BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: surfaces.border, width: 1.5),
      );
    }

    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: gradientColors,
        stops: <double>[0.0, 0.42, 1.0],
      ),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: pressed ? null : relief,
    );
  }

  @override
  State<EzyPrimary3dButton> createState() => _EzyPrimary3dButtonState();
}


class _EzyPrimary3dButtonState extends State<EzyPrimary3dButton> {
  /// El botón está bajo el dedo: se dibuja hundido.
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final enabled = widget.onPressed != null && !widget.isLoading;
    // Con la acción en curso el botón conserva la cara de marca: el spinner va
    // en blanco y sobre el gris del sistema no se leería. Lo que se apaga es el
    // toque.
    final branded = enabled || widget.isLoading;

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double byFraction = constraints.maxWidth * widget.widthFactor;
          final double width = byFraction > widget.maxWidth
              ? widget.maxWidth
              : byFraction;

          return GestureDetector(
            onTapDown: enabled ? (details) => _setPressed(true) : null,
            onTapUp: enabled ? (details) => _setPressed(false) : null,
            onTapCancel: enabled ? () => _setPressed(false) : null,
            onTap: enabled ? widget.onPressed : null,
            child: AnimatedContainer(
              key: widget.anchorKey,
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              width: width,
              height: widget.height,
              // El botón se hunde 4 px: la sombra sólida queda a ras del lienzo.
              transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
              decoration: EzyPrimary3dButton.face(
                enabled: branded,
                pressed: _pressed,
                surfaces: surfaces,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(EzyPrimary3dButton.radius),
                child: DecoratedBox(
                  // El bisel va aquí, sin radio: ver la nota del encabezado.
                  decoration: BoxDecoration(
                    border: branded ? EzyPrimary3dButton.bevel : null,
                  ),
                  child: Center(child: _content(surfaces, branded)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Contenido del botón: spinner, o icono + etiqueta en blanco con su filo.
  Widget _content(EzySurfaces surfaces, bool branded) {
    if (widget.isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: EzyColors.white,
        ),
      );
    }

    final color = branded ? EzyColors.white : surfaces.textMuted;
    final icon = widget.icon;
    final trailingIcon = widget.trailingIcon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
        ],
        Text(
          widget.label,
          style: EzyTextStyles.bodyStrong.copyWith(
            fontSize: widget.labelFontSize,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: branded ? EzyPrimary3dButton.labelShadow : null,
          ),
        ),
        if (trailingIcon != null) ...<Widget>[
          const SizedBox(width: 6),
          Icon(trailingIcon, size: 18, color: color),
        ],
      ],
    );
  }
}
