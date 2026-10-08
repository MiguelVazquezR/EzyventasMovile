import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/service_orders/data/models/custom_field_definition.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/custom_fields_read_view.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/pattern_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las siete definiciones de §3, ya ordenadas por `name` como las manda la API.
List<CustomFieldDefinition> _definitions() => <CustomFieldDefinition>[
  const CustomFieldDefinition(
    key: 'accesorios',
    name: 'Accesorios recibidos',
    type: 'checkbox',
    options: <String>['Funda', 'Mica', 'Cargador', 'Memoria SD'],
  ),
  const CustomFieldDefinition(key: 'imei', name: 'IMEI', type: 'number'),
  const CustomFieldDefinition(
    key: 'notas_equipo',
    name: 'Notas del equipo',
    type: 'textarea',
  ),
  const CustomFieldDefinition(
    key: 'patron',
    name: 'Patrón de pantalla',
    type: 'pattern',
  ),
  const CustomFieldDefinition(
    key: 'pin_desbloqueo',
    name: 'PIN de desbloqueo',
    type: 'text',
  ),
  const CustomFieldDefinition(
    key: 'tipo_equipo',
    name: 'Tipo de equipo',
    type: 'select',
    options: <String>['Celular', 'Tablet', 'Laptop'],
  ),
  const CustomFieldDefinition(
    key: 'con_cargador',
    name: '¿Incluye cargador?',
    type: 'boolean',
  ),
];

/// La orden real de §4.1.
Map<String, dynamic> _values() => <String, dynamic>{
  'accesorios': <String>['Funda', 'Mica'],
  'con_cargador': true,
  'imei': 356938035643809,
  'notas_equipo': 'Golpe en la esquina inferior derecha.',
  'patron': <String, dynamic>{
    'type': 'pattern',
    'value': <int>[1, 2, 3, 5, 7, 8, 9],
  },
  'pin_desbloqueo': '1234',
  'tipo_equipo': 'Celular',
};

/// Solo las definiciones indicadas, para acotar lo que se pinta.
List<CustomFieldDefinition> _only(List<String> keys) => _definitions()
    .where((definition) => keys.contains(definition.key))
    .toList(growable: false);

Widget _wrap(
  Map<String, dynamic> values, {
  List<CustomFieldDefinition>? definitions,
}) => MaterialApp(
  theme: EzyTheme.dark(),
  home: Scaffold(
    body: SingleChildScrollView(
      child: CustomFieldsReadCard(
        definitions: definitions ?? _definitions(),
        values: values,
      ),
    ),
  ),
);

void main() {
  testWidgets('pinta los siete tipos como datos, nunca como JSON (§9.2)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_values()));
    await tester.pumpAndSettle();

    expect(find.text('DETALLES ADICIONALES'), findsOneWidget);
    expect(find.text('Información personalizada del servicio'), findsOneWidget);

    // Rótulos: el `name` que configuró el taller.
    expect(find.text('PIN de desbloqueo'), findsOneWidget);
    expect(find.text('Tipo de equipo'), findsOneWidget);

    // Texto, número, selección y booleano.
    expect(find.text('356938035643809'), findsOneWidget);
    expect(find.text('Celular'), findsOneWidget);
    expect(find.text('Golpe en la esquina inferior derecha.'), findsOneWidget);
    expect(find.text('Sí'), findsOneWidget);

    // Patrón dibujado en solo lectura, con sus puntos en orden.
    expect(find.byType(PatternInput), findsOneWidget);
    expect(find.text('Puntos en orden: 1 → 2 → 3 → 5 → 7 → 8 → 9'), findsOneWidget);

    // Checkbox: todas las opciones, marcadas o tachadas.
    for (final option in <String>['Funda', 'Mica', 'Cargador', 'Memoria SD']) {
      expect(find.text(option), findsOneWidget, reason: option);
    }
    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(2));

    // La contraseña se cubre en su propia prueba; aquí el patrón va dibujado.
    expect(find.text('Ver contraseña'), findsNothing);

    // Nunca el JSON crudo.
    expect(find.textContaining('"type"'), findsNothing);
    expect(find.textContaining('value'), findsNothing);
  });

  testWidgets('los valores vacíos se rotulan N/A (§8.3 y §9.2)', (tester) async {
    await tester.pumpWidget(
      _wrap(
        <String, dynamic>{
          'patron': <int>[],
          'pin_desbloqueo': null,
          'tipo_equipo': '',
        },
        definitions: _only(<String>['patron', 'pin_desbloqueo', 'tipo_equipo']),
      ),
    );
    await tester.pumpAndSettle();

    // Patrón borrado, texto nulo (o ausente) y select vacío.
    expect(find.text('N/A'), findsNWidgets(3));
    expect(find.byType(PatternInput), findsNothing);
  });

  testWidgets('la contraseña del patrón se enmascara y se puede ver (§8.1)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        <String, dynamic>{
          'patron': <String, dynamic>{'type': 'password', 'value': '1234'},
        },
        definitions: _only(<String>['patron']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('••••'), findsOneWidget);
    expect(find.text('1234'), findsNothing);

    await tester.tap(find.text('Ver contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('1234'), findsOneWidget);
    expect(find.text('••••'), findsNothing);
    expect(find.byType(PatternInput), findsNothing);
  });

  testWidgets('un checkbox sin selección lista todas las opciones tachadas', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        <String, dynamic>{'accesorios': <String>[]},
        definitions: _only(<String>['accesorios']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(find.byIcon(Icons.remove_circle_outline), findsNWidgets(4));
  });

  testWidgets('un booleano guardado como "1" se pinta como Sí', (tester) async {
    await tester.pumpWidget(_wrap(<String, dynamic>{'con_cargador': '1'}));
    await tester.pumpAndSettle();

    expect(find.text('Sí'), findsOneWidget);
  });

  testWidgets('las claves huérfanas se pintan al final con su etiqueta (§9.3)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(<String, dynamic>{
        'pin_desbloqueo': '4321',
        'campo_viejo': 'algo',
        'patron_viejo': <String, dynamic>{
          'type': 'pattern',
          'value': <int>[1, 4],
        },
        'accesorios_viejos': <String>['Funda', 'Mica'],
      }),
    );
    await tester.pumpAndSettle();

    // `key` con guiones bajos → etiqueta legible, sin JSON.
    expect(find.text('Campo viejo'), findsOneWidget);
    expect(find.text('algo'), findsOneWidget);
    expect(find.text('Patron viejo'), findsOneWidget);
    // El patrón huérfano también se dibuja como tablero.
    expect(find.byType(PatternInput), findsOneWidget);
    expect(find.text('Puntos en orden: 1 → 4'), findsOneWidget);
    expect(find.text('Funda, Mica'), findsOneWidget);
  });

  testWidgets('sin ninguna clave la sección no se pinta (custom_fields {})', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const <String, dynamic>{}));
    await tester.pumpAndSettle();

    expect(find.text('DETALLES ADICIONALES'), findsNothing);
    expect(find.text('N/A'), findsNothing);
  });
}
