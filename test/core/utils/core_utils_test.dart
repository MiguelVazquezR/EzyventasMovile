import 'package:ezyventas_app/core/theme/status_palette.dart';
import 'package:ezyventas_app/core/utils/app_formatters.dart';
import 'package:ezyventas_app/core/utils/json_reader.dart';
import 'package:ezyventas_app/core/utils/status_catalog.dart';
import 'package:ezyventas_app/core/utils/uuid_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // Igual que en `main.dart`: sin esto `DateFormat('...', 'es_MX')` no tiene
  // datos de locale.
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
  });

  group('StatusCatalog (design system §7)', () {
    test('traduce y colorea los estatus de venta', () {
      expect(StatusCatalog.transactionLabel('entregado_por_pagar'),
          'Entregado por pagar');
      expect(
        StatusCatalog.transactionSeverity('apartado'),
        EzySeverity.warn,
      );
      expect(StatusCatalog.transactionSeverity('completado'),
          EzySeverity.success);
      expect(StatusCatalog.transactionSeverity('cancelado'), EzySeverity.danger);
    });

    test('traduce y colorea los estatus de orden de servicio', () {
      expect(
        StatusCatalog.serviceOrderLabel('esperando_refaccion'),
        'Esperando refacción',
      );
      expect(
        StatusCatalog.serviceOrderSeverity('en_progreso'),
        EzySeverity.info,
      );
      expect(StatusCatalog.serviceOrderStepIndex('terminado'), 3);
      expect(StatusCatalog.serviceOrderStepIndex('cancelado'), -1);
    });

    test('un estatus desconocido se muestra tal cual, en gris', () {
      expect(StatusCatalog.transactionLabel('nuevo'), 'nuevo');
      expect(StatusCatalog.transactionSeverity('nuevo'), EzySeverity.neutral);
    });
  });

  group('JsonReader', () {
    test('tolera mapas, listas y tipos inesperados', () {
      expect(JsonReader.toMap(null), isEmpty);
      expect(JsonReader.toMap('texto'), isEmpty);
      expect(JsonReader.toMapList(<dynamic>[1, 'a']), isEmpty);
      expect(
        JsonReader.toMapList(<dynamic>[
          <String, dynamic>{'id': 1},
        ]),
        hasLength(1),
      );
      expect(JsonReader.string(12), '12');
      expect(JsonReader.string(null), isNull);
      expect(JsonReader.boolean(1), isTrue);
      expect(JsonReader.boolean('false'), isFalse);
      expect(JsonReader.integer('8'), 8);
      expect(JsonReader.stringList(<dynamic>['a', 'b']), <String>['a', 'b']);
      expect(JsonReader.stringList(null), isEmpty);
    });
  });

  group('AppFormatters', () {
    test('convierte ISO-8601 UTC a fecha local legible', () {
      final parsed = AppFormatters.parse('2026-09-18T14:35:00.000000Z');

      expect(parsed, isNotNull);
      expect(AppFormatters.dateTime(parsed), contains('2026'));
      expect(AppFormatters.date(null), '—');
      expect(AppFormatters.parse('no es fecha'), isNull);
    });

    test('initials arma el avatar', () {
      expect(AppFormatters.initials('María López'), 'ML');
      expect(AppFormatters.initials('Soporte'), 'S');
      expect(AppFormatters.initials('  '), '?');
      expect(AppFormatters.initials(null), '?');
    });

    test('apiDate usa el formato de los filtros', () {
      expect(AppFormatters.apiDate(DateTime(2026, 9, 18)), '2026-09-18');
    });
  });

  group('UuidGenerator', () {
    test('genera un UUID v4 válido y distinto en cada llamada', () {
      final uuid = UuidGenerator.v4();
      final pattern = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );

      expect(pattern.hasMatch(uuid), isTrue, reason: uuid);
      expect(UuidGenerator.v4(), isNot(uuid));
    });
  });
}
