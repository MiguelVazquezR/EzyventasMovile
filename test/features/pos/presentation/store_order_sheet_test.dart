import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_primary_3d_button.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/cash/data/models/active_cash_session.dart';
import 'package:ezyventas_app/features/pos/application/cart_controller.dart';
import 'package:ezyventas_app/features/pos/data/models/checkout_result.dart';
import 'package:ezyventas_app/features/pos/data/pos_repository.dart';
import 'package:ezyventas_app/features/pos/presentation/widgets/store_order_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Repositorio falso de escrituras del POS: no toca la red y guarda el payload
/// que la hoja armó, para comprobar que el rediseño **no** cambió lo que viaja a
/// `POST /pos/store-order`.
class _FakePosRepository extends PosRepository {
  _FakePosRepository({this.error}) : super(api: ApiClient());

  /// Si viene, el envío falla con este error (el `422` del servidor).
  final ApiException? error;

  int storeOrderCalls = 0;
  Map<String, dynamic>? lastPayload;

  @override
  Future<CheckoutResult> storeOrder(Map<String, dynamic> payload) async {
    storeOrderCalls++;
    lastPayload = payload;

    final failure = error;
    if (failure != null) {
      throw failure;
    }

    return CheckoutResult.fromJson(<String, dynamic>{
      'transaction': <String, dynamic>{
        'id': 99,
        'folio': 'P-014',
        'status': 'pedido',
        'channel': 'pos',
        'total': 0.0,
      },
    });
  }
}

/// Turno de caja abierto (`active_session` del contrato de caja).
ActiveCashSession _openShift() => ActiveCashSession.fromJson(<String, dynamic>{
  'id': 12,
  'status': 'abierta',
  'opened_at': '2026-09-25T10:00:00-06:00',
  'opening_cash_balance': 500,
  'totals': <String, dynamic>{
    'cash': 0,
    'card': 0,
    'transfer': 0,
    'balance': 0,
  },
});

/// `422` de `POST /pos/store-order` con los errores de campo que el contrato
/// documenta (`contact_info.name`, `delivery_date`, `shipping_address`).
ApiException _validationError() => const ApiException(
  statusCode: 422,
  message: 'Revisa los datos del pedido.',
  errors: <String, List<String>>{
    'contact_info.name': <String>['El nombre del contacto es obligatorio.'],
    'delivery_date': <String>['La fecha de entrega no puede ser en el pasado.'],
    'shipping_address': <String>['La dirección es obligatoria.'],
  },
);

