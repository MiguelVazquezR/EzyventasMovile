import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Opción seleccionable del design system (§10, §12).
///
/// La usan el detalle de producto (variantes) y el cobro (clientes): antes cada
/// pantalla copiaba el mismo contenedor de radio 16, el mismo borde y el mismo
/// tinte azul del seleccionado. Con el check a la izquierda la selección no
/// depende solo del color.
///
/// Con [compact] la fila se pinta sin contenedor, para opciones anidadas dentro
/// de otra tarjeta seleccionable (los métodos de reembolso de la anulación).
class EzySelectableTile extends StatelessWidget {
  const EzySelectableTile({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
    this.caption,
    this.captionColor,
    this.value,
    this.trailing,
    this.child,
    this.accent,
    this.compact = false,
    this.fillColor,
    this.boxShadow,
  });

  final String title;

  /// Segunda línea: stock de la variante o teléfono del cliente.
  final String? subtitle;
  final Color? subtitleColor;

  /// Tercera línea de apoyo (saldo y crédito del cliente).
  final String? caption;
  final Color? captionColor;

  /// Dato numérico a la derecha en cifras tabulares (precio de la variante).
  final String? value;

  /// Contenido a la derecha de [value]: el badge de estado de la tarjeta
  /// («REEMBOLSO» / «RETENCIÓN» en la anulación).
  final Widget? trailing;

  /// Contenido extra bajo las líneas: las opciones del reembolso o la cuenta
  /// destino que aparecen al elegir la tarjeta.
  final Widget? child;

  /// Color de la selección; por defecto el naranja de marca. La opción
  /// destructiva de una anulación usa el rojo del sistema.
  final Color? accent;

  /// Fila compacta (32 px) sin contenedor ni margen: para opciones anidadas.
  final bool compact;

  /// Relleno del contenedor cuando la fila **no** está seleccionada. Sin él manda
  /// `panelInner`; sobre un lienzo gris (la hoja del cliente) se pasa `panel` para
  /// que la opción se lea como una sección blanca.
  final Color? fillColor;

  /// Sombra del contenedor: la de las piezas que flotan sobre un lienzo
  /// (`EzyColors.cardShadow`). La selección no la cambia.
  final List<BoxShadow>? boxShadow;

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = accent ?? EzyColors.primary;

    // En compacto el icono va siempre (marcado o no) para que el texto no se
    // desplace al cambiar de opción; el relleno lo pinta el color de marca.
    final leading = Icon(
      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
      size: compact ? 18 : 20,
      color: isSelected ? color : surfaces.textMuted,
    );

    final row = Row(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        if (isSelected || compact) ...<Widget>[
          leading,
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: compact && !isSelected
                      ? surfaces.textSecondary
                      : surfaces.textPrimary,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: EzyTextStyles.secondary.copyWith(
                    color: subtitleColor ?? surfaces.textSecondary,
                  ),
                ),
              ],
              if (caption != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  caption!,
                  style: EzyTextStyles.caption.copyWith(
                    color: captionColor ?? surfaces.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (value != null) ...<Widget>[
          const SizedBox(width: 12),
          Text(
            value!,
            style: EzyTextStyles.moneyList.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
        ],
        if (trailing != null) ...<Widget>[const SizedBox(width: 12), trailing!],
      ],
    );

    if (compact) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: row,
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : (fillColor ?? surfaces.panelInner),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : surfaces.border,
          ),
          boxShadow: boxShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            row,
            if (child != null) ...<Widget>[const SizedBox(height: 12), child!],
          ],
        ),
      ),
    );
  }
}
