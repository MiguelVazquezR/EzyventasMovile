import '../../../../core/utils/json_reader.dart';
import 'models/cash_cut_document.dart';

/// Convierte el ticket del servidor en el texto que se envía por WhatsApp.
///
/// Réplica de `resources/js/Composables/useWhatsAppTicket.js`: la web y la app
/// mandan **exactamente el mismo mensaje**. Los montos llegan ya formateados
/// (`"$270.00 MXN"`), así que aquí solo se concatenan: nunca se reformatean.
///
/// Variantes de `kind` (las arma `WhatsAppTicketService`): `sale` (venta o
/// apartado), `abono` (abono a una venta), `order` (pedido) y `order_payment`
/// (abono a un pedido).
class WhatsAppMessageBuilder {
  const WhatsAppMessageBuilder._();

  /// Longitud máxima de la descripción para que el bloque quede alineado.
  static const int _maxDescriptionLength = 24;

  static String build(Map<String, dynamic> ticket) {
    return switch (JsonReader.stringOr(ticket['kind'], 'sale')) {
      'abono' => abono(ticket),
      'order' => order(ticket),
      'order_payment' => orderPayment(ticket),
      _ => sale(ticket),
    };
  }

  /// Ticket de venta, crédito o apartado.
  static String sale(Map<String, dynamic> ticket) {
    final saleType = JsonReader.stringOr(ticket['saleType'], '');
    final total = _text(ticket['total']);
    final totalPaid = _text(ticket['totalPaid']);
    final remainingDue = _text(ticket['remainingDue']);
    final expirationDate = _text(ticket['expirationDate']);
    final paymentMethod = _text(ticket['paymentMethod']);
    final address = _text(ticket['address']);
    final finalMessage =
        _text(ticket['finalMessage']) ?? '¡Gracias por tu compra!';

    final lines = <String>[
      '» *${_text(ticket['title']) ?? 'TICKET DE VENTA'}* «',
      '• *${_text(ticket['businessName']) ?? ''}*',
    ];

    final saleTypeLabel = _text(ticket['saleTypeLabel']);

    if (saleTypeLabel != null) {
      lines.add('• Tipo de venta: *$saleTypeLabel*');
    }

    lines.addAll(<String>[
      '• Fecha: *${_text(ticket['date']) ?? ''}*',
      '• Folio: *${_text(ticket['folio']) ?? ''}*',
      '• Cliente: *${_text(ticket['customer']) ?? ''}*',
      '',
      '» *Detalle de compra* «',
      '```',
      _itemsBlock(ticket['items']),
      '```',
    ]);

    if (total != null) {
      lines.add('• Total de venta: *$total*');
    }

    if (totalPaid != null) {
      final paidLabel =
          saleType == 'credito' || saleType == 'apartado' ? 'Abono' : 'Pagado';
      lines.add('• $paidLabel: *$totalPaid*');
    }

    if (remainingDue != null) {
      lines.add('• Restante a pagar: *$remainingDue*');
    }

    if (expirationDate != null) {
      lines.add('• Vencimiento: *$expirationDate*');
    }

    if (paymentMethod != null) {
      lines.add('• Método de pago: *$paymentMethod*');
    }

    if (address != null) {
      lines.add('• Dirección: *$address*');
    }

    lines.addAll(<String>[
      '',
      '» ${_closing(finalMessage, remainingDue, expirationDate)} «',
    ]);

    return lines.join('\n');
  }

  /// Cierre del ticket: añade el recordatorio del saldo pendiente.
  static String _closing(
    String finalMessage,
    String? remainingDue,
    String? expirationDate,
  ) {
    if (remainingDue == null) {
      return finalMessage;
    }

    return expirationDate != null
        ? '$finalMessage Recuerda liquidar tu saldo antes del $expirationDate.'
        : '$finalMessage Queda un saldo pendiente de $remainingDue.';
  }

