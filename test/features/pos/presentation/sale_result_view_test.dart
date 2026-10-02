import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_primary_3d_button.dart';
import 'package:ezyventas_app/features/pos/data/models/checkout_result.dart';
import 'package:ezyventas_app/features/pos/presentation/widgets/sale_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Respuesta del cobro como la manda el servidor: el folio, los montos y el
/// cambio no los calcula la app.
Map<String, dynamic> _payload({
  String status = 'completado',
  String totalPaid = '300.00',
  String remainingDue = '0',
  String change = '0',
  String? customerName = 'Ana López',
}) => <String, dynamic>{
  'transaction': <String, dynamic>{
    'id': 21,
    'folio': 'V-014',
    'status': status,
    'channel': 'pos',
    'subtotal': '270.00',
    'total_discount': '0',
    'total': '270.00',
    'total_paid': totalPaid,
    'remaining_due': remainingDue,
    'items_count': 2,
    'customer': customerName == null
        ? null
        : <String, dynamic>{'name': customerName},
    'created_at': '2026-09-25T10:00:00-06:00',
  },
  'change': change,
  'print': <String, dynamic>{
    'data_source_type': 'pos',
    'data_source_id': 21,
    'template_ids': <int>[3],
  },
};

CheckoutResult _result({
  String status = 'completado',
  String totalPaid = '300.00',
  String remainingDue = '0',
  String change = '0',
  String? customerName = 'Ana López',
}) => CheckoutResult.fromJson(
  _payload(
    status: status,
    totalPaid: totalPaid,
    remainingDue: remainingDue,
    change: change,
    customerName: customerName,
  ),
);

/// Pinta el resultado del cobro con el alto acotado (el pie del CTA vive dentro
/// del `Expanded`, igual que en la hoja del carrito).
///
/// **No se usa `pumpAndSettle`**: el punto del estatus late en bucle, así que
/// esperar a que la animación termine nunca devolvería el control.
Future<void> _pumpResult(
  WidgetTester tester,
  CheckoutResult result, {
  VoidCallback? onDone,
}) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: EzyTheme.dark(),
        home: Scaffold(
          body: SaleResultView(result: result, onDone: onDone ?? () {}),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// `true` cuando el botón de imprimir se puede tocar. La cara del botón la
/// pinta el design system sobre un `FilledButton`, igual que lo lee la prueba
/// de la hoja de impresión.
bool _printEnabled(WidgetTester tester) {
  final button = tester.widget<FilledButton>(
    find
        .ancestor(
          of: find.text('Imprimir ticket'),
          matching: find.byType(FilledButton),
        )
        .first,
  );

  return button.onPressed != null;
}

void main() {
  setUpAll(() async {
    // Igual que `main()` de la app: sin esto `NumberFormat` de es-MX puede
    // lanzar `LocaleDataException` al pintar los montos.
    await initializeDateFormatting('es_MX');
    Intl.defaultLocale = 'es_MX';
  });

  testWidgets('venta cobrada: folio real, totales y cambio a entregar', (
    tester,
  ) async {
    await _pumpResult(tester, _result(change: '30.00'));

    // El folio del servidor es el protagonista de la card (§1 del rediseño).
    expect(find.text('V-014'), findsOneWidget);
    expect(find.text('FOLIO DE VENTA'), findsOneWidget);
    expect(find.text('Venta cobrada'), findsOneWidget);
    expect(find.text('Completado'), findsOneWidget);

    // Un solo bloque de totales, con el total en el naranja de marca.
    expect(find.text('TOTAL DE LA VENTA'), findsOneWidget);
    expect(find.textContaining('270.00'), findsWidgets);
    expect(find.text('Cliente'), findsOneWidget);
    expect(find.text('Ana López'), findsOneWidget);
    expect(find.text('Monto pagado / capturado'), findsOneWidget);
    // Cobrada: no hay saldo pendiente que reclamar.
    expect(find.text('Saldo pendiente'), findsNothing);

    // El cambio llega del servidor y se anuncia en su bloque verde.
    expect(find.text('CAMBIO A ENTREGAR'), findsOneWidget);
    expect(find.textContaining('30.00'), findsWidgets);

    // El estatus late: el punto va montado.
    expect(find.byType(FadeTransition), findsWidgets);
  });

  testWidgets('el CTA de 56 px cierra el resultado con una sola acción', (
    tester,
  ) async {
    var done = false;

    await _pumpResult(tester, _result(), onDone: () => done = true);

    final cta = find.byType(EzyPrimary3dButton);
    expect(cta, findsOneWidget);
    expect(
      find.descendant(of: cta, matching: find.text('Nueva venta')),
      findsOneWidget,
    );
    // El rediseño pide el CTA de 56 px del cobro.
    expect(tester.widget<EzyPrimary3dButton>(cta).height, 56);

    await tester.tap(cta);
    await tester.pump();

    expect(done, isTrue);
  });

  testWidgets('venta apartada: avisa el saldo pendiente y no hay cambio', (
    tester,
  ) async {
    await _pumpResult(
      tester,
      _result(status: 'apartado', totalPaid: '170.00', remainingDue: '100.00'),
    );

    expect(find.text('Venta registrada'), findsOneWidget);
    expect(find.text('Apartado'), findsOneWidget);
    expect(find.text('Saldo pendiente'), findsOneWidget);
    expect(find.textContaining('100.00'), findsWidgets);
    expect(find.text('CAMBIO A ENTREGAR'), findsNothing);
  });

  testWidgets('sin impresora conectada el ticket no se puede imprimir', (
    tester,
  ) async {
    await _pumpResult(tester, _result());

    // El estado de la impresora se anuncia antes de los botones y el de
    // imprimir queda apagado: en las pruebas no hay plugin de Bluetooth.
    expect(find.textContaining('Impresora Bluetooth'), findsOneWidget);
    expect(_printEnabled(tester), isFalse);

    // El envío por WhatsApp no depende de la impresora.
    expect(find.text('Enviar por WhatsApp'), findsOneWidget);
  });

  testWidgets('cliente anónimo y sin descuento: no se inventan filas', (
    tester,
  ) async {
    await _pumpResult(tester, _result(customerName: null));

    expect(find.text('Público general'), findsOneWidget);
    expect(find.text('Descuento aplicado'), findsNothing);
  });
}
