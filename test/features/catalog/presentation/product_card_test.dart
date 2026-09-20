import 'package:ezyventas_app/core/theme/app_theme.dart';
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
              child: ProductCard(product: product),
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
}
