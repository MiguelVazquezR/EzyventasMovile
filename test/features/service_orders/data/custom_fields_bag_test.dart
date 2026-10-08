import 'package:ezyventas_app/features/service_orders/data/models/custom_field_definition.dart';
import 'package:ezyventas_app/features/service_orders/data/models/custom_field_value.dart';
import 'package:ezyventas_app/features/service_orders/data/models/custom_fields_bag.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_form.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las siete definiciones del catálogo (doc 04 §3).
List<CustomFieldDefinition> _definitions() => <CustomFieldDefinition>[
  const CustomFieldDefinition(
    key: 'accesorios',
    name: 'Accesorios recibidos',
    type: 'checkbox',
    options: <String>['Funda', 'Mica', 'Cargador', 'Memoria SD'],
  ),
  const CustomFieldDefinition(
    key: 'imei',
    name: 'IMEI',
    type: 'number',
    isRequired: true,
  ),
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

void main() {
  group('CustomFieldsBag.initialFor (doc 04 §5)', () {
    test('una entrada por definición, en el orden de la API', () {
      final bag = CustomFieldsBag.initialFor(_definitions());

      expect(bag.values.keys, <String>[
        'accesorios',
        'imei',
        'notas_equipo',
        'patron',
        'pin_desbloqueo',
        'tipo_equipo',
        'con_cargador',
      ]);

      // Iniciales de la web: switch apagado y checkbox/patrón como arreglo
      // vacío; el resto en `null` (no se inventan ceros).
      expect(bag.raw('imei'), isNull);
      expect(bag.raw('notas_equipo'), isNull);
      expect(bag.raw('pin_desbloqueo'), isNull);
      expect(bag.raw('tipo_equipo'), isNull);
      expect(bag.raw('con_cargador'), isFalse);
      expect(bag.raw('accesorios'), isEmpty);
      expect(bag.raw('patron'), <int>[]);
    });

    test('lo ya guardado manda y llega normalizado', () {
      final bag = CustomFieldsBag.initialFor(
        _definitions(),
        stored: <String, dynamic>{
          'accesorios': 'Funda, Mica',
          'imei': '356938035643809',
          'con_cargador': '1',
          'patron': <String, dynamic>{
            'type': 'pattern',
            'value': <int>[1, 4, 7],
          },
        },
      );

      expect(bag.raw('accesorios'), <String>['Funda', 'Mica']);
      expect(bag.raw('imei'), 356938035643809);
      expect(bag.raw('con_cargador'), isTrue);
      expect(bag.raw('patron'), <String, dynamic>{
        'type': 'pattern',
        'value': <int>[1, 4, 7],
      });
    });

    test('conserva las claves huérfanas al final, sin tocarlas', () {
      final bag = CustomFieldsBag.initialFor(
        _definitions(),
        stored: <String, dynamic>{'campo_viejo': 'algo', 'imei': '12'},
      );

      expect(bag.raw('campo_viejo'), 'algo');
      expect(bag.values.keys.last, 'campo_viejo');
      expect(bag.orphanKeys(_definitions()), <String>['campo_viejo']);
    });
  });

  group('serialización del payload (§4 y §6)', () {
    test('viaja con tipos reales, nunca como cadena JSON', () {
      final bag = CustomFieldsBag.initialFor(
        _definitions(),
        stored: <String, dynamic>{'imei': 356938035643809},
      )
          .withValue('tipo_equipo', 'Celular')
          .withValue('con_cargador', false)
          .withValue('accesorios', <String>['Funda', 'Mica'])
          .withValue(
            'patron',
            const PatternValue.pattern(<int>[1, 2, 3]).toJson(),
          );

      final json = bag.toJson();

      expect(json['imei'], 356938035643809);
      expect(json['tipo_equipo'], 'Celular');
      // `false` de verdad: con la cadena `"false"` el servidor guarda un string.
      expect(json['con_cargador'], isFalse);
      expect(json['accesorios'], <String>['Funda', 'Mica']);
      expect(json['patron'], <String, dynamic>{
        'type': 'pattern',
        'value': <int>[1, 2, 3],
      });
    });

    test('withValue no muta la bolsa original', () {
      final original = CustomFieldsBag.initialFor(_definitions());
      final updated = original.withValue('imei', 12);

      expect(original.raw('imei'), isNull);
      expect(updated.raw('imei'), 12);
      expect(updated.containsKey('imei'), isTrue);
    });

    test('fromJson conserva tal cual lo que llega del servidor', () {
      final bag = CustomFieldsBag.fromJson(<String, dynamic>{
        'con_cargador': '1',
        'patron': <String>[],
      });

      expect(bag.raw('con_cargador'), '1');
      expect(bag.raw('patron'), isEmpty);
      expect(CustomFieldsBag.empty().isEmpty, isTrue);
    });

    test('el alta manda la bolsa completa con los iniciales de §5', () {
      final fields = ServiceOrderFormData(
        customerName: 'Ana',
        itemDescription: 'iPhone 13',
        reportedProblems: 'No enciende',
        customFields: CustomFieldsBag.initialFor(_definitions()).toJson(),
      ).toFields(isUpdate: false, multipart: false, sessionId: 41);

      final bag = fields['custom_fields'] as Map<String, dynamic>;

      expect(bag.keys.length, _definitions().length);
      // El switch apagado y el checkbox vacío viajan con su tipo real.
      expect(bag['con_cargador'], isFalse);
      expect(bag['accesorios'], isEmpty);
      expect(bag['patron'], isEmpty);
      expect(bag['imei'], isNull);
    });
  });

  group('lectura tipada', () {
    test('typed() usa el tipo de la definición y no el del valor', () {
      final bag = CustomFieldsBag.fromJson(<String, dynamic>{
        'con_cargador': '1',
        'imei': '12',
        'accesorios': <String>['Funda'],
        'patron': <String, dynamic>{'type': 'password', 'value': '1234'},
        'tipo_equipo': 'Celular',
        'pin_desbloqueo': '1234',
        'notas_equipo': 'Golpe en la esquina',
      });

      for (final definition in _definitions()) {
        final value = bag.typed(definition);

        switch (definition.key) {
          case 'con_cargador':
            expect(value, isA<BoolValue>());
            expect(value.toJson(), isTrue);
          case 'imei':
            expect(value, isA<NumberValue>());
            expect(value.toJson(), 12);
          case 'accesorios':
            expect(value, isA<MultiOptionValue>());
            expect(value.toJson(), <String>['Funda']);
          case 'patron':
            expect(value, isA<PatternValue>());
            expect((value as PatternValue).mode, 'password');
          case 'tipo_equipo':
            expect(value, isA<SingleOptionValue>());
            expect(value.toJson(), 'Celular');
          default:
            expect(value, isA<TextValue>());
            expect(
              value.toJson(),
              definition.key == 'pin_desbloqueo' ? '1234' : 'Golpe en la esquina',
            );
        }
      }
    });
  });
}
