import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/ezy_dialog.dart';
import '../../auth/application/auth_controller.dart';
import '../../account/application/account_providers.dart';
import 'account_labels.dart';

/// Cierre de sesión con confirmación (menú lateral y pestaña Cuenta).
///
/// Lo comparten el menú lateral y la pestaña Cuenta para que el texto aprobado y
/// la limpieza de la caché local —los contadores de notificaciones— sean los
/// mismos en los dos caminos: un usuario que sale desde el menú no puede quedar
/// con los avisos del anterior.
Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showEzyConfirmDialog(
    context,
    title: AccountLabels.logoutTitle,
    message: AccountLabels.logoutMessage,
    confirmLabel: AccountLabels.logout,
    isDestructive: true,
  );

  if (!confirmed) {
    return;
  }

  await ref.read(notificationsControllerProvider.notifier).clear();
  await ref.read(authControllerProvider.notifier).logout();
}
