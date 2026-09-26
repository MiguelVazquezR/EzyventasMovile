import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_amount.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_chip.dart';
import 'package:ezyventas_app/core/widgets/ezy_quantity_stepper.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/pos/application/cart_controller.dart';
import 'package:ezyventas_app/features/pos/presentation/widgets/cart_line_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Permisos del vendedor que **sí** captura descuentos (`pos.edit_prices`).
const List<String> _sellerPermissions = <String>[
  'pos.access',
  'pos.create_sale',
  'pos.edit_prices',
];

/// Permisos del vendedor que solo cobra: sin `pos.edit_prices` el descuento de la
/// línea es de solo lectura.
const List<String> _cashierPermissions = <String>[
  'pos.access',
  'pos.create_sale',
];

/// Producto en promoción: `price` 135 sobre un precio de lista de 150 (§7.2), así
/// que la línea llega con `discountPerUnit` 15 y motivo `Promoción de producto`.
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

/// Monta la tarjeta como la monta el carrito: dentro de una lista que **escucha**
/// al carrito, para que mover la cantidad repinte la tarjeta y no solo el modelo.
class _TileHarness extends ConsumerWidget {
  const _TileHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final line in cart.lines) CartLineTile(line: line),
          if (cart.isEmpty) const Text('sin líneas'),
        ],
      ),
    );
  }
}

