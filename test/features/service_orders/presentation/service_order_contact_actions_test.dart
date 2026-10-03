import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/service_orders/data/models/service_order_detail.dart';
import 'package:ezyventas_app/features/service_orders/presentation/widgets/service_order_customer_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'service_orders_sheets_harness.dart';

/// Acciones de contacto de la ficha del cliente (`Llamar` / `WhatsApp`).
///
/// Se montan sobre una app mínima: el widget solo depende del teléfono del
/// cliente, así que no hace falta abrir el detalle completo. Los enlaces se
/// arman con los helpers del proyecto (`tel:` y `WhatsAppMessageBuilder.link`)
/// y se abren con `ExternalLinks`, que avisa si el teléfono no puede abrirlos.
Future<void> pumpContactActions(
  WidgetTester tester, {
  String? customerPhone = '4771112233',
}) async {
  final detail = ServiceOrderDetail.fromJson(
    orderDetailFixture(customerPhone: customerPhone),
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: EzyTheme.dark(),
      home: Scaffold(body: ServiceOrderContactActions(detail: detail)),
    ),
  );
}

void main() {
  testWidgets('con teléfono ofrece llamar y escribir por WhatsApp', (
    tester,
  ) async {
    await pumpContactActions(tester);

    expect(find.text('Llamar'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });

  testWidgets('sin teléfono el bloque no se pinta', (tester) async {
    await pumpContactActions(tester, customerPhone: null);

    expect(find.text('Llamar'), findsNothing);
    expect(find.text('WhatsApp'), findsNothing);
  });
}
