import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/auth_user.dart';

/// Pestaña "Cuenta".
///
/// Entrega 1: perfil, sucursal activa, módulos contratados, tema y cierre de
/// sesión. El perfil editable, el cambio de sucursal, las notificaciones, el
/// soporte y la suscripción llegan en la etapa 7.
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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            const AppScreenHeader(title: 'Mi cuenta', showBranchChip: false),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: <Widget>[
                  _ProfileCard(
                    user: user,
                    businessName: accessContext.businessName,
                  ),
                  const SizedBox(height: 12),
                  _BranchCard(
                    businessName: accessContext.businessName,
                    branchName:
                        accessContext.currentBranch?.label ??
                        user.branch?.name ??
                        '—',
                    branchCount: accessContext.availableBranches.length,
                  ),
                  const SizedBox(height: 12),
                  _ModulesCard(modules: accessContext.modules),
                  const SizedBox(height: 12),
                  const _PreferencesCard(),
                  const SizedBox(height: 12),
                  EzyButton(
                    label: 'Cerrar sesión',
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

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Quieres cerrar sesión?'),
        content: const Text(
          'Se cerrará la sesión de este dispositivo. Los demás dispositivos '
          'siguen conectados.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: EzyColors.danger,
              foregroundColor: EzyColors.white,
            ),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}

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
                    if (user.phone != null && user.phone!.isNotEmpty) ...<Widget>[
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
              _MetaChip(label: businessName),
              if (user.isSubscriptionOwner)
                const _MetaChip(label: 'Propietario de la suscripción'),
              if (!user.isEmailVerified)
                const _MetaChip(
                  label: 'Correo sin verificar',
                  tone: EzySeverity.warn,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip neutro para metadatos del perfil.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.tone = EzySeverity.neutral});

  final String label;
  final EzySeverity tone;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isNeutral = tone == EzySeverity.neutral;
    final color = isNeutral
        ? surfaces.textSecondary
        : StatusPalette.text(context, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isNeutral ? surfaces.panelInner : StatusPalette.soft(tone),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isNeutral ? surfaces.border : StatusPalette.border(tone),
        ),
      ),
      child: Text(
        label,
        style: EzyTextStyles.caption.copyWith(color: color),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  const _BranchCard({
    required this.businessName,
    required this.branchName,
    required this.branchCount,
  });

  final String businessName;
  final String branchName;
  final int branchCount;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Sucursal activa',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            businessName,
            style: EzyTextStyles.bodyStrong.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            branchName,
            style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
          ),
          const SizedBox(height: 12),
          NoticeBanner(
            message: branchCount > 1
                ? 'Tu negocio tiene $branchCount sucursales. El cambio de sucursal se habilita en la siguiente entrega de la app.'
                : 'Esta es la única sucursal de tu negocio.',
            tone: EzySeverity.info,
          ),
        ],
      ),
    );
  }
}

class _ModulesCard extends StatelessWidget {
  const _ModulesCard({required this.modules});

  final List<String> modules;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Módulos contratados',
      child: modules.isEmpty
          ? const NoticeBanner(
              message: 'Tu suscripción no tiene módulos activos.',
              tone: EzySeverity.warn,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (var index = 0; index < modules.length; index++)
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
                            modules[index],
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

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final themeMode = ref.watch(themeModeProvider);

    return SectionCard(
      title: 'Preferencias',
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: themeMode == ThemeMode.dark,
        onChanged: (value) => ref
            .read(themeModeProvider.notifier)
            .setMode(value ? ThemeMode.dark : ThemeMode.light),
        title: Text(
          'Modo oscuro',
          style: EzyTextStyles.bodyStrong.copyWith(color: surfaces.textPrimary),
        ),
        subtitle: Text(
          'La app abre en modo oscuro por defecto.',
          style: EzyTextStyles.secondary.copyWith(
            color: surfaces.textSecondary,
          ),
        ),
      ),
    );
  }
}
