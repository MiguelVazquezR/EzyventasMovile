import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/theme/app_colors.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_action_bar.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_dialog.dart';
import 'package:ezyventas_app/core/widgets/ezy_primary_3d_button.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/cash/data/models/active_cash_session.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/pos/application/cart_controller.dart';
import 'package:ezyventas_app/features/pos/presentation/widgets/cart_line_tile.dart';
import 'package:ezyventas_app/features/pos/presentation/widgets/cart_sheet.dart';
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

/// Monta la hoja del carrito con el turno de caja y los permisos sustituidos.
///
/// Las etiquetas que se comprueban son las que el recorrido del teléfono
/// (`integration_test/qa_device_test.dart`) busca dentro del carrito (`Carrito`,
/// `RESUMEN DE VENTA`, `Finalizar compra`, `Vaciar`), así que un cambio de texto
/// aquí rompería la corrida real.
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
  // que el recorrido del teléfono busca al final (`RESUMEN DE VENTA`,
  // `Finalizar compra`) quedan construidas por el `ListView`.
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

/// «Vaciar» del encabezado de líneas: `true` cuando se puede tocar.
///
/// El botón es una pieza propia del carrito (`GestureDetector` sin relleno) y no
/// un `EzyButton`, así que su estado se lee del gesto que abre la confirmación.
bool _clearCartEnabled(WidgetTester tester) {
  final gesture = find
      .ancestor(of: find.text('Vaciar'), matching: find.byType(GestureDetector))
      .first;

  return tester.widget<GestureDetector>(gesture).onTap != null;
}

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `NumberFormat` de es-MX puede
    // lanzar `LocaleDataException` al pintar el total.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('con líneas: cabecera, cliente, lista y resumen de venta', (
    tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.text('Carrito'), findsOneWidget);
    expect(find.text('1 producto · 1 artículo'), findsOneWidget);
    expect(find.textContaining('135.00'), findsWidgets);

    // §1: la lista se anuncia como `ARTÍCULOS EN ORDEN` y el cliente va arriba
    // de las líneas, con su rótulo y el nombre en su propio renglón.
    expect(find.text('ARTÍCULOS EN ORDEN'), findsOneWidget);
    expect(find.text('CLIENTE'), findsOneWidget);
    expect(find.text('Público general'), findsOneWidget);

    // §4: un solo bloque de totales. La franja duplicada que vivía arriba del
    // todo (`TOTAL A COBRAR`) ya no existe, y el desglose vive en su card.
    expect(find.text('Subtotal'), findsOneWidget);
    expect(find.text('TOTAL A PAGAR'), findsOneWidget);
    expect(find.text('TOTAL A COBRAR'), findsNothing);

    // El cierre de venta es el CTA 3D compartido y no un `EzyButton`: la cara
    // del botón la pinta `EzyPrimary3dButton`.
    final finalizar = find.byType(EzyPrimary3dButton);
    expect(finalizar, findsOneWidget);
    expect(
      find.descendant(of: finalizar, matching: find.text('Finalizar compra')),
      findsOneWidget,
    );
    expect(tester.widget<EzyPrimary3dButton>(finalizar).onPressed, isNotNull);
    expect(_clearCartEnabled(tester), isTrue);
  });

  testWidgets('el pie cierra la venta con un botón y su menú (§5)', (
    tester,
  ) async {
    await _pumpSheet(tester);

    // Las tres formas de cerrar la venta ya no caben en el pie: la principal se
    // queda sola, a 2/3 del ancho y centrada, y las otras dos salen del menú.
    final finalizar = find.byType(EzyPrimary3dButton);
    // La geometría se mide en el recuadro del botón (el `Center` que lo centra
    // ocupa todo el ancho de la barra).
    final finalizarBox = find.descendant(
      of: finalizar,
      matching: find.byType(AnimatedContainer),
    );
    expect(finalizar, findsOneWidget);
    expect(
      find.descendant(of: finalizar, matching: find.text('Finalizar compra')),
      findsOneWidget,
    );
    expect(find.text('Pago al contado'), findsNothing);

    await tester.tap(finalizar);
    await tester.pumpAndSettle();

    final contado = find.text('Pago al contado');
    final apartar = find.text('Apartar');
    final pedido = find.text('Pedido');

    // Las tres salen como **opciones de lista** —título en el tono principal y el
    // color semántico de la acción en su icono—, y no como los tres botones que
    // cabían en el pie.
    expect(contado, findsOneWidget);
    expect(apartar, findsOneWidget);
    expect(pedido, findsOneWidget);

    for (final option in <Finder>[contado, apartar, pedido]) {
      expect(
        tester.widget<Text>(option).style?.color,
        EzyColors.textPrimaryDark,
      );
    }

    // Apiladas **arriba** del botón que las abre, empezando por la que cobra.
    expect(
      tester.getBottomLeft(contado).dy,
      lessThan(tester.getTopLeft(finalizarBox).dy),
    );
    expect(
      tester.getTopLeft(apartar).dy,
      greaterThan(tester.getTopLeft(contado).dy),
    );
    expect(
      tester.getTopLeft(pedido).dy,
      greaterThan(tester.getTopLeft(apartar).dy),
    );

    // A 3/4 del ancho de la barra (16 px de aire por lado), con el tope de
    // 280 px del CTA, y centrado.
    final barWidth = tester.getSize(find.byType(EzyActionBar)).width;
    final button = tester.getRect(finalizarBox);
    expect(button.width, closeTo(((barWidth - 32) * 0.75).clamp(0, 280), 1));
    expect(
      button.center.dx,
      closeTo(tester.getCenter(find.byType(EzyActionBar)).dx, 1),
    );
  });

  testWidgets('vaciar el carrito pide confirmación antes de limpiar (§2)', (
    tester,
  ) async {
    await _pumpSheet(tester);
    expect(find.byType(CartLineTile), findsOneWidget);

    // El «Vaciar» del encabezado ya no limpia en seco: abre el diálogo del
    // sistema (el del diálogo y el de la lista se llaman igual, así que el del
    // encabezado se busca por el texto, que en ese momento es el único).
    await tester.tap(find.text('Vaciar'));
    await tester.pumpAndSettle();

    expect(find.byType(EzyDialog), findsOneWidget);
    expect(find.text('Vaciar carrito'), findsOneWidget);
    expect(find.byType(CartLineTile), findsOneWidget);

    // Cancelar deja el carrito como estaba.
    await tester.tap(find.widgetWithText(EzyButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(EzyDialog), findsNothing);
    expect(find.byType(CartLineTile), findsOneWidget);

    // Confirmar sí lo limpia.
    await tester.tap(find.text('Vaciar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(EzyDialog),
        matching: find.widgetWithText(EzyButton, 'Vaciar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CartLineTile), findsNothing);
    expect(find.text('El carrito está vacío'), findsOneWidget);
  });

  testWidgets('carrito vacío: estado vacío, resumen y acciones apagadas', (
    tester,
  ) async {
    await _pumpSheet(tester, lines: 0);

    expect(find.text('El carrito está vacío'), findsOneWidget);
    expect(find.text('ARTÍCULOS EN ORDEN'), findsOneWidget);
    expect(find.text('TOTAL A PAGAR'), findsOneWidget);

    final finalizar = find.byType(EzyPrimary3dButton);
    expect(tester.widget<EzyPrimary3dButton>(finalizar).onPressed, isNull);
    expect(_clearCartEnabled(tester), isFalse);
    // Apartar y pedido viven en el menú del botón: sin líneas el botón está
    // apagado y el menú no se abre, así que no hay nada más que apagar.
    expect(find.text('Apartar'), findsNothing);
    expect(find.text('Pedido'), findsNothing);
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
          .widget<EzyPrimary3dButton>(find.byType(EzyPrimary3dButton))
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
    expect(find.text('Finalizar compra'), findsNothing);
  });
}
