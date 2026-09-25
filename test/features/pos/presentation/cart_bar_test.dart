import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_action_bar.dart';
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
  'totals': <String, dynamic>{
    'cash': 0,
    'card': 0,
    'transfer': 0,
    'balance': 0,
  },
});

/// Monta la barra del carrito anclada al pie, con el turno de caja sustituido
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
    cart.addProduct(_product());
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: const Scaffold(
          body: Column(
            children: <Widget>[Spacer(), CartBar()],
          ),
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

    expect(find.byType(EzyActionBar), findsOneWidget);
    expect(find.text('Sin turno abierto'), findsOneWidget);
    expect(find.text('Carrito vacío'), findsOneWidget);
    expect(find.textContaining('0.00'), findsOneWidget);
  });

  testWidgets('con líneas: resume el carrito y muestra su total', (
    tester,
  ) async {
    await _pumpBar(tester, withShift: true, lines: 1);

    expect(find.text('Ver carrito'), findsOneWidget);
    expect(find.text('1 producto · 1 artículo'), findsOneWidget);
    // El total lo formatea `EzyAmount` con el dinero del carrito.
    expect(find.textContaining('135.00'), findsOneWidget);
  });

  testWidgets('sin permiso de venta la barra no se dibuja', (tester) async {
    await _pumpBar(tester, canSell: false);

    expect(find.byType(EzyActionBar), findsNothing);
    expect(find.text('Ver carrito'), findsNothing);
    expect(find.text('Carrito vacío'), findsNothing);
  });
}
