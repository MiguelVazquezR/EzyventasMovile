import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_list_tile.dart';
import 'package:ezyventas_app/core/widgets/ezy_search_field.dart';
import 'package:ezyventas_app/core/widgets/ezy_selectable_tile.dart';
import 'package:ezyventas_app/core/widgets/ezy_text_field.dart';
import 'package:ezyventas_app/features/catalog/application/catalog_pickers.dart';
import 'package:ezyventas_app/features/catalog/application/catalog_providers.dart';
import 'package:ezyventas_app/features/catalog/data/models/catalog_service.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/customers/application/customers_providers.dart';
import 'package:ezyventas_app/features/customers/data/models/customer.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_detail.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_item_draft.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_catalog_picker.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_customer_picker.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_variant_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'service_orders_sheets_harness.dart';

/// Servicio del catálogo; [variants] agrega variantes (el precio de la variante
/// es el que viaja en el concepto).
CatalogService pickerService({
  bool withVariants = false,
  double basePrice = 850,
}) => CatalogService.fromJson(<String, dynamic>{
  'id': 12,
  'name': 'Cambio de pantalla',
  'category': 'Reparación',
  'base_price': basePrice.toStringAsFixed(2),
  'show_online': true,
  'variants': withVariants
      ? <Map<String, dynamic>>[
          <String, dynamic>{'id': 31, 'name': 'Original', 'price': 850.0},
          <String, dynamic>{'id': 32, 'name': 'Pantalla OLED', 'price': 990.0},
        ]
      : <Map<String, dynamic>>[],
});

/// Refacción del inventario (`GET /catalog/products`).
Product pickerProduct() => Product.fromJson(<String, dynamic>{
  'id': 78,
  'name': 'Mica templada',
  'sku': 'MIC-001',
  'category': 'Micas',
  'price': 100.0,
  'stock': 25.0,
  'measure_unit': 'pz',
  'is_bulk': false,
  'show_in_pos': true,
});

/// Cliente con deuda y crédito (el selector muestra los dos datos).
Customer pickerCustomer() => Customer.fromJson(<String, dynamic>{
  'id': 7,
  'name': 'Ferretería López',
  'phone': '477 123 4567',
  'balance': '-150.00',
  'credit_limit': '1000.00',
  'available_credit': 1000,
});

