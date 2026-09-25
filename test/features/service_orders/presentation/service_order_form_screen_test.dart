import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/service_orders/application/service_orders_controller.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_detail.dart';
import 'package:ezyventas_app/features/service_orders/presentation/service_order_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Definiciones del módulo como las devuelve `GET /service-orders/custom-fields`
/// (contrato §9): un campo de texto obligatorio y un interruptor.
List<ServiceOrderCustomFieldDefinition> _definitions() =>
    <ServiceOrderCustomFieldDefinition>[
      ServiceOrderCustomFieldDefinition.fromJson(<String, dynamic>{
        'key': 'pin_desbloqueo',
        'name': 'PIN de desbloqueo',
        'type': 'text',
        'options': null,
        'is_required': true,
      }),
      ServiceOrderCustomFieldDefinition.fromJson(<String, dynamic>{
        'key': 'garantia',
        'name': 'Garantía',
        'type': 'switch',
        'options': null,
        'is_required': false,
      }),
    ];

/// Pantalla de **alta** (sin `serviceOrderId`) con las dos dependencias de red
/// sustituidas: el turno de caja (ninguno, el formulario lo avisa) y las
/// definiciones de campos personalizados del módulo.
Widget _wrap({
  List<ServiceOrderCustomFieldDefinition> definitions =
      const <ServiceOrderCustomFieldDefinition>[],
  ApiException? failure,
}) => ProviderScope(
  overrides: [
    activeCashSessionProvider.overrideWithValue(null),
    serviceOrderCustomFieldsProvider.overrideWith((ref) async {
      if (failure != null) {
        throw failure;
      }

      return definitions;
    }),
  ],
  child: MaterialApp(
    theme: EzyTheme.dark(),
    home: const ServiceOrderFormScreen(),
  ),
);

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `DateFormat`/`NumberFormat` de
    // es-MX lanzan `LocaleDataException` al pintar el formulario.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('dibuja los campos personalizados del módulo en el alta (D5)', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(definitions: _definitions()));
    await tester.pumpAndSettle();

    // La sección vive al final del formulario (es una lista perezosa).
    await tester.dragUntilVisible(
      find.text('CAMPOS PERSONALIZADOS'),
      find.byType(ListView),
      const Offset(0, -300),
    );

    expect(find.text('CAMPOS PERSONALIZADOS'), findsOneWidget);
    // `FieldLabel` pinta el texto en mayúsculas y marca los obligatorios.
    expect(find.text('PIN DE DESBLOQUEO *'), findsOneWidget);
    // El interruptor usa el nombre tal cual.
    expect(find.text('Garantía'), findsOneWidget);
  });

  testWidgets('sin definiciones el alta no dibuja la sección', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // Se baja todo el formulario: la sección no debe aparecer en ningún punto.
    for (var i = 0; i < 6; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('CAMPOS PERSONALIZADOS'), findsNothing);
    }
  });

  testWidgets('si el endpoint falla, el alta lo avisa y deja seguir (D5)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        failure: ApiException.fromResponse(403, <String, dynamic>{
          'message': 'Tu usuario no tiene permiso para esta acción.',
        }),
      ),
    );
    await tester.pumpAndSettle();

    const notice =
        'No se pudieron cargar los campos personalizados del módulo. '
        'Puedes crear la orden y capturarlos al editarla.';

    await tester.dragUntilVisible(
      find.text(notice),
      find.byType(ListView),
      const Offset(0, -300),
    );

    expect(find.text(notice), findsOneWidget);
    expect(find.text('CAMPOS PERSONALIZADOS'), findsNothing);
  });
}