  static String? _text(Object? value) {
    final text = JsonReader.string(value)?.trim();

    return text == null || text.isEmpty ? null : text;
  }

  /// Ticket de pedido por entregar.
  static String order(Map<String, dynamic> ticket) {
    final lines = <String>[
      '» *TICKET DE PEDIDO* «',
      '• *${_text(ticket['businessName']) ?? ''}*',
      '• Estado del pedido: *${_text(ticket['statusLabel']) ?? ''}*',
      '• Fecha: *${_text(ticket['date']) ?? ''}*',
      '• Folio: *${_text(ticket['folio']) ?? ''}*',
      '• Cliente: *${_text(ticket['customer']) ?? ''}*',
      '',
      '» *Detalle del pedido* «',
      '```',
      _itemsBlock(ticket['items']),
      '```',
      '• Subtotal: *${_text(ticket['subtotal']) ?? ''}*',
      '• Envío: *${_text(ticket['shippingCost']) ?? ''}*',
      '• Total del pedido: *${_text(ticket['total']) ?? ''}*',
    ];

    final totalPaid = _text(ticket['totalPaid']);
    final paymentMethod = _text(ticket['paymentMethod']);
    final remainingDue = _text(ticket['remainingDue']);

    if (totalPaid != null) {
      lines.add('• Monto pagado: *$totalPaid*');
    }

    if (paymentMethod != null) {
      lines.add('• Método de pago: *$paymentMethod*');
    }

    if (remainingDue != null) {
      lines.add('• Restante a pagar: *$remainingDue*');
    }

    lines.addAll(<String>[
      '',
      '» ${_text(ticket['finalMessage']) ?? '¡Gracias por tu pedido!'} «',
    ]);

    return lines.join('\n');
  }

  /// Ticket de abono a una venta (`scope: transaction`) o a la cuenta del
  /// cliente (`scope: general`).
  static String abono(Map<String, dynamic> ticket) {
    final lines = <String>[
      '» *TICKET DE ABONO* «',
      '• *${_text(ticket['businessName']) ?? ''}*',
      '• Tipo de venta: *Abono*',
      '• Fecha: *${_text(ticket['date']) ?? ''}*',
      '• Cliente: *${_text(ticket['customer']) ?? ''}*',
      '',
      '» *Detalle del abono* «',
    ];

    final folio = _text(ticket['folio']);
    final paymentMethod = _text(ticket['paymentMethod']);
    final liquidated = JsonReader.boolean(ticket['liquidated']);

    if (folio != null) {
      final saleTotal = _text(ticket['saleTotal']) ?? _text(ticket['total']);
      final previousDue = _text(ticket['previousDue']);
      final abonado = _text(ticket['abonado']);
      final remainingDue = _text(ticket['remainingDue']);
      final expirationDate = _text(ticket['expirationDate']);

      lines.add('• Folio de venta: *$folio*');

      if (saleTotal != null) {
        lines.add('• Total de la venta: *$saleTotal*');
      }

      if (previousDue != null) {
        lines.add('• Monto anterior: *$previousDue*');
      }

      if (abonado != null) {
        lines.add('• Abonado: *$abonado*');
      }

      if (remainingDue != null) {
        lines.add('• Restante a pagar: *$remainingDue*');
      }

      if (paymentMethod != null) {
        lines.add('• Método de pago: *$paymentMethod*');
      }

      if (!liquidated && expirationDate != null) {
        lines.add('• Vencimiento: *$expirationDate*');
      }
    } else {
      final totalAbonado = _text(ticket['totalAbonado']);
      final breakdown = JsonReader.toMapList(ticket['breakdown']);
      final liquidatedFolios = JsonReader.stringList(ticket['liquidatedFolios']);
      final totalRemaining = _text(ticket['totalRemaining']);
      final nextExpiration = _text(ticket['nextExpiration']);
      final balanceCredit = _text(ticket['balanceCredit']);

      if (totalAbonado != null) {
        lines.add('• Total abonado: *$totalAbonado*');
      }

      if (paymentMethod != null) {
        lines.add('• Método de pago: *$paymentMethod*');
      }

      if (breakdown.isNotEmpty) {
        lines.addAll(<String>[
          '',
          '» *Aplicado a ventas* «',
          '```',
          ..._abonoBreakdown(breakdown),
          '```',
        ]);
      }

      if (liquidatedFolios.isNotEmpty) {
        lines.add('• Ventas liquidadas: *${liquidatedFolios.join(', ')}*');
      }

      if (totalRemaining != null) {
        lines.add('• Restante total: *$totalRemaining*');
      }

      if (nextExpiration != null) {
        lines.add('• Próximo vencimiento: *$nextExpiration*');
      }

      if (balanceCredit != null) {
        lines.add('• Saldo a favor: *$balanceCredit*');
      }
    }

    final closing = liquidated
        ? '¡Gracias por tu abono! Tu compra quedó liquidada.'
        : '¡Gracias por tu abono!';

    lines.addAll(<String>['', '» $closing «']);

    return lines.join('\n');
  }


