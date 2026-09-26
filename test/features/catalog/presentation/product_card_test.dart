import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/server_image.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/catalog/presentation/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// La reja del catálogo usa dos columnas con `childAspectRatio: 0.68`; en el
/// teléfono de pruebas (1080 x 2400, 440 dpi) cada tarjeta mide 174.4 x 256.4 px.
/// Ese tamaño destapó un `RenderFlex overflowed by 1.1 pixels on the bottom`
/// (`product_card.dart`), así que la prueba fija esas medidas.
const Size _phoneCardSize = Size(174.4, 256.4);

Product _product({String? image, double stock = 5}) => Product.fromJson(
  <String, dynamic>{
    'id': 1,
    'name': 'Funda protectora para iPhone 20 Pro Max con cámara',
    'image': image,
    'selling_price': '150.00',
    'price': 150,
    'original_price': 150,
    'stock': stock,
    'show_in_pos': true,
  },
);

Future<void> _pumpCard(
  WidgetTester tester,
  Product product, {
  double textScale = 1,
  double quantity = 0,
  VoidCallback? onAdd,
  VoidCallback? onIncrement,
  VoidCallback? onDecrement,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: EzyTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: _phoneCardSize.width,
              height: _phoneCardSize.height,
              child: ProductCard(
                product: product,
                quantity: quantity,
                onAdd: onAdd,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('la tarjeta del catálogo no desborda en el teléfono', (
    tester,
  ) async {
    await _pumpCard(tester, _product());

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Funda protectora'), findsOneWidget);
  });

  testWidgets('no desborda con la letra agrandada al máximo (1.3x)', (
    tester,
  ) async {
    await _pumpCard(tester, _product(), textScale: 1.3);

    expect(tester.takeException(), isNull);
  });

  testWidgets('sin imagen muestra el marcador y no desborda', (tester) async {
    await _pumpCard(tester, _product(image: null, stock: 0));

    expect(tester.takeException(), isNull);
    expect(find.text('Sin stock'), findsOneWidget);
  });

  testWidgets('la foto se ve completa: `BoxFit.contain`, sin recortes', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      _product(image: 'https://ezyventas2.test/storage/funda.jpg'),
    );

    expect(tester.takeException(), isNull);

    // `cover` recortaba la foto para llenar el marco; ahora se respeta la
    // proporción original y el hueco lo cubre el fondo interior del panel.
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
  });

  testWidgets('solo variantes: la tarjeta usa la foto de la primera variante', (
    tester,
  ) async {
    // Caso real: el producto no tiene fotos propias (el servidor manda
    // `placehold.co`) y sus fotos viven en las variantes.
    await _pumpCard(
      tester,
      Product.fromJson(<String, dynamic>{
        'id': 9,
        'name': 'Playera',
        'image': 'https://placehold.co/400x400/EBF8FF/3182CE?text=Playera',
        'general_images': <String>[],
        'selling_price': '200.00',
        'price': 200,
        'original_price': 200,
        'stock': 0,
        'show_in_pos': true,
        'variant_combinations': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 30,
            'attributes': <String, dynamic>{'Talla': 'M'},
            'price': 200.0,
            'stock': 2.0,
            'image_url': 'https://ezyventas2.test/storage/playera-m.jpg',
          },
        ],
      }),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.widget<ServerImage>(find.byType(ServerImage)).url,
      'https://ezyventas2.test/storage/playera-m.jpg',
    );
  });

  testWidgets('sin unidades ofrece agregar de un toque', (tester) async {
    var taps = 0;

    await _pumpCard(
      tester,
      _product(),
      onAdd: () => taps++,
      onIncrement: () => taps++,
    );

    await tester.tap(find.byTooltip('Agregar al carrito'));
    await tester.pump();

    expect(taps, 1);
    // Sin unidades el contador no existe: hay una sola acción de suma.
    expect(find.byTooltip('Quitar una unidad'), findsNothing);
  });

  testWidgets('con unidades en el carrito manda el contador [-] n [+]', (
    tester,
  ) async {
    var increments = 0;
    var decrements = 0;

    await _pumpCard(
      tester,
      _product(),
      quantity: 2,
      onAdd: () => increments++,
      onIncrement: () => increments++,
      onDecrement: () => decrements++,
    );

    expect(find.text('2'), findsOneWidget);
    expect(find.byTooltip('Agregar al carrito'), findsNothing);

    await tester.tap(find.byTooltip('Agregar una unidad'));
    await tester.tap(find.byTooltip('Quitar una unidad'));
    await tester.pump();

    expect(increments, 1);
    expect(decrements, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin permiso de venta la tarjeta no ofrece acciones', (
    tester,
  ) async {
    await _pumpCard(tester, _product(), quantity: 2);

    expect(find.byTooltip('Agregar al carrito'), findsNothing);
    expect(find.byTooltip('Agregar una unidad'), findsNothing);
    expect(find.byTooltip('Quitar una unidad'), findsNothing);
  });
}
