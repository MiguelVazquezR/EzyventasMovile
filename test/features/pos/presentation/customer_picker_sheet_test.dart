import 'package:ezyventas_app/core/api/paginated.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_button.dart';
import 'package:ezyventas_app/core/widgets/ezy_selectable_tile.dart';
import 'package:ezyventas_app/core/widgets/section_card.dart';
import 'package:ezyventas_app/features/customers/application/customers_providers.dart';
import 'package:ezyventas_app/features/customers/data/models/customer.dart';
import 'package:ezyventas_app/features/pos/application/cart_controller.dart';
import 'package:ezyventas_app/features/pos/presentation/widgets/customer_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Cliente con deuda y crédito (el que el cobro muestra con su saldo).
Customer _customer() => Customer.fromJson(<String, dynamic>{
  'id': 7,
  'name': 'Ferretería López',
  'phone': '477 123 4567',
  'balance': '-150.00',
  'credit_limit': '1000.00',
  'available_credit': 1000,
});

/// Monta el selector de cliente como lo abre el cobro y devuelve el contenedor
/// para leer el carrito. [failure] deja la búsqueda en estado de error.
Future<ProviderContainer> _pumpSheet(
  WidgetTester tester, {
  List<Customer>? customers,
  Object? failure,
  Customer? selected,
}) async {
  final container = ProviderContainer(
    // Riverpod 3 reintenta solo los `FutureProvider` fallidos (espera creciente),
    // así que durante el reintento la hoja sigue en `loading` y el aviso de error
    // nunca se pinta. En la prueba se apaga para poder comprobar ese aviso.
    retry: (retryCount, error) => null,
    overrides: [
      customerSearchProvider('').overrideWith((ref) async {
        if (failure != null) {
          throw failure;
        }

        final items = customers ?? <Customer>[_customer()];

        return Paginated<Customer>(
          items: items,
          currentPage: 1,
          lastPage: 1,
          perPage: 20,
          total: items.length,
        );
      }),
    ],
  );
  addTearDown(container.dispose);

  // Pantalla alta: la hoja (0.9 del alto) deja construida la lista de clientes
  // sin tener que desplazar.
  await tester.binding.setSurfaceSize(const Size(400, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  if (selected != null) {
    container.read(cartControllerProvider.notifier).setCustomer(selected);
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showCustomerPickerSheet(context),
                child: const Text('Elegir cliente'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  await tester.tap(find.text('Elegir cliente'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();

  return container;
}

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `NumberFormat` de es-MX puede
    // lanzar `LocaleDataException` al pintar los saldos.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('cabecera, público general y clientes con saldo', (tester) async {
    await _pumpSheet(tester);

    expect(find.text('Cliente de la venta'), findsOneWidget);
    expect(
      find.textContaining('Necesitas un cliente para dejar saldo pendiente'),
      findsOneWidget,
    );

    // La venta sin cliente registrado viene seleccionada de fábrica.
    expect(find.text('PÚBLICO GENERAL'), findsOneWidget);
    expect(find.text('Seleccionado'), findsOneWidget);
    expect(
      find.widgetWithText(EzyButton, 'Vender sin cliente'),
      findsOneWidget,
    );

    // Cliente de la lista: nombre, teléfono y saldo con crédito.
    expect(find.byType(EzySelectableTile), findsOneWidget);
    expect(find.text('Ferretería López'), findsOneWidget);
    expect(find.text('477 123 4567'), findsOneWidget);
    expect(find.textContaining('Saldo'), findsOneWidget);
    expect(find.textContaining('150.00'), findsOneWidget);
    expect(find.textContaining('Crédito disponible'), findsOneWidget);
    expect(find.textContaining('1,000.00'), findsOneWidget);
    expect(find.text('1 cliente'), findsOneWidget);
  });

  testWidgets('elegir un cliente lo guarda en el carrito y cierra la hoja', (
    tester,
  ) async {
    final container = await _pumpSheet(tester);

    await tester.tap(find.text('Ferretería López'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(cartControllerProvider).customer?.id, 7);
    expect(find.text('Ferretería López'), findsNothing);
  });

  testWidgets('vender sin cliente usa el nombre capturado para el ticket', (
    tester,
  ) async {
    final container = await _pumpSheet(tester);

    // El campo vive dentro de la card de público general; la hoja tiene además
    // el buscador, así que se acota el finder a esa card.
    await tester.enterText(
      find.descendant(
        of: find.ancestor(
          of: find.text('PÚBLICO GENERAL'),
          matching: find.byType(SectionCard),
        ),
        matching: find.byType(TextField),
      ),
      'Cliente de mostrador',
    );
    await tester.tap(find.widgetWithText(EzyButton, 'Vender sin cliente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final cart = container.read(cartControllerProvider);
    expect(cart.customer, isNull);
    expect(cart.guestName, 'Cliente de mostrador');
    expect(find.text('PÚBLICO GENERAL'), findsNothing);
  });

  testWidgets('el cliente elegido se marca en la lista', (tester) async {
    await _pumpSheet(tester, selected: _customer());

    // El check del tile seleccionado sustituye al "Seleccionado" del invitado.
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('Seleccionado'), findsNothing);
  });

  testWidgets('búsqueda sin resultados: estado vacío', (tester) async {
    await _pumpSheet(tester, customers: const <Customer>[]);

    expect(find.text('Sin resultados'), findsOneWidget);
    expect(
      find.textContaining('No hay clientes que coincidan con la búsqueda.'),
      findsOneWidget,
    );
    expect(find.byType(EzySelectableTile), findsNothing);
  });

  testWidgets('error de red: avisa y ofrece reintentar', (tester) async {
    await _pumpSheet(tester, failure: Exception('sin red'));

    expect(find.text('No se pudieron cargar los clientes.'), findsOneWidget);
    // El aviso de error del design system ofrece la acción subrayada.
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
