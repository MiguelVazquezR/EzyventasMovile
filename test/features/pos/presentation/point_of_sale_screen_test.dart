import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/auth/permissions_service.dart';
import 'package:ezyventas_app/core/scanner/scanner_providers.dart';
import 'package:ezyventas_app/core/theme/app_colors.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/app_drawer_scope.dart';
import 'package:ezyventas_app/core/widgets/ezy_header_band.dart';
import 'package:ezyventas_app/core/widgets/ezy_search_field.dart';
import 'package:ezyventas_app/core/widgets/user_avatar.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/catalog/application/catalog_providers.dart';
import 'package:ezyventas_app/features/catalog/data/catalog_repository.dart';
import 'package:ezyventas_app/features/catalog/data/models/category.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/pos/presentation/point_of_sale_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/auth/auth_harness.dart';

/// Código de barras de la corrida (EAN-13 de prueba).
const String scannedCode = '7501031311309';

const String searchHint = 'Buscar por nombre o SKU…';
const String scannerTooltip = 'Escanear código';

/// Catálogo falso: el POS no toca la red.
class _FakeCatalogRepository extends CatalogRepository {
  _FakeCatalogRepository({List<Map<String, dynamic>>? products})
    : products = products ?? <Map<String, dynamic>>[_product()],
      super(api: ApiClient(baseUrl: 'https://api.test/api/v1'));

  final List<Map<String, dynamic>> products;

  /// Búsquedas que pidió el catálogo, en orden.
  final List<String?> searches = <String?>[];

  @override
  Future<Paginated<Product>> fetchProducts({
    String? search,
    int? categoryId,
    int page = 1,
    int perPage = 20,
    String? updatedSince,
  }) async {
    searches.add(search);

    return Paginated<Product>(
      items: products.map(Product.fromJson).toList(growable: false),
      currentPage: 1,
      lastPage: 1,
      perPage: perPage,
      total: products.length,
    );
  }

  @override
  Future<List<Category>> fetchCategories({
    CatalogCategoryType type = CatalogCategoryType.product,
  }) async => const <Category>[];
}

Map<String, dynamic> _product() => <String, dynamic>{
  'id': 45,
  'name': 'Filtro de aceite',
  'sku': 'FIL-001',
  'selling_price': '150.00',
  'price': 135.0,
  'original_price': 150.0,
  'stock': 24.0,
  'show_in_pos': true,
};

/// Permisos del vendedor del mostrador: entra al POS y puede cobrar.
const List<String> _sellerPermissions = <String>['pos.access', 'pos.create_sale'];
const List<String> _sellerModules = <String>['module_pos'];

/// Monta el POS con el catálogo y el escáner sustituidos.
Future<_FakeCatalogRepository> _pumpPos(
  WidgetTester tester, {
  ScannerLauncher? launcher,
  ThemeData? theme,
  String? businessName,
}) async {
  final catalog = _FakeCatalogRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // El `AppScreenHeader` lee el contexto de acceso (chip de sucursal).
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            session: fakeSession(
              permissions: _sellerPermissions,
              modules: _sellerModules,
              businessName: businessName,
            ),
          ),
        ),
        catalogRepositoryProvider.overrideWithValue(catalog),
        permissionsProvider.overrideWithValue(
          PermissionsService.fromLists(
            permissions: _sellerPermissions,
            moduleKeys: _sellerModules,
          ),
        ),
        // Sin turno abierto: la pill del carrito avisa, pero la banda y el
        // buscador son los mismos.
        activeCashSessionProvider.overrideWithValue(null),
        scannerLauncherProvider.overrideWithValue(launcher ?? (_) async => null),
      ],
      child: MaterialApp(
        theme: theme ?? EzyTheme.dark(),
        home: const PointOfSaleScreen(),
      ),
    ),
  );

  // Carga del catálogo (microtarea + respuesta del repositorio falso).
  await tester.pump();
  await tester.pump();

  return catalog;
}

