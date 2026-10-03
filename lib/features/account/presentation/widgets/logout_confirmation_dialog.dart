import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/ezy_dialog.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/account_providers.dart';
import '../account_labels.dart';

/// Diálogo modal de confirmación de cierre de sesión (§3.8).
///
/// Devuelve `true` solo si se confirmó. Al confirmar limpia la caché local de
/// contadores y cierra la sesión, sin duplicar la lógica de negocio.
Future<bool> showLogoutConfirmationDialog(BuildContext context) =>
    showEzyConfirmDialog(
      context,
      title: AccountLabels.logoutConfirmTitle,
      message: AccountLabels.logoutConfirmMessage,
      confirmLabel: AccountLabels.logoutConfirmAction,
      cancelLabel: AccountLabels.cancel,
      isDestructive: true,
    );

/// Confirmación + cierre de sesión desde la pestaña Cuenta.
Future<void> confirmLogoutAndExit(BuildContext context, WidgetRef ref) async {
  final confirmed = await showLogoutConfirmationDialog(context);
  if (!confirmed) {
    return;
  }

  await ref.read(notificationsControllerProvider.notifier).clear();
  await ref.read(authControllerProvider.notifier).logout();
}
