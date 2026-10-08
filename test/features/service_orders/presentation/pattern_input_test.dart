import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/pattern_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Size _board = Size(240, 240);

Widget _wrap(Widget child) => MaterialApp(
  theme: EzyTheme.dark(),
  home: Scaffold(
    body: Center(child: SizedBox(width: _board.width, height: _board.height, child: child)),
  ),
);

void main() {
  group('geometría del tablero 3×3 (doc 04 §8.2)', () {
    test('el punto 1 es la esquina superior izquierda y el 9 la inferior', () {
      expect(PatternInput.centerOf(1, _board), const Offset(40, 40));
      expect(PatternInput.centerOf(5, _board), const Offset(120, 120));
      expect(PatternInput.centerOf(9, _board), const Offset(200, 200));

      expect(PatternInput.pointAt(const Offset(40, 40), _board), 1);
      expect(PatternInput.pointAt(const Offset(200, 200), _board), 9);
    });

    test('la numeración va fila por fila (fila del medio = 4, 5, 6)', () {
      expect(PatternInput.pointAt(const Offset(40, 120), _board), 4);
      expect(PatternInput.pointAt(const Offset(120, 120), _board), 5);
      expect(PatternInput.pointAt(const Offset(200, 120), _board), 6);
      expect(PatternInput.pointAt(const Offset(120, 200), _board), 8);
      expect(PatternInput.pointAt(const Offset(200, 40), _board), 3);
    });

    test('fuera del tablero no hay punto', () {
      expect(PatternInput.pointAt(const Offset(-1, 10), _board), isNull);
      expect(PatternInput.pointAt(const Offset(10, -1), _board), isNull);
      expect(PatternInput.pointAt(const Offset(240, 240), _board), isNull);
    });
  });

  testWidgets('el trazo se captura en el orden del gesto (patrón en L)', (
    tester,
  ) async {
    List<int>? captured;

    await tester.pumpWidget(
      _wrap(
        PatternInput(
          points: const <int>[],
          onChanged: (points) => captured = points,
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(PatternInput));
    Offset at(int point) => origin + PatternInput.centerOf(point, _board);

    final gesture = await tester.startGesture(at(1));
    // El primer movimiento solo supera el umbral táctil: sigue en la celda 1.
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveTo(at(4));
    await gesture.moveTo(at(7));
    await gesture.moveTo(at(8));
    await gesture.moveTo(at(9));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(captured, <int>[1, 4, 7, 8, 9]);
  });

  testWidgets('un punto ya tocado no se repite al volver a pasar por él', (
    tester,
  ) async {
    List<int>? captured;

    await tester.pumpWidget(
      _wrap(
        PatternInput(
          points: const <int>[],
          onChanged: (points) => captured = points,
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(PatternInput));
    Offset at(int point) => origin + PatternInput.centerOf(point, _board);

    final gesture = await tester.startGesture(at(1));
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveTo(at(4));
    await gesture.moveTo(at(1));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(captured, <int>[1, 4]);
  });

  testWidgets('deslizar dentro del tablero bloquea el scroll del formulario', (
    tester,
  ) async {
    final controller = ScrollController();
    List<int>? captured;

    await tester.pumpWidget(
      MaterialApp(
        theme: EzyTheme.dark(),
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: <Widget>[
              const SizedBox(height: 100),
              Center(
                child: PatternInput(
                  points: const <int>[],
                  onChanged: (points) => captured = points,
                ),
              ),
              const SizedBox(height: 400),
            ],
          ),
        ),
      ),
    );

    final origin = tester.getTopLeft(find.byType(PatternInput));
    Offset at(int point) => origin + PatternInput.centerOf(point, _board);

    // Deslizamiento vertical dentro de la cuadrícula: se traza, no se scrollea.
    final gesture = await tester.startGesture(at(1));
    await gesture.moveTo(at(4));
    await gesture.moveTo(at(7));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
    expect(captured, <int>[1, 4, 7]);
  });

  testWidgets('en solo lectura el tablero se pinta sin gestos (§8.5.6)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const PatternInput(points: <int>[1, 2, 3], readOnly: true)),
    );

    // Sin gestos: el tablero no registra interacción alguna.
    expect(find.byType(GestureDetector), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
