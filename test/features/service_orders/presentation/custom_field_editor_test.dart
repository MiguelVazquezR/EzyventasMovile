import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_chip.dart';
import 'package:ezyventas_app/core/widgets/ezy_selectable_tile.dart';
import 'package:ezyventas_app/core/widgets/ezy_text_field.dart';
import 'package:ezyventas_app/features/service_orders/data/models/custom_field_definition.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/custom_field_editor.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/pattern_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CustomFieldDefinition _definition(
  String type, {
  String key = 'campo',
  String name = 'Campo',
  List<String> options = const <String>[],
  bool isRequired = false,
}) => CustomFieldDefinition(
  key: key,
  name: name,
  type: type,
  options: options,
  isRequired: isRequired,
);

/// El editor tal como lo monta el formulario: dentro de un ancho real y con el
/// valor en estado (el formulario guarda la bolsa y la vuelve a pasar).
Widget _wrap(
  CustomFieldDefinition definition,
  Object? value,
  ValueChanged<Object?> onChanged,
) => _Harness(
  definition: definition,
  initial: value,
  onEmitted: onChanged,
);

class _Harness extends StatefulWidget {
  const _Harness({
    required this.definition,
    required this.initial,
    required this.onEmitted,
  });

  final CustomFieldDefinition definition;
  final Object? initial;
  final ValueChanged<Object?> onEmitted;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  Object? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initial;
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: EzyTheme.dark(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: 360,
          child: buildCustomFieldEditor(widget.definition, _value, (value) {
            setState(() => _value = value);
            widget.onEmitted(value);
          }),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('cada tipo dibuja su control, no texto genérico (doc 04 §9.1)', (
    tester,
  ) async {
    Future<void> pump(CustomFieldDefinition definition, {Object? value}) async {
      await tester.pumpWidget(_wrap(definition, value, (_) {}));
    }

    await pump(_definition('text', name: 'PIN de desbloqueo', isRequired: true));
    // La micro-etiqueta va en mayúsculas y marca el obligatorio.
    expect(find.text('PIN DE DESBLOQUEO *'), findsOneWidget);
    expect(tester.widget<EzyTextField>(find.byType(EzyTextField)).maxLines, 1);

    await pump(_definition('textarea'));
    expect(tester.widget<EzyTextField>(find.byType(EzyTextField)).maxLines, 4);

    await pump(_definition('number'));
    expect(
      tester.widget<EzyTextField>(find.byType(EzyTextField)).keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );

    await pump(_definition('boolean'));
    expect(find.byType(Switch), findsOneWidget);

    await pump(
      _definition('select', options: <String>['Celular', 'Tablet', 'Laptop']),
    );
    expect(
      tester.widget<EzyTextField>(find.byType(EzyTextField)).readOnly,
      isTrue,
    );

    await pump(
      _definition('checkbox', options: <String>['Funda', 'Mica']),
    );
    expect(find.byType(EzyChip), findsNWidgets(2));

    await pump(_definition('pattern'));
    expect(find.byType(PatternInput), findsOneWidget);
    expect(find.text('Patrón'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);

    // Tipo nuevo del backend: degrada a caja de texto, nunca rompe.
    await pump(_definition('firma'));
    expect(find.byType(EzyTextField), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('el number emite num y null al vaciarse', (tester) async {
    final emitted = <Object?>[];

    await tester.pumpWidget(
      _wrap(_definition('number', key: 'imei'), null, emitted.add),
    );
    await tester.enterText(find.byType(EzyTextField), '356938035643809');
    await tester.pump();

    expect(emitted.last, 356938035643809);

    await tester.enterText(find.byType(EzyTextField), '');
    await tester.pump();

    expect(emitted.last, isNull);
  });

  testWidgets('el boolean emite booleanos reales', (tester) async {
    final emitted = <Object?>[];

    await tester.pumpWidget(
      _wrap(_definition('boolean'), false, emitted.add),
    );
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(emitted, <Object?>[true]);
  });

  testWidgets('el select abre la hoja con las opciones en el orden de la API', (
    tester,
  ) async {
    final emitted = <Object?>[];

    await tester.pumpWidget(
      _wrap(
        _definition(
          'select',
          key: 'tipo_equipo',
          options: <String>['Celular', 'Tablet', 'Laptop'],
        ),
        null,
        emitted.add,
      ),
    );

    await tester.tap(find.byType(EzyTextField));
    await tester.pumpAndSettle();

    final tiles = tester
        .widgetList<EzySelectableTile>(find.byType(EzySelectableTile))
        .toList();

    expect(
      tiles.map((tile) => tile.title),
      <String>['Celular', 'Tablet', 'Laptop'],
    );

    await tester.tap(find.text('Tablet'));
    await tester.pumpAndSettle();

    expect(emitted, <Object?>['Tablet']);
  });

  testWidgets('un valor fuera de las opciones no se descarta (§4)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _definition('select', options: <String>['Celular', 'Tablet']),
        'Laptop',
        (_) {},
      ),
    );

    final field = tester.widget<EzyTextField>(find.byType(EzyTextField));

    expect(field.controller?.text, 'Laptop');
    expect(field.helperText, 'Ya no está entre las opciones configuradas.');
  });

  testWidgets('select y checkbox sin opciones se apagan (§11)', (tester) async {
    await tester.pumpWidget(
      _wrap(_definition('select', options: <String>[]), null, (_) {}),
    );

    expect(find.text('Sin opciones configuradas'), findsOneWidget);
    expect(find.byType(EzyChip), findsNothing);

    await tester.pumpWidget(
      _wrap(_definition('checkbox', options: <String>[]), null, (_) {}),
    );

    expect(find.text('Sin opciones configuradas'), findsOneWidget);
    expect(find.byType(EzyTextField), findsNothing);
  });

  testWidgets('el checkbox emite la lista en el orden de las opciones', (
    tester,
  ) async {
    final emitted = <Object?>[];

    await tester.pumpWidget(
      _wrap(
        _definition(
          'checkbox',
          key: 'accesorios',
          options: <String>['Funda', 'Mica', 'Cargador'],
        ),
        <String>['Mica'],
        emitted.add,
      ),
    );

    expect(find.byType(EzyChip), findsNWidgets(3));

    await tester.tap(find.text('Funda'));
    await tester.pump();

    // El orden lo manda el catálogo de opciones, no el orden de los toques.
    expect(emitted.last, <String>['Funda', 'Mica']);

    await tester.tap(find.text('Mica'));
    await tester.pump();

    expect(emitted.last, <String>['Funda']);
  });

  testWidgets('el checkbox conserva un valor que ya no está en las opciones', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _definition('checkbox', options: <String>['Funda', 'Mica']),
        <String>['Funda', 'Obsoleta'],
        (_) {},
      ),
    );

    // El valor huérfano se agrega como chip extra para no perderlo.
    expect(find.text('Obsoleta'), findsOneWidget);
    expect(find.byType(EzyChip), findsNWidgets(3));
  });

  testWidgets('el patrón dibujado emite el objeto completo (§8.5)', (
    tester,
  ) async {
    final emitted = <Object?>[];

    await tester.pumpWidget(
      _wrap(_definition('pattern', key: 'patron'), <int>[], emitted.add),
    );

    final origin = tester.getTopLeft(find.byType(PatternInput));
    Offset at(int point) => origin + PatternInput.centerOf(point, const Size(240, 240));

    final gesture = await tester.startGesture(at(1));
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveTo(at(4));
    await gesture.moveTo(at(5));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(emitted.last, <String, dynamic>{
      'type': 'pattern',
      'value': <int>[1, 4, 5],
    });
    expect(find.text('Puntos en orden: 1 → 4 → 5'), findsOneWidget);
  });

  testWidgets('limpiar el patrón emite value vacío, nunca null (§8.5.4)', (
    tester,
  ) async {
    final emitted = <Object?>[];

    await tester.pumpWidget(
      _wrap(
        _definition('pattern', key: 'patron'),
        <int>[1, 2, 3],
        emitted.add,
      ),
    );

    await tester.tap(find.text('Limpiar'));
    await tester.pumpAndSettle();

    expect(emitted, <Object?>[
      <String, dynamic>{'type': 'pattern', 'value': <int>[]},
    ]);
  });

  testWidgets('cambiar a contraseña emite el modo con valor vacío (§8.5.5)', (
    tester,
  ) async {
    final emitted = <Object?>[];

    await tester.pumpWidget(
      _wrap(
        _definition('pattern', key: 'patron'),
        <String, dynamic>{
          'type': 'pattern',
          'value': <int>[1, 2],
        },
        emitted.add,
      ),
    );

    await tester.tap(find.text('Contraseña'));
    await tester.pumpAndSettle();

    expect(emitted.last, <String, dynamic>{
      'type': 'password',
      'value': '',
    });

    await tester.enterText(find.byType(EzyTextField), '1234');
    await tester.pump();

    expect(emitted.last, <String, dynamic>{
      'type': 'password',
      'value': '1234',
    });
  });
}