/// Monta el selector pedido sobre una app mínima y abre su hoja.
Future<void> pumpPicker(
  WidgetTester tester, {
  required String openLabel,
  required void Function(BuildContext context) open,
  List<CatalogService> services = const <CatalogService>[],
  List<Product> products = const <Product>[],
  List<Customer> customers = const <Customer>[],
}) async {
  await useTallScreen(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        servicesProvider(null).overrideWith(
          (ref) async => Paginated<CatalogService>(
            items: services,
            currentPage: 1,
            lastPage: 1,
            perPage: 50,
            total: services.length,
          ),
        ),
        productSearchProvider('').overrideWith(
          (ref) async => Paginated<Product>(
            items: products,
            currentPage: 1,
            lastPage: 1,
            perPage: 30,
            total: products.length,
          ),
        ),
        customerSearchProvider('').overrideWith(
          (ref) async => Paginated<Customer>(
            items: customers,
            currentPage: 1,
            lastPage: 1,
            perPage: 20,
            total: customers.length,
          ),
        ),
      ],
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => open(context),
                child: Text(openLabel),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await openSheet(tester, openLabel);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la variante se elige con la fila del design system', (
    tester,
  ) async {
    VariantOption? chosen;

    await pumpPicker(
      tester,
      openLabel: 'Variante',
      open: (context) async {
        chosen = await showServiceOrderVariantPicker(
          context,
          title: 'Cambio de pantalla',
          options: const <VariantOption>[
            VariantOption(
              id: 31,
              label: 'Original',
              price: 850,
              itemableType: ServiceOrderItemType.serviceVariant,
            ),
            VariantOption(
              id: 32,
              label: 'Pantalla OLED',
              price: 990,
              itemableType: ServiceOrderItemType.serviceVariant,
            ),
          ],
        );
      },
    );

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Elegir variante');
    expect(header.subtitle, 'Cambio de pantalla');
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    // Cada variante es una opción seleccionable con su precio.
    expect(find.byType(EzySelectableTile), findsNWidgets(2));
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('Pantalla OLED'), findsOneWidget);
    expect(find.text(r'$850.00'), findsOneWidget);
    expect(find.text(r'$990.00'), findsOneWidget);

    await tester.tap(find.text('Pantalla OLED'));
    await settleSheet(tester);
    await tester.pump();

    expect(chosen?.id, 32);
    expect(chosen?.label, 'Pantalla OLED');
    expect(chosen?.price, 990);
    expect(find.text('Elegir variante'), findsNothing);
  });

  testWidgets('el catálogo lista los servicios con su precio más bajo', (
    tester,
  ) async {
    ServiceOrderItemDraft? chosen;

    await pumpPicker(
      tester,
      openLabel: 'Catálogo',
      services: <CatalogService>[pickerService()],
      open: (context) async {
        chosen = await showServiceOrderCatalogPicker(context);
      },
    );

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Agregar concepto');
    expect(header.subtitle, 'Elige del catálogo o captura un concepto libre.');
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    // Buscador del sistema (con su *debounce* y botón de limpiar).
    final search = tester.widget<EzySearchField>(find.byType(EzySearchField));
    expect(search.hint, 'Buscar en el catálogo…');

    // Tipo de concepto y fila del sistema con el precio de lista.
    expect(find.text('Mano de obra'), findsOneWidget);
    expect(find.text('Refacciones'), findsOneWidget);
    expect(find.byType(EzyListTile), findsOneWidget);
    expect(find.text('Cambio de pantalla'), findsOneWidget);
    expect(find.text(r'$850.00'), findsOneWidget);
    expect(find.textContaining('Precio de lista'), findsOneWidget);

    await tester.tap(find.text('Cambio de pantalla'));
    await settleSheet(tester);
    await tester.pump();

    expect(chosen?.description, 'Cambio de pantalla');
    expect(chosen?.unitPrice, 850);
    expect(chosen?.itemableType, ServiceOrderItemType.service);
    expect(chosen?.itemableId, 12);
  });

  testWidgets('la pestaña de refacciones lista los productos con su stock', (
    tester,
  ) async {
    ServiceOrderItemDraft? chosen;

    await pumpPicker(
      tester,
      openLabel: 'Catálogo',
      products: <Product>[pickerProduct()],
      open: (context) async {
        chosen = await showServiceOrderCatalogPicker(context);
      },
    );

    await tester.tap(find.text('Refacciones'));
    await settleSheet(tester);

    expect(find.text('Mica templada'), findsOneWidget);
    expect(find.textContaining('SKU MIC-001'), findsOneWidget);
    expect(find.textContaining('Stock 25'), findsOneWidget);

    await tester.tap(find.text('Mica templada'));
    await settleSheet(tester);
    await tester.pump();

    expect(chosen?.description, 'Mica templada');
    expect(chosen?.unitPrice, 100);
    expect(chosen?.itemableType, ServiceOrderItemType.product);
    expect(chosen?.itemableId, 78);
  });

  testWidgets('un servicio con variantes pide la variante antes de volver', (
    tester,
  ) async {
    ServiceOrderItemDraft? chosen;

    await pumpPicker(
      tester,
      openLabel: 'Catálogo',
      services: <CatalogService>[pickerService(withVariants: true)],
      open: (context) async {
        chosen = await showServiceOrderCatalogPicker(context);
      },
    );

    expect(find.textContaining('2 variantes'), findsOneWidget);
    expect(find.text(r'$850.00'), findsOneWidget);

    await tester.tap(find.text('Cambio de pantalla'));
    await settleSheet(tester);

    // El selector de variante se abre encima del catálogo.
    final header = tester.widget<EzySheetHeader>(
      find.byType(EzySheetHeader).last,
    );
    expect(header.title, 'Elegir variante');
    expect(header.subtitle, 'Cambio de pantalla');

    await tester.tap(find.text('Pantalla OLED'));
    await settleSheet(tester);
    await tester.pump();

    expect(chosen?.description, 'Cambio de pantalla · Pantalla OLED');
    expect(chosen?.unitPrice, 990);
    expect(chosen?.itemableType, ServiceOrderItemType.serviceVariant);
    expect(chosen?.itemableId, 32);
  });

  testWidgets('el cliente se elige con su saldo y crédito', (tester) async {
    ServiceOrderCustomerSelection? chosen;

    await pumpPicker(
      tester,
      openLabel: 'Cliente',
      customers: <Customer>[pickerCustomer()],
      open: (context) async {
        chosen = await showServiceOrderCustomerPicker(context);
      },
    );

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Cliente de la orden');
    expect(
      header.subtitle,
      'Puedes elegir un cliente registrado o capturar los datos a mano.',
    );
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    final search = tester.widget<EzySearchField>(find.byType(EzySearchField));
    expect(search.hint, 'Buscar cliente por nombre, correo o teléfono…');

    expect(find.byType(EzySelectableTile), findsOneWidget);
    expect(find.text('Ferretería López'), findsOneWidget);
    expect(find.text('477 123 4567'), findsOneWidget);
    expect(find.textContaining('Crédito disponible'), findsOneWidget);

    await tester.tap(find.text('Ferretería López'));
    await settleSheet(tester);
    await tester.pump();

    expect(chosen?.customerId, 7);
    expect(chosen?.name, 'Ferretería López');
    expect(chosen?.phone, '477 123 4567');
    expect(chosen?.createCustomer, isFalse);
  });

  testWidgets('el cliente se puede capturar a mano', (tester) async {
    ServiceOrderCustomerSelection? chosen;

    await pumpPicker(
      tester,
      openLabel: 'Cliente',
      open: (context) async {
        chosen = await showServiceOrderCustomerPicker(context);
      },
    );

    expect(find.text('CAPTURAR CLIENTE'), findsOneWidget);
    expect(find.text('NOMBRE'), findsOneWidget);
    expect(find.text('TELÉFONO'), findsOneWidget);
    expect(find.text('CORREO ELECTRÓNICO'), findsOneWidget);

    // Sin nombre no se puede aplicar lo capturado.
    expect(
      tester
          .widget<EzyButton>(find.widgetWithText(EzyButton, 'Usar estos datos'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.descendant(
        of: find.byType(EzyTextField).first,
        matching: find.byType(TextField),
      ),
      'Cliente de mostrador',
    );
    await settleSheet(tester);

    await tester.tap(find.widgetWithText(EzyButton, 'Usar estos datos'));
    await settleSheet(tester);
    await tester.pump();

    expect(chosen?.name, 'Cliente de mostrador');
    expect(chosen?.customerId, isNull);
    expect(chosen?.createCustomer, isFalse);
  });

  testWidgets('dar de alta al cliente pide el límite de crédito', (
    tester,
  ) async {
    ServiceOrderCustomerSelection? chosen;

    await pumpPicker(
      tester,
      openLabel: 'Cliente',
      open: (context) async {
        chosen = await showServiceOrderCustomerPicker(context);
      },
    );

    expect(find.text(r'LÍMITE DE CRÉDITO *'), findsNothing);

    await tester.tap(find.byType(Switch));
    await settleSheet(tester);

    expect(find.text(r'LÍMITE DE CRÉDITO *'), findsOneWidget);
    expect(
      find.text('Requerido al dar de alta un cliente nuevo.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.descendant(
        of: find.byType(EzyTextField).first,
        matching: find.byType(TextField),
      ),
      'Taller Nuevo',
    );
    // El límite de crédito es el único campo de dinero de la hoja.
    await tester.enterText(find.byType(EzyTextField).last, '1500');
    await settleSheet(tester);

    await tester.tap(find.widgetWithText(EzyButton, 'Usar estos datos'));
    await settleSheet(tester);
    await tester.pump();

    expect(chosen?.name, 'Taller Nuevo');
    expect(chosen?.createCustomer, isTrue);
    expect(chosen?.creditLimit, 1500);
  });
}
