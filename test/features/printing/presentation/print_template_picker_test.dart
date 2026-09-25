import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/ezy_selectable_tile.dart';
import 'package:ezyventas_app/features/printing/data/models/print_template.dart';
import 'package:ezyventas_app/features/printing/presentation/widgets/print_template_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plantilla como la devuelve `GET /print/templates`.
PrintTemplate _template({
  required int id,
  required String name,
  String type = 'ticket_venta',
  String context = 'transaction',
  String paperWidth = '80mm',
  bool isDefault = false,
}) => PrintTemplate(
  id: id,
  name: name,
  type: type,
  contextType: context,
  paperWidth: paperWidth,
  isDefault: isDefault,
  config: const <String, dynamic>{},
);

/// Monta el selector suelto (la hoja de impresión lo dibuja dentro de su card).
Future<void> _pumpPicker(
  WidgetTester tester, {
  required List<PrintTemplate> templates,
  int? selectedId,
  ValueChanged<PrintTemplate>? onSelected,
  String? emptyMessage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: EzyTheme.dark(),
      home: Scaffold(
        body: PrintTemplatePicker(
          templates: templates,
          selectedId: selectedId,
          onSelected: onSelected ?? (_) {},
          emptyMessage: emptyMessage,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('lista las plantillas con la fila del design system', (
    tester,
  ) async {
    await _pumpPicker(
      tester,
      templates: <PrintTemplate>[
        _template(id: 3, name: 'Ticket de venta', isDefault: true),
        _template(id: 7, name: 'Ticket de venta A2', paperWidth: '58mm'),
      ],
      selectedId: 3,
    );

    // Nombre y detalle (`80mm · predeterminada`) en el mismo componente que
    // usan el detalle de producto y el cobro.
    final tiles = find.byType(EzySelectableTile);
    expect(tiles, findsNWidgets(2));
    expect(find.text('Ticket de venta'), findsOneWidget);
    expect(find.text('Ticket de venta A2'), findsOneWidget);
    expect(find.textContaining('80mm'), findsOneWidget);
    expect(find.textContaining('predeterminada'), findsOneWidget);
    expect(find.textContaining('58mm'), findsOneWidget);

    // La elegida se marca en el componente (check + tinte), no con un radio
    // dibujado aquí.
    expect(tester.widget<EzySelectableTile>(tiles.at(0)).isSelected, isTrue);
    expect(tester.widget<EzySelectableTile>(tiles.at(1)).isSelected, isFalse);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('elegir una plantilla avisa al que la usa', (tester) async {
    final selected = <PrintTemplate>[];

    await _pumpPicker(
      tester,
      templates: <PrintTemplate>[
        _template(id: 3, name: 'Ticket de venta', isDefault: true),
        _template(id: 7, name: 'Ticket de venta A2', paperWidth: '58mm'),
      ],
      selectedId: 3,
      onSelected: selected.add,
    );

    await tester.tap(find.text('Ticket de venta A2'));
    await tester.pump();

    expect(selected, hasLength(1));
    expect(selected.single.id, 7);
  });

  testWidgets('sin plantillas lo explica en un aviso', (tester) async {
    await _pumpPicker(tester, templates: const <PrintTemplate>[]);

    expect(
      find.textContaining('No hay plantillas de impresión configuradas'),
      findsOneWidget,
    );
    expect(find.byType(EzySelectableTile), findsNothing);
  });

  testWidgets('el mensaje de vacío lo puede imponer la hoja', (tester) async {
    await _pumpPicker(
      tester,
      templates: const <PrintTemplate>[],
      emptyMessage:
          'El negocio no tiene una plantilla de ticket de venta para este '
          'documento. Se configura en la web.',
    );

    expect(
      find.textContaining('El negocio no tiene una plantilla de'),
      findsOneWidget,
    );
  });
}