/// Abre el editor de la línea con el lápiz de la tarjeta.
Future<void> _openEditor(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Monta la tarjeta de la única línea del carrito y devuelve el contenedor para
/// leer el carrito. [canEditPrices] deja el campo del descuento en solo lectura.
Future<ProviderContainer> _pumpTile(
  WidgetTester tester, {
  bool canEditPrices = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      permissionsProvider.overrideWithValue(
        PermissionsService.fromLists(
          permissions: canEditPrices
              ? _sellerPermissions
              : _cashierPermissions,
          moduleKeys: const <String>['module_pos'],
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  container.read(cartControllerProvider.notifier).addProduct(_product());

  // Pantalla alta: el editor (0.92 del alto) deja construidos el desglose y el
  // pie con «Cancelar» / «Guardar cambios» sin desplazar la hoja.
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: const Scaffold(body: _TileHarness()),
      ),
    ),
  );
  await tester.pump();

  return container;
}

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `NumberFormat` de es-MX puede
    // lanzar `LocaleDataException` al pintar los montos.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la tarjeta lee precio, ahorro por pastilla y total de la línea', (
    tester,
  ) async {
    await _pumpTile(tester);

    // Nombre y precio unitario final.
    expect(find.text('Filtro de aceite'), findsOneWidget);
    expect(find.text(r'$135.00 c/u'), findsOneWidget);

    // El precio de lista se tacha al lado y el ahorro va en la pastilla del
    // sistema: el descuento se lee sin restar renglones de texto.
    final listPrice = tester.widget<Text>(find.text(r'$150.00'));
    expect(listPrice.style?.decoration, TextDecoration.lineThrough);
    expect(find.widgetWithText(EzyChip, r'-$15.00 c/u'), findsOneWidget);

    // El motivo lo pone el modelo, no la tarjeta.
    expect(find.text('Promoción de producto'), findsOneWidget);

    // Contador del sistema y total de la línea, en el mismo renglón.
    expect(find.byType(EzyQuantityStepper), findsOneWidget);
    expect(tester.widget<EzyAmount>(find.byType(EzyAmount)).value, 135);

    // Las acciones son botones de icono con su ayuda, no botones de texto.
    expect(find.byTooltip('Editar cantidad y descuento'), findsOneWidget);
    expect(find.byTooltip('Quitar del carrito'), findsOneWidget);
  });

  testWidgets('el contador mueve la cantidad y recalcula el total', (
    tester,
  ) async {
    final container = await _pumpTile(tester);

    await tester.tap(find.byTooltip('Agregar una unidad'));
    await tester.pump();

    expect(container.read(cartControllerProvider).lines.single.quantity, 2);
    expect(find.text(r'$270.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar una unidad'));
    await tester.pump();

    expect(container.read(cartControllerProvider).lines.single.quantity, 1);
    expect(find.text(r'$135.00'), findsOneWidget);
  });

  testWidgets('la papelera quita la línea del carrito', (tester) async {
    final container = await _pumpTile(tester);

    await tester.tap(find.byTooltip('Quitar del carrito'));
    await tester.pump();

    expect(container.read(cartControllerProvider).isEmpty, isTrue);
    expect(find.text('sin líneas'), findsOneWidget);
    expect(find.byType(EzyAmount), findsNothing);
  });

  testWidgets('el lápiz abre el editor con el desglose de la línea', (
    tester,
  ) async {
    await _pumpTile(tester);
    await _openEditor(tester);

    // §3: la hoja se identifica con la línea que edita.
    expect(find.text('Editar línea: Filtro de aceite'), findsOneWidget);
    // Las micro-etiquetas del design system van en MAYÚSCULAS (§3).
    expect(find.text('CANTIDAD'), findsOneWidget);
    // Los campos abren con lo que ya trae la línea, no en blanco.
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller?.text,
      '1',
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '15.00',
    );

    // Desglose de solo lectura: precio de lista, descuento y total de la línea.
    expect(find.text('Precio de lista'), findsOneWidget);
    expect(find.text(r'-$15.00'), findsOneWidget);
    expect(find.text('Descuento aplicado'), findsOneWidget);
    expect(find.text('Total de la línea'), findsOneWidget);

    // Una promoción no es un precio capturado a mano: no hay nada que devolver.
    expect(find.text('Volver al precio del catálogo'), findsNothing);

    expect(find.widgetWithText(EzyButton, 'Cancelar'), findsOneWidget);
    expect(find.widgetWithText(EzyButton, 'Guardar cambios'), findsOneWidget);
  });


  testWidgets('el editor guarda cantidad y descuento en el mismo guardado', (
    tester,
  ) async {
    final container = await _pumpTile(tester);
    await _openEditor(tester);

    // Se capturan los dos campos antes de guardar: la cantidad no puede perderse
    // al aplicar el descuento (cada escritura parte de la línea vigente).
    await tester.enterText(find.byType(TextField).first, '3');
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, '20');
    await tester.pump();

    // El desglose se recalcula mientras se captura: 150 × 3 y −20 × 3.
    expect(find.text(r'$450.00'), findsOneWidget);
    expect(find.text(r'-$60.00'), findsOneWidget);
    expect(find.text(r'$390.00'), findsOneWidget);

    await tester.tap(find.widgetWithText(EzyButton, 'Guardar cambios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final line = container.read(cartControllerProvider).lines.single;
    expect(line.quantity, 3);
    expect(line.discountPerUnit, 20);
    expect(line.unitPrice, 130);
    expect(line.lineTotal, 390);
    expect(line.discountReason, 'Descuento manual');

    // La hoja se cerró y la tarjeta ya muestra el resultado.
    expect(find.text('Guardar cambios'), findsNothing);
    expect(find.widgetWithText(EzyChip, r'-$20.00 c/u'), findsOneWidget);
    expect(find.text(r'$390.00'), findsOneWidget);
  });

  testWidgets('cancelar deja la línea como estaba', (tester) async {
    final container = await _pumpTile(tester);
    await _openEditor(tester);

    await tester.enterText(find.byType(TextField).first, '4');
    await tester.pump();
    await tester.tap(find.widgetWithText(EzyButton, 'Cancelar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final line = container.read(cartControllerProvider).lines.single;
    expect(line.quantity, 1);
    expect(line.unitPrice, 135);
    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('sin permiso de precios el descuento no se puede capturar', (
    tester,
  ) async {
    final container = await _pumpTile(tester, canEditPrices: false);
    await _openEditor(tester);

    // El campo queda deshabilitado y lo explica en su ayuda.
    expect(
      tester.widget<TextField>(find.byType(TextField).last).enabled,
      isFalse,
    );
    expect(
      find.text('Necesitas el permiso para editar precios.'),
      findsOneWidget,
    );

    // Cambiar solo la cantidad no toca el precio ni el motivo de la promoción.
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.pump();
    await tester.tap(find.widgetWithText(EzyButton, 'Guardar cambios'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final line = container.read(cartControllerProvider).lines.single;
    expect(line.quantity, 2);
    expect(line.unitPrice, 135);
    expect(line.discountPerUnit, 15);
    expect(line.discountReason, 'Promoción de producto');
  });

  testWidgets('un precio capturado a mano se devuelve al del catálogo', (
    tester,
  ) async {
    final container = await _pumpTile(tester);
    final cart = container.read(cartControllerProvider.notifier);

    // El cajero baja la línea a 120: deja de ser promoción y pasa a descuento
    // manual, con su pastilla de ahorro de 30 por unidad.
    cart.setUnitPrice(
      container.read(cartControllerProvider).lines.single,
      120,
    );
    await tester.pump();

    expect(find.text(r'$120.00 c/u'), findsOneWidget);
    expect(find.widgetWithText(EzyChip, r'-$30.00 c/u'), findsOneWidget);
    expect(find.text('Descuento manual'), findsOneWidget);

    await _openEditor(tester);
    expect(find.text('Volver al precio del catálogo'), findsOneWidget);
    await tester.tap(find.text('Volver al precio del catálogo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final line = container.read(cartControllerProvider).lines.single;
    expect(line.isManualPrice, isFalse);
    expect(line.unitPrice, 135);
    expect(line.discountReason, 'Promoción de producto');
    expect(find.text('Volver al precio del catálogo'), findsNothing);
  });
}

