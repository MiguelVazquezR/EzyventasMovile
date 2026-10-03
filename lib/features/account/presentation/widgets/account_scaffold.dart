import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../account_labels.dart';

/// Pantalla completa de la sección Cuenta: título `h1` con botón "Regresar".
///
/// Mismo patrón que las pantallas de formulario del resto de la app (SafeArea +
/// título sin margen), sin `AppBar` de Material.
class AccountScaffold extends StatelessWidget {
  const AccountScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions = const <Widget>[],
    this.onRefresh,
    this.compact = false,
  });

  final String title;

  /// Línea de apoyo bajo el título; opcional.
  final String? subtitle;

  final Widget body;
  final List<Widget> actions;

  /// Si se pasa, la pantalla se puede refrescar deslizando hacia abajo.
  final Future<void> Function()? onRefresh;

  /// Cabecera densa del rediseño: título 17 px `w900`, botón "Regresar" de 36 px
  /// y línea divisoria bajo la cabecera. Las pantallas que no lo piden conservan
  /// el `h1` de 24 px del design system.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final content = onRefresh == null
        ? body
        : RefreshIndicator(onRefresh: onRefresh!, child: body);
    final titleStyle = compact
        ? EzyTextStyles.bodyStrong.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: surfaces.textPrimary,
          )
        : EzyTextStyles.screenTitle.copyWith(color: surfaces.textPrimary);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: <Widget>[
          EzyIconButton(
            icon: Icons.arrow_back,
            tooltip: AccountLabels.back,
            size: compact ? 36 : 44,
            iconSize: compact ? 18 : 20,
            onTap: () => Navigator.of(context).pop(),
          ),
          if (compact) const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(title, style: titleStyle),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: EzyTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: surfaces.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            if (compact)
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: surfaces.border)),
                ),
                child: header,
              )
            else
              header,
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
