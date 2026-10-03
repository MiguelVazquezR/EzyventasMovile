import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../application/account_providers.dart';
import '../application/subscription_controller.dart';
import 'account_labels.dart';
import 'widgets/account_branch_card.dart';
import 'widgets/account_menu_card.dart';
import 'widgets/account_modules_card.dart';
import 'widgets/account_preferences_card.dart';
import 'widgets/account_profile_card.dart';
import 'widgets/logout_confirmation_dialog.dart';

/// Pestaña "Cuenta": equivalente móvil del menú de usuario del topbar web (§9b).
///
/// Perfil, sucursal, suscripción (solo propietario), notificaciones, soporte,
/// preferencias y cierre de sesión. Cada opción se muestra según lo que el
/// servidor autoriza: la app nunca asume roles ni permisos.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authControllerProvider);
    final accessContext = state.context;
    final user = state.user;

    if (accessContext == null || user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final permissions = ref.watch(permissionsProvider);
    final notificationTotal = ref.watch(notificationsTotalProvider);
    final canSwitchBranch = permissions.can('system.branches.switch');
    final isOwner = user.isSubscriptionOwner;

    // El estado de la suscripción solo lo puede leer el propietario; para el
    // resto de la plantilla el servidor responde 403 y no se consulta.
    final subscriptionWarning = isOwner
        ? ref.watch(subscriptionProvider).value?.statusData.warning
        : null;
    final subscriptionBadge = subscriptionWarning == null
        ? null
        : AccountLabels.subscriptionExpiringBadge;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const AppScreenHeader(
              title: AccountLabels.title,
              subtitle: AccountLabels.subtitle,
              showBranchChip: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: <Widget>[
                  if (subscriptionWarning != null) ...<Widget>[
                    NoticeBanner(
                      message: subscriptionWarning,
                      tone: EzySeverity.warn,
                      actionLabel: AccountLabels.subscription,
                      onAction: () => context.push(subscriptionPath),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AccountProfileCard(
                    user: user,
                    businessName: accessContext.businessName,
                  ),
                  const SizedBox(height: 12),
                  AccountBranchCard(
                    branchName:
                        accessContext.currentBranch?.label ??
                        user.branch?.name ??
                        '—',
                    branchCount: accessContext.availableBranches.length,
                    canSwitchBranch: canSwitchBranch,
                    onChangeBranch: () => context.push(branchSwitchPath),
                  ),
                  const SizedBox(height: 12),
                  AccountMenuCard(
                    isOwner: isOwner,
                    notificationTotal: notificationTotal,
                    subscriptionBadge: subscriptionBadge,
                    onProfile: () => context.push(profilePath),
                    onSubscription: () => context.push(subscriptionPath),
                    onNotifications: () => context.push(notificationsPath),
                    onSupport: () => context.push(supportPath),
                  ),
                  const SizedBox(height: 12),
                  AccountModulesCard(modules: accessContext.modules),
                  const SizedBox(height: 12),
                  const AccountPreferencesCard(),
                  const SizedBox(height: 16),
                  EzyButton(
                    label: AccountLabels.logout,
                    icon: Icons.logout,
                    variant: EzyButtonVariant.danger,
                    isLoading: state.isSubmitting,
                    onPressed: () => confirmLogoutAndExit(context, ref),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AccountLabels.appVersion,
                    textAlign: TextAlign.center,
                    style: EzyTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: context.surfaces.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
