import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Micro-etiqueta de campo: 10 px, MAYÚSCULAS, tracking alto (§3).
///
/// Va **fuera** del input (nunca `floatingLabel`), como en la web.
///
/// [trailing] comparte la fila con la etiqueta por la derecha: el contador
/// `0/255` de un campo con tope de caracteres o el aviso `MÁX. 20`. Sin él la
/// fila se colapsa al `Text` de siempre, así que las pantallas que ya la usan no
/// cambian de layout. [requiredMarkColor] pinta el `*` de obligatorio con el
/// color que pida la pantalla (las hojas del POS lo marcaban en gris; el
/// rediseño lo quiere en rojo de peligro).
class FieldLabel extends StatelessWidget {
  const FieldLabel(
    this.text, {
    super.key,
    this.isRequired = false,
    this.color,
    this.trailing,
    this.requiredMarkColor,
  });

  final String text;
  final bool isRequired;
  final Color? color;

  /// Contenido alineado a la derecha de la etiqueta (contador, ayuda corta).
  final Widget? trailing;

  /// Color del `*`; sin él hereda el tono de la etiqueta.
  final Color? requiredMarkColor;

  @override
  Widget build(BuildContext context) {
    final markColor = requiredMarkColor;
    final style = EzyTextStyles.microLabel.copyWith(
      color: color ?? context.surfaces.textMuted,
    );

    final label = Text.rich(
      TextSpan(
        text: text.toUpperCase(),
        children: <InlineSpan>[
          if (isRequired)
            TextSpan(
              text: ' *',
              style: markColor == null ? null : TextStyle(color: markColor),
            ),
        ],
      ),
      style: style,
    );

    final trailing = this.trailing;
    if (trailing == null) {
      return label;
    }

    return Row(
      children: <Widget>[
        Expanded(child: label),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}
