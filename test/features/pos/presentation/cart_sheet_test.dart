import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/cash/data/models/active_cash_session.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/pos/application/cart_controller.dart';
import 'package:ezyventas_app/features/pos/presentation/widgets/cart_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Permisos del vendedor del mostrador: entra al POS y puede cobrar.
const List<String> _sellerPermissions = <String>['pos.access', 'pos.create_sale'];

Product _product() => Product.fromJson(<String, dynamic>{
  'id': 45,
  'name': 'Filtro de aceite',
  'sku': 'FIL-001',
  'selling_price': '150.00',
  'price': 135.0,
  'original_price': 150.0,
  'stock': 24.0,
  'measure_unit': 'pz',
  'is_bulk': false,
  'show_in_pos': true,
});

/// Turno de caja abierto (`active_session` del contrato de caja).
ActiveCashSession _openShift() => ActiveCashSession.fromJson(<String, dynamic>{
  'id': 12,
  'status': 'abierta',
  'opened_at': '2026-09-25T10:00:00-06:00',
  'opening_cash_balance': 500,
  'totals': <String, dynamic>{'cash': 0, 'card': 0, 'transfer': 0, 'balance': 0},
});

/// Monta la hoja del carrito con el turno de caja y los permisos sustituidos.
///
/// Las etiquetas que se comprueban son las que el recorrido del teléfono
/// (`integration_test/qa_device_test.dart`) busca dentro del carrito, así que un
/// cambio de texto aquí rompería la corrida real.
Future<ProviderContainer> _pumpSheet(
  WidgetTester tester, {
  bool withShift = true,
  bool canSell = true,
  int lines = 1,
}) async {
  final container = ProviderContainer(
    overrides: [
      activeCashSessionProvider.overrideWithValue(
        withShift ? _openShift() : null,
      ),
      permissionsProvider.overrideWithValue(
        canSell
            ? PermissionsService.fromLists(
                permissions: _sellerPermissions,
                moduleKeys: const <String>['module_pos'],
              )
            : const PermissionsService.empty(),
      ),
    ],
  );
  addTearDown(container.dispose);

  // Pantalla alta: la hoja (0.92 del alto) no recorta el carrito y las anclas
  // que el recorrido del teléfono busca al final (`TOTALES`, `Cobrar`) quedan
  // construidas por el `ListView`.
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final cart = container.read(cartControllerProvider.notifier);
  for (var line = 0; line < lines; line++) {
    cart.addProduct(_product());
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: const Scaffold(body: CartSheet()),
      ),
    ),
  );
  await tester.pump();

  return container;
}

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `NumberFormat` de es-MX puede
    // lanzar `LocaleDataException` al pintar el total.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('con líneas: cabecera, total a cobrar, totales y cobro', (
    tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.text('Carrito'), findsOneWidget);
    expect(find.text('1 producto · 1 artículo'), findsOneWidget);
    expect(find.text('TOTAL A COBRAR'), findsOneWidget);
    expect(find.textContaining('135.00'), findsWidgets);
    expect(find.text('TOTALES'), findsOneWidget);
    expect(find.text('Vaciar carrito'), findsOneWidget);

    final cobrar = find.widgetWithText(EzyButton, 'Cobrar');
    expect(cobrar, findsOneWidget);
    expect(tester.widget<EzyButton>(cobrar).onPressed, isNotNull);
  });

  testWidgets('carrito vacío: estado vacío y cobro deshabilitado', (
    tester,
  ) async {
    await _pumpSheet(tester, lines: 0);

    expect(find.text('El carrito está vacío'), findsOneWidget);
    expect(find.text('TOTALES'), findsOneWidget);

    final cobrar = find.widgetWithText(EzyButton, 'Cobrar');
    expect(tester.widget<EzyButton>(cobrar).onPressed, isNull);
    expect(
      tester
          .widget<EzyButton>(find.widgetWithText(EzyButton, 'Vaciar carrito'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('sin turno de caja: avisa y bloquea el cobro', (tester) async {
    await _pumpSheet(tester, withShift: false);

    expect(
      find.text('Necesitas una sesión de caja abierta para registrar ventas.'),
      findsOneWidget,
    );
    expect(find.text('Ir a Caja'), findsWidgets);
    expect(
      tester
          .widget<EzyButton>(find.widgetWithText(EzyButton, 'Cobrar'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('sin permiso de venta: el carrito avisa en lugar de cobrar', (
    tester,
  ) async {
    await _pumpSheet(tester, canSell: false);

    expect(
      find.text('Tu usuario no tiene permiso para esta acción.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(EzyButton, 'Cobrar'), findsNothing);
  });
}