  /// Ticket de pago de un pedido (al abonar o liquidarlo).
  static String orderPayment(Map<String, dynamic> ticket) {
    final lines = <String>[
      '» *TICKET DE PEDIDO* «',
      '• *${_text(ticket['businessName']) ?? ''}*',
      '• Estado del pedido: *${_text(ticket['estado']) ?? ''}*',
      '• Fecha: *${_text(ticket['date']) ?? ''}*',
      '• Folio: *${_text(ticket['folio']) ?? ''}*',
      '• Cliente: *${_text(ticket['customer']) ?? ''}*',
      '',
      '» *Detalle del pedido* «',
      '• Total de la venta: *${_text(ticket['total']) ?? ''}*',
    ];

    for (final entry in <MapEntry<String, Object?>>[
      MapEntry<String, Object?>('Monto anterior', ticket['previousDue']),
      MapEntry<String, Object?>('Abonado', ticket['abonado']),
      MapEntry<String, Object?>('Método de pago', ticket['paymentMethod']),
      MapEntry<String, Object?>('Restante a pagar', ticket['remainingDue']),
    ]) {
      final value = _text(entry.value);

      if (value != null) {
        lines.add('• ${entry.key}: *$value*');
      }
    }

    lines.addAll(<String>[
      '',
      '» ${_text(ticket['finalMessage']) ?? '¡Gracias por tu pedido!'} «',
    ]);

    return lines.join('\n');
  }

  /// Texto del **corte de caja** (no hay endpoint de WhatsApp para el corte:
  /// el documento se arma en el dispositivo, contrato §6.3).
  static String cashCut(CashCutDocument cut) {
    final lines = <String>[
      '» *CORTE DE CAJA* «',
      '• *${cut.businessName}*',
      '• Sucursal: *${cut.branchName}*',
      '• Terminal: *${cut.terminalName}*',
      '• Turno: *${cut.periodLabel}*',
      '• Abrió: *${cut.openerName}*',
      '',
      '» *Detalle del turno* «',
      '• Fondo inicial: *${cut.money(cut.openingCash)}*',
      '• Ventas en efectivo: *${cut.money(cut.cashSales)}*',
      '• Ingresos: *${cut.money(cut.inflows)}*',
      '• Egresos: *${cut.money(cut.outflows)}*',
      '• Total esperado: *${cut.money(cut.expectedTotal)}*',
      '',
      '» *Cobros por método* «',
      '```',
      ..._cashCutBreakdown(cut),
      '```',
      '• Efectivo contado: *${cut.money(cut.countedTotal)}*',
      '• Diferencia: *${cut.money(cut.difference)}*',
      '',
      '» ${cut.hasDifference ? 'Revisa el descuadre del turno.' : 'Turno sin diferencia.'} «',
    ];

    return lines.join('\n');
  }

