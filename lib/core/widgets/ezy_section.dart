import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Sección del design system: cabecera en micro-mayúsculas, contenido sobre el
/// panel y divisores de 1 px en lugar de tarjetas anidadas (§13, §15, §17).
///
/// Con [collapsible] la cabecera pliega el contenido (flecha giratoria), útil en
/// fichas largas como el detalle de una venta o de una orden.
class EzySection extends StatefulWidget {
  const EzySection({
    super.key,
    this.title,
    this.trailing,
    this.children = const <Widget>[],
    this.child,
    this.initiallyExpanded = true,
    this.collapsible = true,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  /// Título en MAYÚSCULAS pequeñas (`ANTICIPOS Y PAGOS`).
  final String? title;

  /// Acción a la derecha del título (contador, botón).
  final Widget? trailing;

  /// Filas de la sección: se separan solas con divisores de 1 px.
  final List<Widget> children;

  /// Contenido libre; alternativa a [children].
  final Widget? child;

  final bool initiallyExpanded;

  /// Plegable (solo aplica si hay [title]).
  final bool collapsible;
  final EdgeInsetsGeometry padding;

  @override
  State<EzySection> createState() => _EzySectionState();
}

class _EzySectionState extends State<EzySection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final canCollapse = widget.collapsible && widget.title != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.title != null)
          GestureDetector(
            onTap: canCollapse
                ? () => setState(() => _expanded = !_expanded)
                : null,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title!.toUpperCase(),
                      style: EzyTextStyles.cardTitle.copyWith(
                        color: surfaces.textBody,
                      ),
                    ),
                  ),
                  if (widget.trailing != null) ...<Widget>[
                    const SizedBox(width: 8),
                    widget.trailing!,
                  ],
                  if (canCollapse) ...<Widget>[
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0 : -0.25,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.expand_more,
                        size: 20,
                        color: surfaces.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          sizeCurve: Curves.easeOut,
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: _body(surfaces),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _body(EzySurfaces surfaces) {
    final content =
        widget.child ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < widget.children.length; i++) ...<Widget>[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: surfaces.border),
              widget.children[i],
            ],
          ],
        );

    return Padding(padding: widget.padding, child: content);
  }
}
