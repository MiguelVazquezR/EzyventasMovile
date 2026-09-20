import 'dart:typed_data';

import '../../../../core/printing/esc_pos_builder.dart';
import '../../../../core/utils/money.dart';
import '../../cash/data/models/cash_movement.dart';
import 'models/cash_cut_document.dart';

/// Render del **corte de caja**: bytes ESC/POS para la impresora térmica y
/// texto plano para previsualizarlo o copiarlo.
///
/// El corte es el único documento que el servidor no codifica (el contrato §6.3
/// lo dice: no existe `cash_register_session` como `data_source_type`), así que
/// se arma aquí con los montos que ya calculó el backend.
class CashCutRenderer {
  const CashCutRenderer._();

  /// 48 caracteres en 80 mm, 32 en 58 mm.
  static Uint8List escPos(CashCutDocument cut, {int charactersPerLine = 48}) {
    final builder = EscPosBuilder(charactersPerLine: charactersPerLine)
      ..initialize()
      ..selectCp850()
      ..align(EscPosAlign.center)
      ..bold(enabled: true)
      ..doubleSize(enabled: true)
      ..text('CORTE DE CAJA')
      ..doubleSize(enabled: false)
      ..text(cut.businessName)
      ..bold(enabled: false)
      ..text('Sucursal: ${cut.branchName}')
      ..text('Terminal: ${cut.terminalName}')
      ..text('Abrió: ${cut.openerName}')
      ..text(usersLine(cut))
      ..text('Turno: ${cut.periodLabel}')
      ..align(EscPosAlign.left)
      ..separator();

    _amount(builder, 'Fondo inicial', cut.openingCash);
    _amount(builder, 'Ventas en efectivo', cut.cashSales);
    _amount(builder, 'Ingresos', cut.inflows);
    _amount(builder, 'Egresos', cut.outflows);

    builder.separator();
    _amount(builder, 'TOTAL ESPERADO', cut.expectedTotal, bold: true);
    _amount(builder, 'Efectivo contado', cut.countedTotal);
    _amount(builder, 'DIFERENCIA', cut.difference, bold: true);
    builder
      ..separator()
      ..text('COBROS POR METODO');

    for (final entry in cut.paymentBreakdown) {
      _amount(builder, entry.key, entry.value);
    }

    if (cut.movements.isNotEmpty) {
      builder
        ..separator()
        ..text('MOVIMIENTOS');

      for (final movement in cut.movements) {
        builder.text(movementLine(cut, movement));
      }
    }

    if (cut.bankAccounts.isNotEmpty) {
      builder
        ..separator()
        ..text('BANCOS');

      for (final account in cut.bankAccounts) {
        builder
          ..text(account.label)
          ..leftRight('  Saldo inicial', Money.format(account.initialBalance))
          ..leftRight('  Recibido', Money.format(account.received))
          ..leftRight('  Gastado', Money.format(account.spent))
          ..leftRight(
            '  Transferido',
            Money.format(account.transferredIn - account.transferredOut),
          )
          ..leftRight('  Saldo final', Money.format(account.finalBalance));
      }
    }

    builder
      ..separator()
      ..text('Ventas: ${cut.transactionsCount}   Cobros: ${cut.paymentsCount}')
      ..align(EscPosAlign.center)
      ..text('EzyVentas')
      ..feed(3)
      ..cut();

    return builder.build();
  }

  /// Texto plano del mismo ticket (previsualización y copiado).
  static String text(CashCutDocument cut, {int charactersPerLine = 48}) {
    final rows = _TextRowBuilder(charactersPerLine);
    final lines = <String>[
      'CORTE DE CAJA',
      cut.businessName,
      'Sucursal: ${cut.branchName}',
      'Terminal: ${cut.terminalName}',
      'Abrió: ${cut.openerName}',
      usersLine(cut),
      'Turno: ${cut.periodLabel}',
      rows.separator(),
      rows.row('Fondo inicial', Money.format(cut.openingCash)),
      rows.row('Ventas en efectivo', Money.format(cut.cashSales)),
      rows.row('Ingresos', Money.format(cut.inflows)),
      rows.row('Egresos', Money.format(cut.outflows)),
      rows.separator(),
      rows.row('TOTAL ESPERADO', Money.format(cut.expectedTotal)),
      rows.row('Efectivo contado', Money.format(cut.countedTotal)),
      rows.row('DIFERENCIA', Money.format(cut.difference)),
      rows.separator(),
      'COBROS POR METODO',
      for (final entry in cut.paymentBreakdown)
        rows.row(entry.key, Money.format(entry.value)),
    ];

    if (cut.movements.isNotEmpty) {
      lines
        ..add(rows.separator())
        ..add('MOVIMIENTOS')
        ..addAll(
          cut.movements.map((movement) => movementLine(cut, movement)),
        );
    }

    if (cut.bankAccounts.isNotEmpty) {
      lines
        ..add(rows.separator())
        ..add('BANCOS');

      for (final account in cut.bankAccounts) {
        lines
          ..add(account.label)
          ..add(
            rows.row('  Saldo inicial', Money.format(account.initialBalance)),
          )
          ..add(rows.row('  Recibido', Money.format(account.received)))
          ..add(rows.row('  Gastado', Money.format(account.spent)))
          ..add(
            rows.row(
              '  Transferido',
              Money.format(account.transferredIn - account.transferredOut),
            ),
          )
          ..add(rows.row('  Saldo final', Money.format(account.finalBalance)));
      }
    }

    lines
      ..add(rows.separator())
      ..add('Ventas: ${cut.transactionsCount}   Cobros: ${cut.paymentsCount}');

    return lines.join('\n');
  }

  /// `3 usuarios en el turno` (el cierre avisa cuando hay más de uno).
  static String usersLine(CashCutDocument cut) => cut.usersCount > 1
      ? 'Usuarios en el turno: ${cut.usersCount}'
      : 'Usuario único en el turno';

  /// `Ingreso · $100.00 · Fondo extra · María López`.
  static String movementLine(CashCutDocument cut, CashMovement movement) => <String>[
    movement.label,
    Money.format(movement.amount),
    if ((movement.description ?? '').trim().isNotEmpty)
      movement.description!.trim(),
    if (movement.user != null) movement.user!.name,
  ].join(' · ');

  static void _amount(
    EscPosBuilder builder,
    String label,
    double amount, {
    bool bold = false,
  }) {
    builder
      ..bold(enabled: bold)
      ..leftRight(label, Money.format(amount))
      ..bold(enabled: false);
  }
}

/// Alineación en texto plano (espejo del builder ESC/POS para previsualizar).
class _TextRowBuilder {
  _TextRowBuilder(this.charactersPerLine);

  final int charactersPerLine;

  String row(String label, String value) {
    final space = charactersPerLine - label.length - value.length;

    return space < 1 ? '$label $value' : '$label${' ' * space}$value';
  }

  String separator() => List<String>.filled(charactersPerLine, '-').join();
}

