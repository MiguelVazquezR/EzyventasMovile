import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_amount.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/cash/data/models/active_cash_session.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/pos/application/cart_controller.dart';
import 'package:ezyventas_app/features/pos/presentation/widgets/cart_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Permisos del vendedor del mostrador: entra al POS y puede cobrar.
const List<String> _sellerPermissions = <String>[
  'pos.access',
  'pos.create_sale',
];

Product _product({double price = 135}) => Product.fromJson(<String, dynamic>{
  'id': 45,
  'name': 'Filtro de aceite',
  'sku': 'FIL-001',
  'selling_price': '150.00',
  'price': price,
  'original_price': price,
  'stock': 2400.0,
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
  'totals': <String, dynamic>{
    'cash': 0,
    'card': 0,
    'transfer': 0,
    'balance': 0,
  },
});

/// Monta la pill del carrito anclada al pie, con el turno de caja sustituido
/// (sin turno el servidor respondería `session_required`) y los permisos
/// indicados.
///
/// Las etiquetas que se comprueban son las que el recorrido del teléfono
/// (`integration_test/qa_device_test.dart`) busca para abrir el carrito, así que
/// un cambio de texto aquí rompería la corrida real.
Future<ProviderContainer> _pumpBar(
  WidgetTester tester, {
  bool canSell = true,
  bool withShift = false,
  int lines = 0,
  double unitPrice = 135,
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

  final cart = container.read(cartControllerProvider.notifier);
  for (var line = 0; line < lines; line++) {
    cart.addProduct(_product(price: unitPrice));
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: const Scaffold(
          body: Column(children: <Widget>[Spacer(), CartBar()]),
        ),
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

  testWidgets('carrito vacío: avisa del turno y ofrece abrirlo', (
    tester,
  ) async {
    await _pumpBar(tester);

    // La pill es un resumen, no una barra de acciones: el importe y el acceso
    // al carrito viven en la misma pieza táctil (§8.1).
    expect(find.byType(EzyAmount), findsOneWidget);
    expect(find.text('Sin turno abierto'), findsOneWidget);
    expect(find.text('Carrito vacío'), findsOneWidget);
    expect(find.textContaining('0.00'), findsOneWidget);
  });

  testWidgets('con líneas: resume el carrito, muestra su total y la flecha', (
    tester,
  ) async {
    await _pumpBar(tester, withShift: true, lines: 1);

    // El acceso al carrito es el chevron, no la pastilla «Ver carrito»: el
    // texto robaba al total el ancho que necesita para caber en un renglón.
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.text('Ver carrito'), findsNothing);
    expect(find.text('1 producto · 1 artículo'), findsOneWidget);
    // El total lo formatea `EzyAmount` con el dinero del carrito.
    expect(find.textContaining('135.00'), findsOneWidget);
  });

  testWidgets('el total va en un solo renglón aunque tenga siete cifras', (
    tester,
  ) async {
    // En un teléfono estrecho el monto es donde se partía en dos renglones.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpBar(tester, withShift: true, lines: 3, unitPrice: 1240000);

    final total = find.textContaining('3,720,000.00');
    expect(total, findsOneWidget);
    // Dos renglones medirían el doble del alto de la tipografía del monto
    // (19 px × 1.1 ≈ 21 px).
    expect(tester.getSize(total).height, lessThan(24));
  });

  testWidgets('sin permiso de venta la pill no se dibuja', (tester) async {
    await _pumpBar(tester, canSell: false);

    expect(find.byType(EzyAmount), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('Carrito vacío'), findsNothing);
  });
}
