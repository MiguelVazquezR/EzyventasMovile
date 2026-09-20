import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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
    this.actions = const <Widget>[],
    this.onRefresh,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  /// Si se pasa, la pantalla se puede refrescar deslizando hacia abajo.
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final content = onRefresh == null
        ? body
        : RefreshIndicator(onRefresh: onRefresh!, child: body);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: AccountLabels.back,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: surfaces.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      style: EzyTextStyles.screenTitle.copyWith(
                        color: surfaces.textPrimary,
                      ),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}
