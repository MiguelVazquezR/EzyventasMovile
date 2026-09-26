import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Hoja inferior estándar de la app (§23.16).
///
/// Envuelve `showModalBottomSheet` para que **todas** las hojas cumplan las
/// mismas reglas: `isScrollControlled: true`, `useSafeArea: true`, alto máximo
/// acotado, teclado respetado (`viewInsets`) y, si se pasa [title], la misma
/// cabecera. El `footer` opcional se ancla al pie (fuera del scroll) para que el
/// CTA siga a la vista en las hojas largas. Así ninguna hoja vuelve a quedarse
/// sin las banderas.
class EzyBottomSheet {
  const EzyBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    Widget? child,
    Widget Function(BuildContext sheetContext)? builder,
    String? title,
    String? subtitle,
    Widget? trailing,
    Widget? footer,
    double maxHeightFactor = 0.9,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    assert(
      child != null || builder != null,
      'EzyBottomSheet.show necesita `child` o `builder`.',
    );

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      builder: (sheetContext) {
        final media = MediaQuery.of(sheetContext);
        final content = builder?.call(sheetContext) ?? child!;

        return Padding(
          // El teclado empuja la hoja: sin esto el campo activo queda tapado.
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          // El alto máximo se acota con las restricciones de LAYOUT de la hoja
          // (no con `MediaQuery.size`, que en las pruebas no refleja la
          // superficie): así la hoja sigue siendo "el 90 % de la pantalla" en
          // el teléfono y se puede medir en las pruebas.
          child: LayoutBuilder(
            builder: (context, constraints) => ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * maxHeightFactor,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (title != null)
                    EzySheetHeader(
                      title: title,
                      subtitle: subtitle,
                      trailing: trailing,
                    ),
                  Flexible(child: content),
                  // El pie se queda fijo: el CTA de una hoja larga (§7.6) no
                  // puede depender de haber bajado hasta el final. Con pie, el
                  // área segura la resuelve él mismo (`EzyActionBar`).
                  if (footer == null)
                    SizedBox(height: media.viewPadding.bottom),
                  ?footer,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Cabecera de hoja: título `h1` reducido, subtítulo opcional y acción a la
/// derecha. El asa de arrastre la pinta el tema (`showDragHandle`).
class EzySheetHeader extends StatelessWidget {
  const EzySheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 16),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: EzyTextStyles.screenTitle.copyWith(
                    fontSize: 20,
                    color: surfaces.textPrimary,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: EzyTextStyles.secondary.copyWith(
                      color: surfaces.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Botonera al pie de una hoja: acciones repartidas a lo ancho.
class EzySheetActions extends StatelessWidget {
  const EzySheetActions({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 8),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: children.length == 1
          ? children.first
          : Row(
              children: <Widget>[
                for (int i = 0; i < children.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: children[i]),
                ],
              ],
            ),
    );
  }
}
