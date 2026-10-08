import 'package:ezyventas_app/features/service_orders/data/models/custom_field_definition.dart';
import 'package:ezyventas_app/features/service_orders/data/models/custom_field_normalizers.dart';
import 'package:ezyventas_app/features/service_orders/data/models/custom_field_value.dart';
import 'package:flutter_test/flutter_test.dart';

CustomFieldDefinition _definition(String type) =>
    CustomFieldDefinition(key: 'campo', name: 'Campo', type: type);

void main() {
  group('isBlank', () {
    test('reconoce nulos, cadenas vacías y colecciones sin contenido', () {
      expect(isBlank(null), isTrue);
      expect(isBlank('   '), isTrue);
      expect(isBlank(<String>[]), isTrue);
      expect(isBlank(<String, dynamic>{}), isTrue);
      expect(isBlank(0), isFalse);
      expect(isBlank(false), isFalse);
    });
  });

  group('normalizeBool', () {
    test('acepta booleanos reales y las variantes del servidor (§7.1)', () {
      for (final truthy in <Object?>[
        true,
        1,
        '1',
        'true',
        'si',
        'sí',
        ' TRUE ',
      ]) {
        expect(normalizeBool(truthy), isTrue, reason: '$truthy');
      }

      for (final falsy in <Object?>[false, 0, '0', 'false', 'no', null, '']) {
        expect(normalizeBool(falsy), isFalse, reason: '$falsy');
      }
    });
  });

  group('normalizeList', () {
    test('arreglo, texto histórico separado por comas y valor suelto', () {
      expect(normalizeList(<String>['Funda', 'Mica']), <String>[
        'Funda',
        'Mica',
      ]);
      expect(normalizeList('Funda, Mica'), <String>['Funda', 'Mica']);
      expect(normalizeList(' Funda '), <String>['Funda']);
      expect(normalizeList(null), isEmpty);
      // Sin repetidos ni vacíos.
      expect(normalizeList(<String>['Funda', 'Funda', '']), <String>['Funda']);
    });
  });

  group('normalizeNumber', () {
    test('acepta número y cadena numérica; el vacío es null', () {
      expect(normalizeNumber(12), 12);
      expect(normalizeNumber('12'), 12);
      expect(normalizeNumber('356938035643809'), 356938035643809);
      expect(normalizeNumber(''), isNull);
      expect(normalizeNumber(null), isNull);
      expect(normalizeNumber('doce'), isNull);
    });
  });

  group('normalizePattern (doc 04 §8.3)', () {
    test('patrón dibujado, con puntos como número o como string', () {
      final drawn = normalizePattern(<String, dynamic>{
        'type': 'pattern',
        'value': <int>[1, 2, 3],
      });

      expect(drawn.mode, 'pattern');
      expect(drawn.points, <int>[1, 2, 3]);
      expect(drawn.isBlank, isFalse);

      // Multipart: los puntos llegan como strings (§4.2).
      final multipart = normalizePattern(<String, dynamic>{
        'type': 'pattern',
        'value': <String>['1', '2', '3', '5', '7', '8', '9'],
      });

      expect(multipart.points, <int>[1, 2, 3, 5, 7, 8, 9]);
    });

    test('contraseña escrita', () {
      final password = normalizePattern(<String, dynamic>{
        'type': 'password',
        'value': '1234',
      });

      expect(password.mode, 'password');
      expect(password.password, '1234');
      expect(password.points, isEmpty);
      expect(password.maskedPassword, '••••');
      expect(password.isBlank, isFalse);
    });

    test('los cuatro estados sin valor se leen como patrón vacío', () {
      for (final empty in <Object?>[
        null,
        <String, dynamic>{},
        <int>[],
        <String, dynamic>{'type': 'pattern', 'value': <int>[]},
      ]) {
        final value = normalizePattern(empty);

        expect(value.mode, 'pattern', reason: '$empty');
        expect(value.points, isEmpty, reason: '$empty');
        expect(value.isBlank, isTrue, reason: '$empty');
        expect(value.toJson(), <String, dynamic>{
          'type': 'pattern',
          'value': <int>[],
        });
      }
    });

    test('un mapa sin type (histórico) y un string suelto también se toleran', () {
      expect(normalizePattern(<String, dynamic>{'value': <int>[1, 5]}).points, <int>[
        1,
        5,
      ]);
      expect(normalizePattern('4321').password, '4321');
      // Puntos fuera del tablero se descartan.
      expect(
        normalizePattern(<String, dynamic>{'value': <int>[0, 4, 10]}).points,
        <int>[4],
      );
    });

    test('serializa siempre el objeto completo, nunca un arreglo suelto', () {
      expect(const PatternValue.pattern(<int>[1, 4, 5, 8]).toJson(), <String, dynamic>{
        'type': 'pattern',
        'value': <int>[1, 4, 5, 8],
      });
      expect(
        const PatternValue.password('1234').toJson(),
        <String, dynamic>{'type': 'password', 'value': '1234'},
      );
      // Limpiar deja el objeto con el valor vacío del modo activo (§8.5.4).
      expect(
        const PatternValue.pattern(<int>[]).toJson(),
        <String, dynamic>{'type': 'pattern', 'value': <int>[]},
      );
      expect(
        const PatternValue.password('').toJson(),
        <String, dynamic>{'type': 'password', 'value': ''},
      );
    });
  });

  group('parseCustomFieldValue', () {
    test('el tipo lo dicta la definición, no el valor', () {
      expect(parseCustomFieldValue('boolean', '1'), isA<BoolValue>());
      expect(parseCustomFieldValue('boolean', '1').toJson(), isTrue);
      expect(parseCustomFieldValue('text', '1').toJson(), '1');
      expect(parseCustomFieldValue('number', '12').toJson(), 12);
      expect(parseCustomFieldValue('checkbox', 'Funda, Mica').toJson(), <String>[
        'Funda',
        'Mica',
      ]);
      expect(parseCustomFieldValue('select', 12).toJson(), '12');
      expect(parseCustomFieldValue('pattern', <int>[]).toJson(), <String, dynamic>{
        'type': 'pattern',
        'value': <int>[],
      });
    });

    test('un tipo desconocido degrada a texto sin romper', () {
      final value = parseCustomFieldValue('signature', 'garabato');

      expect(value, isA<TextValue>());
      expect(value.toJson(), 'garabato');
      expect(parseCustomFieldValue('signature', null).isBlank, isTrue);
    });
  });

  group('normalizeForType', () {
    test('deja cada valor en su forma canónica de envío', () {
      expect(normalizeForType('boolean', '1'), isTrue);
      expect(normalizeForType('boolean', '0'), isFalse);
      expect(normalizeForType('number', '12'), 12);
      expect(normalizeForType('checkbox', 'Funda, Mica'), <String>[
        'Funda',
        'Mica',
      ]);
      expect(normalizeForType('checkbox', null), isEmpty);
      expect(normalizeForType('pattern', <int>[]), <String, dynamic>{
        'type': 'pattern',
        'value': <int>[],
      });
      expect(normalizeForType('text', null), isNull);
      expect(normalizeForType('select', null), isNull);
    });
  });

  group('initialValueFor (doc 04 §5)', () {
    test('cada tipo arranca con el valor inicial de la web', () {
      expect(initialValueFor('text'), isNull);
      expect(initialValueFor('number'), isNull);
      expect(initialValueFor('textarea'), isNull);
      expect(initialValueFor('select'), isNull);
      expect(initialValueFor('boolean'), isFalse);
      expect(initialValueFor('checkbox'), isEmpty);
      // El patrón nace como arreglo vacío, igual que en la web.
      expect(initialValueFor('pattern'), <int>[]);
    });
  });

  group('labelFromKey', () {
    test('convierte el key huérfano en una etiqueta legible', () {
      expect(labelFromKey('pin_de_desbloqueo'), 'Pin de desbloqueo');
      expect(labelFromKey('imei'), 'Imei');
      expect(labelFromKey(''), 'Campo');
    });
  });

  group('las dos vías del contrato (§4.1 y §4.2) se leen igual', () {
    test('JSON con tipos reales y multipart degradado dan el mismo valor', () {
      final jsonValues = <String, dynamic>{
        'accesorios': <String>['Funda', 'Mica'],
        'con_cargador': true,
        'imei': 356938035643809,
        'tipo_equipo': 'Celular',
        'patron': <String, dynamic>{
          'type': 'pattern',
          'value': <int>[1, 2, 3, 5, 7, 8, 9],
        },
      };

      final multipartValues = <String, dynamic>{
        'accesorios': <String>['Funda', 'Mica'],
        'con_cargador': '1',
        'imei': '356938035643809',
        'tipo_equipo': 'Celular',
        'patron': <String, dynamic>{
          'type': 'pattern',
          'value': <String>['1', '2', '3', '5', '7', '8', '9'],
        },
      };

      final types = <String, String>{
        'accesorios': 'checkbox',
        'con_cargador': 'boolean',
        'imei': 'number',
        'tipo_equipo': 'select',
        'patron': 'pattern',
      };

      for (final entry in types.entries) {
        expect(
          parseCustomFieldValue(entry.value, multipartValues[entry.key]).toJson(),
          parseCustomFieldValue(entry.value, jsonValues[entry.key]).toJson(),
          reason: entry.key,
        );
      }
    });
  });

  group('CustomFieldDefinition', () {
    test('expone los siete tipos y degrada los que no conoce', () {
      for (final type in CustomFieldTypes.all) {
        expect(_definition(type).isKnown, isTrue, reason: type);
      }

      expect(_definition('text').isText, isTrue);
      expect(_definition('boolean').isBoolean, isTrue);
      expect(_definition('pattern').isPattern, isTrue);
      expect(_definition('firma-nueva').isKnown, isFalse);
    });

    test('marca los select/checkbox sin opciones configuradas (§11)', () {
      expect(_definition('select').hasNoOptions, isTrue);
      expect(_definition('text').hasNoOptions, isFalse);
      expect(
        const CustomFieldDefinition(
          key: 'tipo_equipo',
          name: 'Tipo de equipo',
          type: 'select',
          options: <String>['Celular'],
        ).hasNoOptions,
        isFalse,
      );
    });

    test('lee la definición del contrato y la vuelve a serializar igual', () {
      final definition = CustomFieldDefinition.fromJson(<String, dynamic>{
        'id': 7,
        'key': 'accesorios',
        'name': 'Accesorios recibidos',
        'type': 'checkbox',
        'options': <String>['Funda', 'Mica'],
        'is_required': false,
      });

      expect(definition.id, 7);
      expect(definition.options, <String>['Funda', 'Mica']);
      expect(definition.isRequired, isFalse);
      expect(definition.toJson()['key'], 'accesorios');
      expect(definition.toJson()['is_required'], isFalse);
      // Sin opciones se manda `null`, como la API.
      expect(_definition('text').toJson()['options'], isNull);
    });
  });
}
