import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import 'service_order_form_controls.dart';

/// Tablero de desbloqueo 3×3 del tipo `pattern` (doc 04 §8.2 y §8.5).
///
/// Un solo widget para los dos usos: con `onChanged` captura el trazo (editor)
/// y con `readOnly` solo lo pinta (vista de la orden, §8.5.6).
///
/// La numeración coincide con `PatternLock.vue` de la web: fila por fila, de
/// izquierda a derecha y de arriba hacia abajo (`x = i % 3`, `y = i ~/ 3`,
/// id = `i + 1`), así que un patrón en «L» es `[1, 4, 7, 8, 9]`.
///
/// El tablero se queda con el gesto desde que el dedo toca la cuadrícula
/// ([_BoardPanGestureRecognizer] gana la arena de gestos sin umbral), así que
/// el scroll del formulario no lo roba y se puede trazar en cualquier
/// dirección.
class PatternInput extends StatefulWidget {
  const PatternInput({
    super.key,
    required this.points,
    this.onChanged,
    this.readOnly = false,
    this.side = 240,
  });

  /// Puntos en **orden de trazo** (no ordenados).
  final List<int> points;

  /// Sin él el tablero es de solo lectura (no hay gestos).
  final ValueChanged<List<int>>? onChanged;
  final bool readOnly;

  /// Lado del tablero cuadrado; se recorta si el hueco disponible es menor.
  final double side;

  /// Lado de la cuadrícula (3×3 = 9 puntos).
  static const int gridSize = 3;
  static const int pointCount = 9;

  /// Centro del punto [point] dentro de un tablero [size], con la esquina
  /// superior izquierda como origen. Es la misma fórmula del pintor, así que
  /// sirve para calcular los destinos de un gesto en las pruebas.
  static Offset centerOf(int point, Size size) {
    final column = (point - 1) % gridSize;
    final row = (point - 1) ~/ gridSize;
    final cell = size.width / gridSize;

    return Offset(cell * (column + 0.5), cell * (row + 0.5));
  }

  /// Punto tocado por una posición local; `null` fuera del tablero. El área de
  /// toque de cada punto es su celda completa (el dedo no es un ratón).
  static int? pointAt(Offset local, Size size) {
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= size.width ||
        local.dy >= size.height) {
      return null;
    }

    final column = (local.dx / (size.width / gridSize)).floor().clamp(
      0,
      gridSize - 1,
    );
    final row = (local.dy / (size.height / gridSize)).floor().clamp(
      0,
      gridSize - 1,
    );

    return row * gridSize + column + 1;
  }

  @override
  State<PatternInput> createState() => _PatternInputState();
}

class _PatternInputState extends State<PatternInput> {
  late List<int> _points = List<int>.of(widget.points);

  /// Último tamaño pintado; el reconocedor de gestos lo consulta porque se
  /// registra una sola vez y no ve los `size` de builds posteriores.
  late Size _board = Size.square(widget.side);

  @override
  void didUpdateWidget(covariant PatternInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // El padre manda (carga de la orden, limpiar): si su valor no coincide con
    // el trazo en curso, se adopta.
    if (!listEquals(widget.points, _points)) {
      _points = List<int>.of(widget.points);
    }
  }

  void _touch(Offset local, Size size) {
    final point = PatternInput.pointAt(local, size);

    if (point == null || _points.contains(point)) {
      return;
    }

    final next = <int>[..._points, point];

    setState(() => _points = next);
    widget.onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final interactable = !widget.readOnly && widget.onChanged != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.hasBoundedWidth
            ? math.min(widget.side, constraints.maxWidth)
            : widget.side;
        final size = Size.square(side);

        _board = size;

        final board = CustomPaint(
          size: size,
          painter: _PatternPainter(
            points: _points,
            idleColor: SoColors.structuralBorder(context),
            activeColor: SoColors.primary,
            numberColor: SoColors.textSecondary(context),
          ),
        );

        if (!interactable) {
          return SizedBox(width: side, height: side, child: board);
        }

        // El tablero bloquea el scroll mientras el dedo está dentro: gana la
        // arena al instante, así que el trazo sale en cualquier dirección.
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _BoardPanGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<_BoardPanGestureRecognizer>(
                  () => _BoardPanGestureRecognizer(debugOwner: this),
                  (recognizer) {
                    recognizer.onStart = (details) {
                      _touch(details.localPosition, _board);
                    };
                    recognizer.onUpdate = (details) {
                      _touch(details.localPosition, _board);
                    };
                  },
                ),
          },
          child: SizedBox(width: side, height: side, child: board),
        );
      },
    );
  }
}

/// Arrastre que se queda con el gesto ya en el `pointer down`.
///
/// Un `PanGestureRecognizer` normal acepta al superar 36 px y el scroll del
/// formulario solo necesita 18 px, así que el scroll ganaba el deslizamiento
/// vertical. Aceptando de entrada la arena se resuelve a favor del tablero y
/// el scroll queda bloqueado mientras el dedo esté dentro de la cuadrícula.
class _BoardPanGestureRecognizer extends PanGestureRecognizer {
  _BoardPanGestureRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// Pinta la cuadrícula, los nueve puntos numerados y el trazo en su orden.
class _PatternPainter extends CustomPainter {
  const _PatternPainter({
    required this.points,
    required this.idleColor,
    required this.activeColor,
    required this.numberColor,
  });

  final List<int> points;
  final Color idleColor;
  final Color activeColor;
  final Color numberColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / PatternInput.gridSize;
    final dotRadius = cell * 0.24;

    // Cuadrícula: las divisiones del diagrama de §8.2.
    final grid = Paint()
      ..color = idleColor
      ..strokeWidth = 1;

    for (var index = 1; index < PatternInput.gridSize; index++) {
      final offset = cell * index;
      canvas.drawLine(Offset(offset, 0), Offset(offset, size.height), grid);
      canvas.drawLine(Offset(0, offset), Offset(size.width, offset), grid);
    }

    // Trazo del dedo, en el orden en que se tocaron los puntos.
    if (points.length > 1) {
      final path = Path();

      for (var index = 0; index < points.length; index++) {
        final center = PatternInput.centerOf(points[index], size);

        if (index == 0) {
          path.moveTo(center.dx, center.dy);
        } else {
          path.lineTo(center.dx, center.dy);
        }
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = activeColor
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    for (var point = 1; point <= PatternInput.pointCount; point++) {
      final center = PatternInput.centerOf(point, size);
      final selected = points.contains(point);

      if (selected) {
        canvas.drawCircle(center, dotRadius, Paint()..color = activeColor);
      } else {
        canvas.drawCircle(
          center,
          dotRadius,
          Paint()
            ..color = idleColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      final label = TextPainter(
        text: TextSpan(
          text: '$point',
          style: EzyTextStyles.caption.copyWith(
            fontSize: cell * 0.3,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFFFFFFFF) : numberColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) =>
      !listEquals(oldDelegate.points, points) ||
      oldDelegate.idleColor != idleColor ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.numberColor != numberColor;
}

