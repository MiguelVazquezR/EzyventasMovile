import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Card / panel del design system: radio 24, borde de 1 px, `elevation: 0`.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
    this.inner = false,
  });

  final Widget child;

  /// Título en micro-mayúsculas (`ANTICIPOS Y PAGOS`).
  final String? title;

  /// Acción a la derecha del título.
  final Widget? trailing;

  final EdgeInsetsGeometry padding;

  /// `true` para cards internas (fondo `panelInner`, radio 16).
  final bool inner;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final hasHeader = title != null || trailing != null;

    return Container(
      decoration: BoxDecoration(
        color: inner ? surfaces.panelInner : surfaces.panel,
        borderRadius: BorderRadius.circular(inner ? 16 : 24),
        border: Border.all(color: surfaces.border),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasHeader) ...<Widget>[
            Row(
              children: <Widget>[
                if (title != null)
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: EzyTextStyles.cardTitle.copyWith(
                        color: surfaces.textBody,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// Fila etiqueta-valor usada en resúmenes y cortes de caja.
class SectionRow extends StatelessWidget {
  const SectionRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.valueStyle,
  });

  final String label;
  final String value;

  /// Fila destacada: etiqueta en el tono alto y monto grande.
  final bool emphasized;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: emphasized
                  ? EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    )
                  : EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style:
                  valueStyle ??
                  (emphasized
                      ? EzyTextStyles.moneyMedium.copyWith(
                          color: surfaces.textPrimary,
                        )
                      : EzyTextStyles.moneyList.copyWith(
                          color: surfaces.textPrimary,
                        )),
            ),
          ),
        ],
      ),
    );
  }
}