  /// Enlace de WhatsApp con el mensaje codificado.
  ///
  /// Los teléfonos nacionales de 10 dígitos llevan el prefijo de México (52),
  /// igual que la web. Sin teléfono se abre WhatsApp sin destinatario para que
  /// el usuario elija el contacto.
  static String link({required String? phone, required String message}) {
    final clean = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    final withPrefix = clean.length == 10 ? '52$clean' : clean;
    final encoded = Uri.encodeComponent(message);

    return clean.isEmpty
        ? 'https://wa.me/?text=$encoded'
        : 'https://wa.me/$withPrefix?text=$encoded';
  }

  /// Bloque monospace `Cant | Producto | Total` alineado por columnas.
  static String _itemsBlock(Object? rawItems) {
    final items = JsonReader.toMapList(rawItems).map((item) {
      final description = _text(item['descripcion']) ?? '';

      return <String>[
        _text(item['cantidad']) ?? '',
        description.length > _maxDescriptionLength
            ? '${description.substring(0, _maxDescriptionLength - 1)}…'
            : description,
        _text(item['total']) ?? '',
      ];
    }).toList(growable: false);

    if (items.isEmpty) {
      return '';
    }

    final quantityWidth = _maxWidth(items, 0, 4);
    final descriptionWidth = _maxWidth(items, 1, 8);
    final totalWidth = _maxWidth(items, 2, 5);

    final rows = <String>[
      '${'Cant'.padRight(quantityWidth)} '
      '${'Producto'.padRight(descriptionWidth)} '
      '${'Total'.padLeft(totalWidth)}',
    ];

    for (final item in items) {
      rows.add(
        '${item[0].padRight(quantityWidth)} '
        '${item[1].padRight(descriptionWidth)} '
        '${item[2].padLeft(totalWidth)}',
      );
    }

    return rows.join('\n');
  }

  /// Bloque `Venta | Abono | Restante` de un abono general.
  static List<String> _abonoBreakdown(List<Map<String, dynamic>> breakdown) {
    final rows = breakdown
        .map(
          (row) => <String>[
            _text(row['folio']) ?? '',
            _text(row['abonado']) ?? '',
            _text(row['restante']) ?? '',
          ],
        )
        .toList(growable: false);

    final folioWidth = _maxWidth(rows, 0, 5);
    final abonadoWidth = _maxWidth(rows, 1, 5);
    final restanteWidth = _maxWidth(rows, 2, 8);

    return <String>[
      '${'Venta'.padRight(folioWidth)} '
          '${'Abono'.padLeft(abonadoWidth)} '
          '${'Restante'.padLeft(restanteWidth)}',
      for (final row in rows)
        '${row[0].padRight(folioWidth)} '
        '${row[1].padLeft(abonadoWidth)} '
        '${row[2].padLeft(restanteWidth)}',
    ];
  }

  /// Bloques de totales del corte (`Efectivo`, `Tarjeta`, ...).
  static List<String> _cashCutBreakdown(CashCutDocument cut) {
    final labels = cut.paymentBreakdown
        .map((entry) => entry.key)
        .toList(growable: false);
    final amounts = cut.paymentBreakdown
        .map((entry) => cut.money(entry.value))
        .toList(growable: false);
    final labelWidth = _maxWidth(<List<String>>[labels], 0, 8);
    final amountWidth = _maxWidth(<List<String>>[amounts], 0, 6);

    return <String>[
      for (var index = 0; index < labels.length; index++)
        '${labels[index].padRight(labelWidth)} '
            '${amounts[index].padLeft(amountWidth)}',
    ];
  }

  /// Ancho de la columna [index] (mínimo [fallback]).
  static int _maxWidth(List<List<String>> rows, int index, int fallback) {
    var width = fallback;

    for (final row in rows) {
      if (row.length > index && row[index].length > width) {
        width = row[index].length;
      }
    }

    return width;
  }
}

