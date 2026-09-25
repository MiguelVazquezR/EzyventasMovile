import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_bottom_sheet.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/features/catalog/application/catalog_pickers.dart';
import 'package:ezyventas_app/features/catalog/application/catalog_providers.dart';
import 'package:ezyventas_app/features/catalog/data/models/catalog_service.dart';
import 'package:ezyventas_app/features/catalog/data/models/product.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_detail.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_item_draft.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_items_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'service_orders_sheets_harness.dart';

/// Concepto de catálogo que ofrece el selector (`GET /catalog/services`).
CatalogService itemsCatalogService() =>
    CatalogService.fromJson(<String, dynamic>{
      'id': 12,
      'name': 'Cambio de pantalla',
      'category': 'Reparación',
      'base_price': '850.00',
      'show_online': true,
      'variants': <Map<String, dynamic>>[],
    });

/// Concepto de la orden (refacción del inventario).
ServiceOrderItemDraft partDraft() => const ServiceOrderItemDraft(
  description: 'Mica templada',
  quantity: 2,
  unitPrice: 100,
  itemableType: ServiceOrderItemType.product,
  itemableId: 78,
);

/// Editor de conceptos tal como lo abre el alta de la orden.
Future<void> pumpItemsSheet(
  WidgetTester tester, {
  List<ServiceOrderItemDraft> items = const <ServiceOrderItemDraft>[],
  List<CatalogService> services = const <CatalogService>[],
  void Function(List<ServiceOrderItemDraft>?)? onResult,
}) async {
  await useTallScreen(tester);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // El selector de catálogo vive detrás del botón «Del catálogo»: se
        // sirven las dos listas sin tocar la red.
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
          (ref) async => const Paginated<Product>(
            items: <Product>[],
            currentPage: 1,
            lastPage: 1,
            perPage: 30,
            total: 0,
          ),
        ),
      ],
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  final result = await showServiceOrderItemsSheet(
                    context,
                    items: items,
                  );
                  onResult?.call(result);
                },
                child: const Text('Conceptos'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await openSheet(tester, 'Conceptos');
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('la cabecera usa el subtítulo del stock y el cierre', (
    tester,
  ) async {
    await pumpItemsSheet(tester);

    final header = tester.widget<EzySheetHeader>(find.byType(EzySheetHeader));
    expect(header.title, 'Conceptos de la orden');
    expect(
      header.subtitle,
      'Las refacciones descuentan stock al guardar la orden.',
    );
    expect(find.byTooltip('Cerrar'), findsOneWidget);

    // Las tarjetas del design system, con el conteo del servidor.
    expect(find.text('0 CONCEPTOS'), findsOneWidget);
    expect(find.text('AGREGAR'), findsOneWidget);
    expect(find.text('SUBTOTAL DE CONCEPTOS'), findsOneWidget);
    expect(
      find.text('Aún no hay conceptos. Agrega mano de obra o refacciones.'),
      findsOneWidget,
    );
  });

  testWidgets('lista los conceptos con su cantidad, precio y total', (
    tester,
  ) async {
    await pumpItemsSheet(tester, items: <ServiceOrderItemDraft>[partDraft()]);

    expect(find.text('1 CONCEPTO'), findsOneWidget);
    expect(find.text('Mica templada'), findsOneWidget);
    // `Refacción · 2 × $100.00` en la segunda línea de la fila.
    expect(find.textContaining('2 ×'), findsOneWidget);
    expect(find.textContaining('Refacción'), findsOneWidget);
    expect(find.text(r'$200.00'), findsWidgets);
    expect(find.byTooltip('Quitar concepto'), findsOneWidget);
  });

  testWidgets('quitar un concepto lo saca de la lista', (tester) async {
    await pumpItemsSheet(tester, items: <ServiceOrderItemDraft>[partDraft()]);

    await tester.tap(find.byTooltip('Quitar concepto'));
    await settleSheet(tester);

    expect(find.text('Mica templada'), findsNothing);
    expect(find.text('0 CONCEPTOS'), findsOneWidget);
  });

  testWidgets('un concepto libre se captura en el editor de la hoja', (
    tester,
  ) async {
    await pumpItemsSheet(tester);

    await tester.tap(find.text('Concepto libre'));
    await settleSheet(tester);

    // El editor se abre **encima** del editor de conceptos: se lee el último.
    final header = tester.widget<EzySheetHeader>(
      find.byType(EzySheetHeader).last,
    );
    expect(header.title, 'Concepto libre');
    expect(find.text('DESCRIPCIÓN *'), findsOneWidget);
    expect(find.text('CANTIDAD *'), findsOneWidget);
    expect(find.text('PRECIO UNITARIO *'), findsOneWidget);
    // `SectionRow` no sube a micro-mayúsculas: el texto va tal cual.
    expect(find.text('Total del concepto'), findsOneWidget);

    // Falta el precio: «Aplicar» sigue deshabilitado.
    expect(
      tester
          .widget<EzyButton>(find.widgetWithText(EzyButton, 'Aplicar'))
          .onPressed,
      isNull,
    );

    // Descripción, cantidad y precio unitario.
    await tester.enterText(find.byType(TextField).at(0), 'Cambio de pantalla');
    await tester.enterText(find.byType(TextField).at(2), '450');
    await settleSheet(tester);

    await tester.tap(find.widgetWithText(EzyButton, 'Aplicar'));
    await settleSheet(tester);

    expect(find.text('Cambio de pantalla'), findsOneWidget);
    // El concepto libre se lista con su tipo en la segunda línea.
    expect(find.text(r'Concepto libre · 1 × $450.00'), findsOneWidget);
    expect(find.text(r'$450.00'), findsWidgets);
  });

  testWidgets('del catálogo se agrega con el precio del servidor', (
    tester,
  ) async {
    await pumpItemsSheet(
      tester,
      services: <CatalogService>[itemsCatalogService()],
    );

    await tester.tap(find.text('Del catálogo'));
    await settleSheet(tester);

    // El selector de conceptos se abre encima: se lee su cabecera.
    final header = tester.widget<EzySheetHeader>(
      find.byType(EzySheetHeader).last,
    );
    expect(header.title, 'Agregar concepto');
    expect(find.text('Cambio de pantalla'), findsOneWidget);
    expect(find.text(r'$850.00'), findsOneWidget);

    await tester.tap(find.text('Cambio de pantalla'));
    await settleSheet(tester);
    await tester.pump();

    // De vuelta en el editor de conceptos, con la línea agregada.
    expect(find.text('AGREGAR'), findsOneWidget);
    expect(find.text('Cambio de pantalla'), findsOneWidget);
    expect(find.text(r'$850.00'), findsWidgets);
    expect(find.byTooltip('Quitar concepto'), findsOneWidget);
  });

  testWidgets('Listo devuelve los conceptos y cierra la hoja', (tester) async {
    List<ServiceOrderItemDraft>? result;

    await pumpItemsSheet(
      tester,
      items: <ServiceOrderItemDraft>[partDraft()],
      onResult: (value) => result = value,
    );

    await tester.tap(find.widgetWithText(EzyButton, 'Listo'));
    await settleSheet(tester);

    expect(result, hasLength(1));
    expect(result!.single.description, 'Mica templada');
    expect(result!.single.lineTotal, 200);
    expect(find.text('Conceptos de la orden'), findsNothing);
  });
}
