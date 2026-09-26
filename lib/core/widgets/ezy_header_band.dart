import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Cabecera curva con el degradado de marca.
///
/// Bloque a ancho completo con el naranja de EzyVentas (`primary400` →
/// `primary700`), esquinas inferiores redondeadas ([curveRadius]) y unas ondas
/// tenues de adorno (`_HeaderWaves`) que le dan el aire orgánico de la cabecera
/// del POS sin añadir ni un asset.
///
/// El contenido de dentro es **blanco** (el degradado es de marca), así que quien
/// la use pinta sus textos con `EzyColors.white`. La pieza de trabajo —el
/// buscador del POS— va dentro y lleva su propio relieve: al ser un card claro
/// con sombra sobre el naranja se lee como si flotara por encima del borde curvo,
/// y sin salirse de la banda no pierde ni un píxel de zona táctil.
class EzyHeaderBand extends StatelessWidget {
  const EzyHeaderBand({
    super.key,
    required this.child,
    this.curveRadius = 28,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
  });

  final Widget child;

  /// Radio de las esquinas inferiores.
  final double curveRadius;

  /// Respiro del contenido dentro de la banda.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(bottom: Radius.circular(curveRadius));

    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              EzyColors.primary400,
              EzyColors.primary,
              EzyColors.primary700,
            ],
            stops: <double>[0, 0.55, 1],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _HeaderWaves())),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Ondas de adorno de la cabecera: arcos concéntricos que entran por la esquina
/// superior derecha y una línea curva que cruza por abajo.
///
/// Son blancos translúcidos (10 % y 7 %) sobre el degradado: se leen como
/// textura, nunca como un dibujo, y no compiten con el texto ni con los iconos.
/// No hay nada que repintar: el trazo depende solo del tamaño.
class _HeaderWaves extends CustomPainter {
  const _HeaderWaves();

  @override
  void paint(Canvas canvas, Size size) {
    final arcs = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = EzyColors.white.withValues(alpha: 0.10);

    // Centro fuera de la banda: solo se ve el tramo de arco que la cruza.
    final center = Offset(size.width * 1.04, -size.height * 0.28);
    for (var index = 0; index < 4; index++) {
      canvas.drawCircle(center, size.width * (0.40 + index * 0.17), arcs);
    }

    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = EzyColors.white.withValues(alpha: 0.07);
    final path = Path()
      ..moveTo(-12, size.height * 0.86)
      ..cubicTo(
        size.width * 0.24,
        size.height * 0.44,
        size.width * 0.56,
        size.height * 1.12,
        size.width + 12,
        size.height * 0.62,
      );

    canvas.drawPath(path, wave);
  }

  @override
  bool shouldRepaint(covariant _HeaderWaves oldDelegate) => false;
}
