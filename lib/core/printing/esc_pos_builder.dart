import 'dart:typed_data';

import 'cp850.dart';

/// Alineación horizontal de la impresora térmica (`ESC a n`).
enum EscPosAlign { left, center, right }

/// Generador **ESC/POS** local.
///
/// El servidor ya entrega las plantillas de venta y de orden codificadas
/// (`POST /print/bluetooth-payload`); este generador existe para el único
/// documento que la API **no** puede codificar: el **corte de caja** (el
/// contrato §6.3 lo dice explícitamente: `cash_register_session` no es un
/// `data_source_type` válido). Se deja aislado y sin estado compartido para
/// reutilizarlo tal cual cuando se implemente el modo offline (fase 5).
///
/// Comandos usados (Epson ESC/POS estándar, compatibles con las térmicas
/// Bluetooth de 58/80 mm):
/// - `ESC @` inicializar, `ESC t 2` página CP850, `ESC a n` alineación,
///   `ESC E n` negritas, `GS ! n` doble alto/ancho, `GS V 66 0` corte parcial,
///   `ESC p 0 25 250` abrir cajón.
class EscPosBuilder {
  EscPosBuilder({this.charactersPerLine = 48});

  /// Ancho útil en caracteres (48 en 80 mm, 32 en 58 mm).
  final int charactersPerLine;

  final BytesBuilder _out = BytesBuilder();

  /// Ancho de línea efectivo (nunca menor a 16 para no romper el corte).
  int get _width => charactersPerLine < 16 ? 16 : charactersPerLine;

  /// `ESC @`: reinicia la impresora.
  EscPosBuilder initialize() => raw(<int>[0x1B, 0x40]);

  /// `ESC t 2`: página de códigos CP850 (los acentos del castellano).
  EscPosBuilder selectCp850() => raw(<int>[0x1B, 0x74, 0x02]);

  /// `ESC a n`: alineación del texto siguiente.
  EscPosBuilder align(EscPosAlign align) => raw(<int>[
    0x1B,
    0x61,
    switch (align) {
      EscPosAlign.left => 0,
      EscPosAlign.center => 1,
      EscPosAlign.right => 2,
    },
  ]);

  /// `ESC E n`: negritas.
  EscPosBuilder bold({required bool enabled}) =>
      raw(<int>[0x1B, 0x45, enabled ? 1 : 0]);

  /// `GS ! n`: doble alto y ancho (para títulos y montos grandes).
  EscPosBuilder doubleSize({required bool enabled}) =>
      raw(<int>[0x1D, 0x21, enabled ? 0x11 : 0x00]);

  /// `ESC p 0 25 250`: pulso para abrir el cajón de dinero.
  EscPosBuilder openDrawer() => raw(<int>[0x1B, 0x70, 0x00, 0x19, 0xFA]);

  /// `GS V 66 0`: corte parcial (deja el ticket colgando, como la web).
  EscPosBuilder cut() => raw(<int>[0x1D, 0x56, 0x42, 0x00]);

  /// Avanza [lines] líneas en blanco.
  EscPosBuilder feed([int lines = 1]) {
    if (lines <= 0) {
      return this;
    }

    return raw(List<int>.filled(lines, 0x0A));
  }

  /// Escribe [text] (con saltos de línea) codificado en CP850 y ajustado al
  /// ancho de papel.
  EscPosBuilder text(String text) {
    for (final line in text.split('\n')) {
      if (line.isEmpty) {
        raw(<int>[0x0A]);
        continue;
      }

      for (final wrapped in _wrap(line)) {
        raw(Cp850.encode(wrapped));
        raw(<int>[0x0A]);
      }
    }

    return this;
  }

  /// Línea centrada.
  EscPosBuilder centered(String text) =>
      align(EscPosAlign.center).text(text).align(EscPosAlign.left);

  /// Separador de ancho completo (`--------------------------------`).
  EscPosBuilder separator({String character = '-'}) {
    final safe = character.isEmpty ? '-' : character.substring(0, 1);

    return text(List<String>.filled(_width, safe).join());
  }

  /// Etiqueta a la izquierda y valor a la derecha, en la misma línea.
  ///
  /// Si no caben, la etiqueta va en su línea y el valor se alinea a la derecha
  /// del papel (nunca se pierde el monto).
  EscPosBuilder leftRight(String left, String right) {
    final space = _width - left.length - right.length;

    if (space < 1) {
      return text(left).text(_padLeft(right, _width));
    }

    return text('$left${' ' * space}$right');
  }

  /// Renglón de tres columnas del corte: `Cant  Concepto          Monto`.
  EscPosBuilder quantityRow(String quantity, String description, String amount) {
    const quantityWidth = 7;
    final amountWidth = amount.length > _width - quantityWidth - 4
        ? _width - quantityWidth - 4
        : amount.length;
    final descriptionWidth = _width - quantityWidth - amountWidth - 2;

    return text(
      '${_padRight(quantity, quantityWidth)} '
      '${_padRight(_truncate(description, descriptionWidth), descriptionWidth)} '
      '${_padLeft(amount, amountWidth)}',
    );
  }

  /// Escribe bytes crudos (para comandos no cubiertos por los atajos).
  EscPosBuilder raw(List<int> bytes) {
    _out.add(bytes);
    return this;
  }

  /// Bytes finales que se envían a la impresora Bluetooth.
  Uint8List build() => _out.toBytes();

  List<String> _wrap(String line) {
    if (line.length <= _width) {
      return <String>[line];
    }

    final lines = <String>[];
    var remaining = line;

    while (remaining.length > _width) {
      lines.add(remaining.substring(0, _width));
      remaining = remaining.substring(_width);
    }

    lines.add(remaining);

    return lines;
  }

  static String _padRight(String value, int width) =>
      value.length >= width ? _truncate(value, width) : value.padRight(width);

  static String _padLeft(String value, int width) =>
      value.length >= width ? value.substring(value.length - width) : value.padLeft(width);

  static String _truncate(String value, int width) => value.length <= width
      ? value
      : '${value.substring(0, width - 1).trimRight()}…';
}
