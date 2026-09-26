import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/ezy_chip.dart';
import '../../../core/widgets/ezy_list_tile.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';
import '../application/account_providers.dart';
import '../application/subscription_controller.dart';
import 'account_labels.dart';
import 'logout_flow.dart';

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
    final subscriptionWarning = isOwner ? _subscriptionWarning(ref) : null;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const AppScreenHeader(
              title: AccountLabels.title,
              showBranchChip: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
                  _ProfileCard(
                    user: user,
                    businessName: accessContext.businessName,
                  ),
                  const SizedBox(height: 12),
                  _BranchCard(
                    canSwitchBranch: canSwitchBranch,
                    branchName:
                        accessContext.currentBranch?.label ??
                        user.branch?.name ??
                        '—',
                    branchCount: accessContext.availableBranches.length,
                    onChangeBranch: () => context.push(branchSwitchPath),
                  ),
                  const SizedBox(height: 20),
                  _Menu(isOwner: isOwner, notificationTotal: notificationTotal),
                  const SizedBox(height: 20),
                  _ModulesCard(modules: accessContext.modules),
                  const SizedBox(height: 12),
                  const _PreferencesCard(),
                  const SizedBox(height: 20),
                  EzyButton(
                    label: AccountLabels.logout,
                    icon: Icons.logout,
                    variant: EzyButtonVariant.danger,
                    isLoading: state.isSubmitting,
                    onPressed: () => _confirmLogout(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// `status_data.warning` del servidor (suscripción por vencer o expirada).
  String? _subscriptionWarning(WidgetRef ref) =>
      ref.watch(subscriptionProvider).value?.statusData.warning;

  /// Confirmación + cierre de sesión: el mismo recorrido que el menú lateral.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) =>
      confirmAndLogout(context, ref);
}

/// Opciones del menú de cuenta (§14.2).
///
/// Las filas son las del design system (`EzyListTile` sobre un panel) con los
/// divisores de 1 px que marca el sistema: antes esta pantalla tenía su propio
/// `AccountTile`/`AccountMenuCard`.
class _Menu extends StatelessWidget {
  const _Menu({required this.isOwner, required this.notificationTotal});

  final bool isOwner;
  final int notificationTotal;

  @override
  Widget build(BuildContext context) {
    final rows =
        <
          ({
            IconData icon,
            String title,
            String subtitle,
            int? badge,
            String route,
          })
        >[
          (
            icon: Icons.person_outline,
            title: AccountLabels.profile,
            subtitle: AccountLabels.profileSubtitle,
            badge: null,
            route: profilePath,
          ),
          if (isOwner)
            (
              icon: Icons.workspace_premium_outlined,
              title: AccountLabels.subscription,
              subtitle: AccountLabels.subscriptionSubtitle,
              badge: null,
              route: subscriptionPath,
            ),
          (
            icon: Icons.notifications_none,
            title: AccountLabels.notifications,
            subtitle: AccountLabels.notificationsEmptySubtitle,
            badge: notificationTotal,
            route: notificationsPath,
          ),
          (
            icon: Icons.support_agent_outlined,
            title: AccountLabels.support,
            subtitle: AccountLabels.supportSubtitle,
            badge: null,
            route: supportPath,
          ),
        ];

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++)
            EzyListTile(
              icon: rows[i].icon,
              title: rows[i].title,
              subtitle: rows[i].subtitle,
              badgeCount: rows[i].badge,
              showDivider: i < rows.length - 1,
              onTap: () => context.push(rows[i].route),
            ),
        ],
      ),
    );
  }
}

/// Encabezado con foto, nombre, correo y etiquetas del usuario.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.businessName});

  final AuthUser user;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              UserAvatar(
                name: user.name,
                photoUrl: user.profilePhotoUrl,
                size: 56,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.name,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        fontSize: 18,
                        color: surfaces.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: EzyTextStyles.secondary.copyWith(
                        color: surfaces.textSecondary,
                      ),
                    ),
                    if (user.phone != null &&
                        user.phone!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        user.phone!,
                        style: EzyTextStyles.secondary.copyWith(
                          color: surfaces.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              EzyChip(label: businessName, inner: true),
              if (user.isSubscriptionOwner)
                const EzyChip(
                  label: 'Propietario de la suscripción',
                  inner: true,
                ),
              if (!user.isEmailVerified)
                const EzyChip(
                  label: 'Correo sin verificar',
                  inner: true,
                  tone: EzySeverity.warn,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sucursal activa con la acción de cambio (§9b.1).
class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.canSwitchBranch,
    required this.branchName,
    required this.branchCount,
    required this.onChangeBranch,
  });

  final bool canSwitchBranch;
  final String branchName;
  final int branchCount;
  final VoidCallback onChangeBranch;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final canChange = canSwitchBranch && branchCount > 1;

    return SectionCard(
      title: AccountLabels.branch,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            branchName,
            style: EzyTextStyles.bodyStrong.copyWith(
              fontSize: 18,
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            canChange
                ? 'Tu negocio tiene $branchCount sucursales.'
                : (branchCount > 1
                      ? AccountLabels.noBranchPermission
                      : AccountLabels.singleBranch),
            style: EzyTextStyles.caption.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          if (canChange) ...<Widget>[
            const SizedBox(height: 14),
            EzyButton(
              label: AccountLabels.changeBranch,
              icon: Icons.swap_horiz,
              variant: EzyButtonVariant.outline,
              onPressed: onChangeBranch,
            ),
          ],
        ],
      ),
    );
  }
}

/// Módulos contratados por el negocio (`modules` del contexto).
class _ModulesCard extends StatelessWidget {
  const _ModulesCard({required this.modules});

  final List<String> modules;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: AccountLabels.modules,
      child: modules.isEmpty
          ? const NoticeBanner(
              message: 'Tu suscripción no tiene módulos activos.',
              tone: EzySeverity.warn,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final module in modules)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: EzyColors.success,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            module,
                            style: EzyTextStyles.body.copyWith(
                              color: surfaces.textBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Preferencias locales del dispositivo (modo oscuro).
class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    // Fila propia en lugar de `SwitchListTile`: el panel ya pinta su fondo y
    // `ListTile` exige un `Material` intermedio para el toque.
    return SectionCard(
      title: AccountLabels.preferences,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AccountLabels.darkMode,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    color: surfaces.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AccountLabels.darkModeSubtitle,
                  style: EzyTextStyles.secondary.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isDark,
            onChanged: (value) => ref
                .read(themeModeProvider.notifier)
                .setMode(value ? ThemeMode.dark : ThemeMode.light),
          ),
        ],
      ),
    );
  }
}