void main() {
  testWidgets('la cabecera lleva el negocio, la sucursal y el buscador', (
    tester,
  ) async {
    await _pumpPos(tester);

    // La cabecera es la banda curva con el degradado de marca: el avatar, el
    // nombre del negocio y la sucursal activa van dentro, y el buscador con su
    // botón de escáner también (no se va con el scroll).
    expect(find.byType(EzyHeaderBand), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(EzyHeaderBand),
        matching: find.text('Melchor Ocampo'),
      ),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(
        of: find.byType(EzyHeaderBand),
        matching: find.byIcon(Icons.storefront_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(EzyHeaderBand),
        matching: find.byType(UserAvatar),
      ),
      findsOneWidget,
    );
    expect(find.byType(EzySearchField), findsOneWidget);
    expect(find.text(searchHint), findsOneWidget);
    expect(find.byTooltip(scannerTooltip), findsOneWidget);
  });

  testWidgets('la banda lleva el vendedor y, debajo, el negocio · sucursal', (
    tester,
  ) async {
    await _pumpPos(tester, businessName: 'ApontePhone');

    final band = find.byType(EzyHeaderBand);

    // El titular de la banda es el vendedor de la sesión, no el negocio: el POS
    // lo opera una persona, y el negocio baja a la línea de apoyo.
    expect(
      find.descendant(of: band, matching: find.text('Miguel Osvaldo')),
      findsOneWidget,
    );
    // Debajo, el negocio con la sucursal activa, con el mismo separador que la
    // cabecera del menú lateral.
    expect(
      find.descendant(
        of: band,
        matching: find.text('ApontePhone · Melchor Ocampo'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('sin nombre de negocio la línea de apoyo no repite la sucursal', (
    tester,
  ) async {
    // Usuario sin suscripción: el contexto de acceso devuelve la sucursal como
    // nombre del negocio, y `Melchor Ocampo · Melchor Ocampo` no dice nada.
    await _pumpPos(tester);

    expect(
      find.descendant(
        of: find.byType(EzyHeaderBand),
        matching: find.text('Melchor Ocampo'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('el avatar sin foto se lee sobre la banda de marca', (
    tester,
  ) async {
    await _pumpPos(tester);

    // El servidor manda un `profile_photo_url` generado aunque el usuario no
    // tenga foto, así que lo normal es ver las iniciales: van sobre un degradado
    // blanco → gris (con las letras oscuras) para que se lean sobre el naranja.
    final avatar = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(UserAvatar),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = avatar.decoration! as BoxDecoration;

    expect(decoration.color, isNull);
    expect(decoration.gradient!.colors, <Color>[
      EzyColors.white,
      EzyColors.grayD9,
    ]);
  });

  testWidgets('el decorado de la banda es el degradado de marca', (tester) async {
    await _pumpPos(tester);

    final decoration =
        tester
                .widget<DecoratedBox>(
                  find
                      .descendant(
                        of: find.byType(EzyHeaderBand),
                        matching: find.byType(DecoratedBox),
                      )
                      .first,
                )
                .decoration
            as BoxDecoration;

    expect(decoration.gradient, isNotNull);
    expect(decoration.gradient!.colors.first, EzyColors.primary400);
  });

  testWidgets('sin cascarón la cabecera no ofrece el menú lateral', (
    tester,
  ) async {
    // El POS se monta aquí sin `AppDrawerScope`: no hay `Drawer` que abrir, así
    // que la hamburguesa no se pinta (y no se promete un menú inexistente).
    await _pumpPos(tester);

    expect(find.byTooltip(appDrawerOpenTooltip), findsNothing);
  });

  testWidgets('el buscador va como card claro con sombra sobre la banda', (
    tester,
  ) async {
    await _pumpPos(tester, theme: EzyTheme.light());

    // El campo es un card (`panel`, blanco) con relieve y borde normal: sobre el
    // naranja de la cabecera el borde reforzado ya no hace falta, y la sombra lo
    // separa del fondo claro.
    final field =
        tester.widget<Container>(
              find
                  .ancestor(
                    of: find.byType(TextField),
                    matching: find.byType(Container),
                  )
                  .first,
            ).decoration!
            as BoxDecoration;

    expect(field.color, EzySurfaces.light.panel);
    expect(field.boxShadow, isNotNull);
    expect((field.border! as Border).top.color, EzySurfaces.light.border);
    expect(tester.takeException(), isNull);
  });

  testWidgets('escribir en el buscador consulta el catálogo con retardo', (
    tester,
  ) async {
    final catalog = await _pumpPos(tester);
    catalog.searches.clear();

    await tester.enterText(find.byType(TextField), 'filtro');
    await tester.pump(const Duration(milliseconds: 400));

    expect(catalog.searches.last, 'filtro');
  });

  testWidgets('el escáner llena el buscador y confirma el código', (
    tester,
  ) async {
    final catalog = await _pumpPos(tester, launcher: (_) async => scannedCode);
    catalog.searches.clear();

    await tester.tap(find.byTooltip(scannerTooltip));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // El texto entra en la barra y el catálogo se filtra con él.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, scannedCode);
    expect(catalog.searches.last, scannedCode);

    // §12: la confirmación se da en la pantalla que abrió el escáner.
    expect(find.text('Código escaneado: $scannedCode'), findsOneWidget);
  });

  testWidgets('cerrar el escáner sin leer no cambia la búsqueda', (
    tester,
  ) async {
    final catalog = await _pumpPos(tester, launcher: (_) async => null);
    catalog.searches.clear();

    await tester.tap(find.byTooltip(scannerTooltip));
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    expect(catalog.searches, isEmpty);
    expect(find.textContaining('Código escaneado'), findsNothing);
  });
}
