import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_quantity_stepper.dart';
import 'package:ezyventas_app/core/widgets/ezy_selectable_tile.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/catalog/application/catalog_providers.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/catalog/presentation/widgets/product_detail_sheet.dart';
import 'package:ezyventas_app/features/pos/application/cart_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Permisos del vendedor del mostrador: entra al POS y puede vender.
const List<String> _sellerPermissions = <String>[
  'pos.access',
  'pos.create_sale',
];

/// Producto de la tarjeta del catálogo; `withVariants` añade dos combinaciones
/// (una con stock y otra agotada) para probar la sección de venta.
///
/// [generalImages] son las fotos del producto tal como llegan en
/// `general_images`: la portada (`image`) repite la primera, igual que las manda
/// el servidor. [variantImage] es la foto de la combinación «Talla M»
/// (`variant_combinations[].image_url`).
Product _product({
  double stock = 8,
  bool withVariants = false,
  List<String> generalImages = const <String>[],
  String? variantImage,
}) => Product.fromJson(<String, dynamic>{
  'id': 45,
  'name': 'Filtro de aceite',
  'sku': 'FIL-001',
  'category': 'Filtros',
  'description': '<p>Filtro de alto rendimiento</p>',
  'image': generalImages.isEmpty ? null : generalImages.first,
  'general_images': generalImages,
  'price': 135.0,
  'original_price': 150.0,
  'stock': stock,
  'measure_unit': 'pz',
  'is_bulk': false,
  'show_in_pos': true,
  if (withVariants)
    'variant_combinations': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'attributes': <String, dynamic>{'Talla': 'M'},
        'price': 135.0,
        'stock': 4.0,
        'sku_suffix': 'M',
        'image_url': variantImage,
      },
      <String, dynamic>{
        'id': 2,
        'attributes': <String, dynamic>{'Talla': 'G'},
        'price': 145.0,
        'stock': 0.0,
        'sku_suffix': 'G',
        'image_url': null,
      },
    ],
});