void main() {
  late _FakePosRepository repository;

  setUpAll(() async {
    // Igual que `main()` de la app: sin esto el `DateFormat` de es-MX de la
    // fecha de entrega lanza `LocaleDataException`.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  /// App mínima con un botón que abre la hoja bajo prueba.
  Widget app() => ProviderScope(
    overrides: [
      posRepositoryProvider.overrideWithValue(repository),
      activeCashSessionProvider.overrideWithValue(_openShift()),
    ],
    child: MaterialApp(
      theme: EzyTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              // La hoja cierra con `true` al confirmar el envío; aquí solo
              // interesa abrirla, así que el resultado se descarta.
              onPressed: () async {
                await showStoreOrderSheet(context);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );

  setUp(() {
    repository = _FakePosRepository();
  });

  /// Pantalla alta: la hoja (0.96 del alto) construye todas sus tarjetas y el
  /// `ListView` no deja fuera la de totales. La altura de 2400 y el ancho de 800
  /// también dan aire a los diálogos del sistema de fecha y hora.
  Future<void> openSheet(
    WidgetTester tester, {
    Size size = const Size(800, 2400),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.tap(find.text('Abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Fecha y hora de entrega: los dos diálogos del sistema confirman con `OK`
  /// (la fecha arranca en hoy, así que el valor por defecto es válido).
  Future<void> pickDeliveryDateTime(WidgetTester tester) async {
    await tester.tap(find.text('Cambiar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('pedido por defecto: cabecera, tarjetas y CTA de 56 apagado', (
    tester,
  ) async {
    await openSheet(tester);

    // Cabecera fija (§2): el título convive con la opción del selector, que se
    // llama igual.
    expect(find.text('Pedido'), findsNWidgets(2));
    expect(find.text('POR ENTREGAR'), findsOneWidget);
    expect(
      find.text('El stock queda reservado; se cobra al entregar.'),
      findsOneWidget,
    );

    // Tarjetas (§4–§6) con sus micro-etiquetas y chips.
    expect(find.text('DATOS DE CONTACTO'), findsOneWidget);
    expect(find.text('RESERVA DE STOCK'), findsOneWidget);
    expect(find.text('ENTREGA Y LOGÍSTICA'), findsOneWidget);
    expect(find.text('PROGRAMADA'), findsOneWidget);
    expect(find.text('RESUMEN DE LA ORDEN'), findsOneWidget);
    expect(find.text('TOTAL DEL PEDIDO'), findsOneWidget);
    expect(find.text('Costo de envío'), findsOneWidget);
    expect(find.text('MXN'), findsOneWidget);

    // Contadores de la micro-etiqueta (§4) y marcador de la fecha.
    expect(find.text('0/255'), findsNWidgets(2));
    expect(find.text('MÁX. 20'), findsOneWidget);
    expect(find.text('Seleccionar fecha…'), findsOneWidget);

    // Pie fijo (§7): CTA 3D de 56 px apagado mientras falten datos.
    final cta = tester.widget<EzyPrimary3dButton>(
      find.byType(EzyPrimary3dButton),
    );
    expect(cta.label, 'Registrar pedido');
    expect(cta.height, 56);
    expect(cta.onPressed, isNull);
    expect(find.text('Se requiere una sesión de caja activa'), findsOneWidget);
  });

  testWidgets('el contador del nombre sigue al texto capturado', (tester) async {
    await openSheet(tester);

    expect(find.text('0/255'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.pump();

    expect(find.text('3/255'), findsOneWidget);
  });

  testWidgets('comanda: cabecera, CTA y leyenda cambian de tipo', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Comanda'));
    await tester.pump();

    expect(find.text('Comanda'), findsNWidgets(2));
    expect(find.text('Pedido'), findsOneWidget);
    expect(
      tester.widget<EzyPrimary3dButton>(find.byType(EzyPrimary3dButton)).label,
      'Registrar comanda',
    );
    expect(
      find.text('Uso para cocina, restaurante y consumo en mesa.'),
      findsOneWidget,
    );
    expect(
      find.text('Uso para retail y entregas programadas a domicilio.'),
      findsNothing,
    );
  });

  testWidgets('los errores del servidor se pintan en el banner y en su campo', (
    tester,
  ) async {
    repository = _FakePosRepository(error: _validationError());
    await openSheet(tester);

    await tester.enterText(find.byType(TextField).first, 'Ana Ramírez');
    await tester.pump();
    await pickDeliveryDateTime(tester);

    // Con nombre y fecha el CTA ya se puede enviar.
    final cta = find.byType(EzyPrimary3dButton);
    expect(tester.widget<EzyPrimary3dButton>(cta).onPressed, isNotNull);

    await tester.tap(cta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.storeOrderCalls, 1);
    final contact =
        repository.lastPayload!['contact_info']! as Map<String, dynamic>;
    expect(contact['name'], 'Ana Ramírez');
    expect(contact['type'], 'pedido');

    // El global arriba y cada error en el borde de su campo (§3–§5).
    expect(find.text('Error al registrar'), findsOneWidget);
    expect(find.text('Revisa los datos del pedido.'), findsOneWidget);
    expect(find.text('El nombre del contacto es obligatorio.'), findsOneWidget);
    expect(
      find.text('La fecha de entrega no puede ser en el pasado.'),
      findsOneWidget,
    );
    expect(find.text('La dirección es obligatoria.'), findsOneWidget);
    // Sin éxito la hoja sigue abierta con el formulario intacto.
    expect(find.text('Registrar pedido'), findsOneWidget);

    // El cierre del banner descarta el `422` completo: el mensaje global y los
    // errores por campo que vinieron con él (`clearError` del carrito).
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pump();

    expect(find.text('Error al registrar'), findsNothing);
    expect(find.text('El nombre del contacto es obligatorio.'), findsNothing);
  });

  testWidgets('en un teléfono la hoja se recorre sin desbordar', (tester) async {
    await openSheet(tester, size: const Size(400, 800));

    // El formulario es más largo que la hoja: se recorre entero y ninguna
    // tarjeta desborda (un `RenderFlex overflowed` haría fallar la prueba).
    await tester.drag(find.byType(ListView), const Offset(0, -1600));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // El pie no viaja con el scroll: el CTA de 56 sigue a la vista.
    expect(find.text('Registrar pedido'), findsOneWidget);
    expect(find.text('TOTAL DEL PEDIDO'), findsOneWidget);
  });

  testWidgets('sin nombre no hay envío aunque la fecha esté puesta', (
    tester,
  ) async {
    await openSheet(tester);
    await pickDeliveryDateTime(tester);

    final cta = find.byType(EzyPrimary3dButton);
    expect(tester.widget<EzyPrimary3dButton>(cta).onPressed, isNull);

    // Un nombre de una letra sigue sin habilitar el envío y se marca el error.
    await tester.enterText(find.byType(TextField).first, 'A');
    await tester.pump();
    expect(tester.widget<EzyPrimary3dButton>(cta).onPressed, isNull);
    expect(
      find.text('El nombre debe tener al menos 2 caracteres.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.pump();
    expect(tester.widget<EzyPrimary3dButton>(cta).onPressed, isNotNull);
    expect(repository.storeOrderCalls, 0);
  });

}
