import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/theme/app_colors.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/catalog/application/catalog_providers.dart';
import 'package:ezyventas_app/features/catalog/data/catalog_repository.dart';
import 'package:ezyventas_app/features/catalog/data/models/category.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/catalog/presentation/widgets/catalog_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Catálogo falso: el carrusel no toca la red.
class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository(this.categories)
    : super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final List<Category> categories;

  @override
  Future<List<Category>> fetchCategories({
    CatalogCategoryType type = CatalogCategoryType.product,
  }) async => categories;

  @override
  Future<Paginated<Product>> fetchProducts({
    String? search,
    int? categoryId,
    int page = 1,
    int perPage = 20,
    String? updatedSince,
  }) async => Paginated<Product>(
    items: const <Product>[],
    currentPage: 1,
    lastPage: 1,
    perPage: perPage,
    total: 0,
  );
}

/// Monta el carrusel con las categorías indicadas y devuelve el contenedor para
/// poder leer la categoría elegida.
Future<ProviderContainer> _pumpCarousel(
  WidgetTester tester,
  List<Category> categories,
) async {
  final container = ProviderContainer(
    overrides: [
      catalogRepositoryProvider.overrideWithValue(
        _FakeCatalogRepository(categories),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: const Scaffold(body: CatalogCategoryChips()),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

/// Color de la teja de una categoría.
///
/// La etiqueta y la teja son hermanas dentro del `Column` del tile, así que el
/// cuadro se busca **dentro** del gesto que envuelve toda la categoría.
Color _tileColor(WidgetTester tester, String label) {
  final tile = find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .first;
  final decoration =
      tester
              .widget<AnimatedContainer>(
                find.descendant(
                  of: tile,
                  matching: find.byType(AnimatedContainer),
                ),
              )
              .decoration
          as BoxDecoration;

  return decoration.color!;
}

void main() {
  testWidgets('la categoría activa se rellena con el color de marca', (
    tester,
  ) async {
    final container = await _pumpCarousel(tester, <Category>[
      const Category(id: 7, name: 'Aceites y lubricantes'),
      const Category(id: 8, name: 'Herramienta'),
    ]);

    // Sin filtro manda «Todas».
    expect(_tileColor(tester, 'Todas'), EzyColors.primary);
    expect(_tileColor(tester, 'Herramienta'), isNot(EzyColors.primary));

    await tester.tap(find.text('Herramienta'));
    await tester.pumpAndSettle();

    expect(
      container.read(
        productsControllerProvider.select((state) => state.categoryId),
      ),
      8,
    );
    expect(_tileColor(tester, 'Herramienta'), EzyColors.primary);
    expect(_tileColor(tester, 'Todas'), isNot(EzyColors.primary));
  });

  testWidgets('la teja elige su icono por palabra clave del nombre', (
    tester,
  ) async {
    await _pumpCarousel(tester, <Category>[
      const Category(id: 7, name: 'Aceites y lubricantes'),
      const Category(id: 8, name: 'Sin pista'),
    ]);

    expect(find.byIcon(Icons.oil_barrel_outlined), findsOneWidget);
    // Sin palabra clave reconocible queda el icono genérico de categoría.
    expect(find.byIcon(Icons.category_outlined), findsOneWidget);
  });

  testWidgets('sin categorías contratadas el carrusel no ocupa sitio', (
    tester,
  ) async {
    await _pumpCarousel(tester, const <Category>[]);

    expect(find.byType(AnimatedContainer), findsNothing);
  });
}