/// Monta el detalle del producto como lo abre el catálogo y devuelve el
/// contenedor para leer el carrito.
///
/// Las etiquetas que se comprueban son las que el recorrido del teléfono
/// (`integration_test/qa_device_test.dart`) busca dentro del sheet, así que un
/// cambio de texto aquí rompería la corrida real.
Future<ProviderContainer> _pumpSheet(
  WidgetTester tester, {
  Product? product,
  bool canSell = true,
}) async {
  final item = product ?? _product();
  final container = ProviderContainer(
    overrides: [
      productDetailProvider(item.id).overrideWith((ref) async => item),
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

  // Pantalla alta: la hoja (0.92 del alto) construye todas sus secciones y la
  // sección de venta —la que el recorrido del teléfono sondea bajando— queda
  // disponible sin desplazar.
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showProductDetail(context, item),
                child: const Text('Abrir detalle'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.text('Abrir detalle'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  return container;
}

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `NumberFormat` de es-MX puede
    // lanzar `LocaleDataException` al pintar los montos.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('cabecera, precio, cantidad y CTA de la sección de venta', (
    tester,
  ) async {
    await _pumpSheet(tester);

    // Cabecera de hoja del design system: nombre + SKU · categoría.
    expect(find.text('Filtro de aceite'), findsOneWidget);
    expect(find.text('SKU FIL-001 · Filtros'), findsOneWidget);

    // Precio vigente en el bloque de precio y como total de la línea (1 pza).
    expect(find.textContaining('135.00'), findsNWidgets(2));
    expect(find.text('Antes \$150.00'), findsOneWidget);

    // Sección de venta: cantidad con el control del design system y el ancla
    // del recorrido del teléfono. El título de la card va en micro-mayúsculas.
    expect(find.text('AGREGAR A LA VENTA'), findsOneWidget);
    expect(find.text('Cantidad'), findsOneWidget);
    expect(find.byType(EzyQuantityStepper), findsOneWidget);
    expect(find.text('1 pz'), findsOneWidget);
    expect(find.text('TOTAL DE LA LÍNEA'), findsOneWidget);
    expect(find.text('Agregar al carrito'), findsOneWidget);
  });

  testWidgets('el ± suma de unidad en unidad y actualiza el total', (
    tester,
  ) async {
    await _pumpSheet(tester);

    await tester.tap(find.byTooltip('Agregar una unidad'));
    await tester.pump();
    await tester.tap(find.byTooltip('Agregar una unidad'));
    await tester.pump();

    expect(find.text('3 pz'), findsOneWidget);
    expect(find.textContaining('405.00'), findsOneWidget);

    await tester.tap(find.byTooltip('Quitar una unidad'));
    await tester.pump();

    expect(find.text('2 pz'), findsOneWidget);
    expect(find.textContaining('270.00'), findsOneWidget);
  });

  testWidgets('agregar al carrito suma la línea y cierra la hoja', (
    tester,
  ) async {
    final container = await _pumpSheet(tester);

    await tester.tap(find.text('Agregar al carrito'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final cart = container.read(cartControllerProvider);
    expect(cart.lines, hasLength(1));
    expect(cart.lines.first.quantity, 1);
    expect(cart.lines.first.productName, 'Filtro de aceite');

    // El recorrido del teléfono espera que el sheet se cierre solo.
    expect(find.text('Agregar al carrito'), findsNothing);
    expect(find.textContaining('agregado al carrito'), findsOneWidget);
  });

  testWidgets('variantes: la selección cambia el precio y el stock', (
    tester,
  ) async {
    await _pumpSheet(tester, product: _product(withVariants: true));

    expect(find.text('VARIANTES'), findsOneWidget);
    expect(find.byType(EzySelectableTile), findsNWidgets(2));
    expect(find.text('Talla M'), findsOneWidget);
    expect(find.text('4 disponibles'), findsOneWidget);
    expect(find.text('Sin stock'), findsOneWidget);

    await tester.tap(find.text('Talla G'));
    await tester.pump();

    // La variante agotada deja el precio del servidor y quita el CTA: el monto
    // aparece en el tile y en el bloque de precio.
    expect(find.textContaining('145.00'), findsNWidgets(2));
    expect(
      find.text('El producto ya no tiene stock suficiente.'),
      findsOneWidget,
    );
    expect(find.text('Agregar al carrito'), findsNothing);
  });

  testWidgets('producto sin stock: avisa en lugar de ofrecer el CTA', (
    tester,
  ) async {
    await _pumpSheet(tester, product: _product(stock: 0));

    expect(
      find.text('El producto ya no tiene stock suficiente.'),
      findsOneWidget,
    );
    expect(find.text('AGREGAR A LA VENTA'), findsNothing);
    expect(find.text('Agregar al carrito'), findsNothing);
  });

  testWidgets('sin pos.create_sale: avisa en lugar de ofrecer el CTA', (
    tester,
  ) async {
    await _pumpSheet(tester, canSell: false);

    expect(
      find.text('Tu usuario no tiene permiso para esta acción.'),
      findsOneWidget,
    );
    expect(find.text('Agregar al carrito'), findsNothing);
  });

  test('la variante se pinta primero y las imágenes repetidas se descartan', () {
    expect(
      ProductGallery.resolveImages(
        <String>['https://x/a.jpg', 'https://x/b.jpg'],
        overrideImage: 'https://x/m.jpg',
      ),
      <String>['https://x/m.jpg', 'https://x/a.jpg', 'https://x/b.jpg'],
    );

    // Si la variante elegida no trae foto propia, quedan las del producto.
    expect(
      ProductGallery.resolveImages(<String>['https://x/a.jpg']),
      <String>['https://x/a.jpg'],
    );

    // Sin fotos la galería queda vacía (el detalle pinta el marcador).
    expect(ProductGallery.resolveImages(const <String>[]), isEmpty);
  });

  testWidgets('la galería recorre todas las fotos del producto', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      product: _product(
        generalImages: <String>[
          'https://ezyventas2.test/storage/filtro.jpg',
          'https://ezyventas2.test/storage/filtro-2.jpg',
        ],
      ),
    );

    final gallery = tester.widget<ProductGallery>(find.byType(ProductGallery));

    // La portada repetida en `general_images` no cuenta dos veces: 2 páginas.
    expect(gallery.images, hasLength(2));
    expect(gallery.overrideImage, isNull);
    expect(find.byTooltip('Imagen anterior'), findsOneWidget);
    expect(find.byTooltip('Imagen siguiente'), findsOneWidget);
    expect(find.byKey(const Key('gallery-dot-0')), findsOneWidget);
    expect(find.byKey(const Key('gallery-dot-1')), findsOneWidget);
    expect(find.byKey(const Key('gallery-dot-2')), findsNothing);

    // La flecha avanza la página del `PageView` (antes solo se veía la primera).
    await tester.tap(find.byTooltip('Imagen siguiente'));
    await tester.pumpAndSettle();

    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
  });

  testWidgets('con una sola foto no hay flechas ni puntos', (tester) async {
    await _pumpSheet(
      tester,
      product: _product(
        generalImages: <String>['https://ezyventas2.test/storage/filtro.jpg'],
      ),
    );

    expect(find.byTooltip('Imagen siguiente'), findsNothing);
    expect(find.byTooltip('Imagen anterior'), findsNothing);
    expect(find.byKey(const Key('gallery-dot-0')), findsNothing);
  });

  testWidgets('sin fotos la galería muestra el marcador de la pantalla', (
    tester,
  ) async {
    await _pumpSheet(tester);

    expect(find.byType(ProductGallery), findsOneWidget);
    expect(find.byType(ImagePlaceholder), findsOneWidget);
    expect(find.byTooltip('Imagen siguiente'), findsNothing);
  });

  testWidgets('la variante elegida pinta su propia foto en la galería', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      product: _product(
        withVariants: true,
        generalImages: <String>['https://ezyventas2.test/storage/filtro.jpg'],
        variantImage: 'https://ezyventas2.test/storage/filtro-m.jpg',
      ),
    );

    // El detalle abre con la primera combinación («Talla M»), así que la foto de
    // esa variante manda y las del producto quedan como segunda página.
    var gallery = tester.widget<ProductGallery>(find.byType(ProductGallery));
    expect(
      gallery.overrideImage,
      'https://ezyventas2.test/storage/filtro-m.jpg',
    );
    expect(
      ProductGallery.resolveImages(
        gallery.images,
        overrideImage: gallery.overrideImage,
      ),
      <String>[
        'https://ezyventas2.test/storage/filtro-m.jpg',
        'https://ezyventas2.test/storage/filtro.jpg',
      ],
    );

    await tester.tap(find.text('Talla G'));
    await tester.pumpAndSettle();

    // «Talla G» no trae foto propia: se regresa a las imágenes del producto y a
    // la primera página de la galería.
    gallery = tester.widget<ProductGallery>(find.byType(ProductGallery));
    expect(gallery.overrideImage, isNull);
    expect(
      ProductGallery.resolveImages(
        gallery.images,
        overrideImage: gallery.overrideImage,
      ),
      <String>['https://ezyventas2.test/storage/filtro.jpg'],
    );
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
  });
}
