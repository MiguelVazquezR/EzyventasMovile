import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/ezy_chip.dart';
import '../../../core/widgets/ezy_dialog.dart';
import '../../../core/widgets/ezy_list_tile.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/models/available_branch.dart';
import '../application/branch_switch_controller.dart';
import 'account_labels.dart';
import 'widgets/account_scaffold.dart';

/// Selector de sucursal (`available_branches` de `GET /auth/me`).
///
/// Elegir otra sucursal ejecuta `PUT /branch/switch/{id}` con confirmación
/// previa; después la app limpia la caché de la sucursal anterior, refresca
/// `GET /auth/me` y vuelve a la pantalla de Caja (el turno anterior era de otra
/// sucursal). Solo se llega aquí con permiso `system.branches.switch`.
class BranchSwitchScreen extends ConsumerWidget {
  const BranchSwitchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(authControllerProvider).context;
    final state = ref.watch(branchSwitchControllerProvider);
    final controller = ref.read(branchSwitchControllerProvider.notifier);
    final branches =
        accessContext?.availableBranches ?? const <AvailableBranch>[];

    return AccountScaffold(
      title: AccountLabels.branchTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          if (state.errorMessage != null) ...<Widget>[
            ErrorNotice(
              message: state.errorMessage!,
              onRetry: controller.consumeError,
            ),
            const SizedBox(height: 12),
          ],
          if (state.notice != null) ...<Widget>[
            NoticeBanner(
              message: state.notice!,
              tone: EzySeverity.success,
              actionLabel: AccountLabels.branchChangedGoToCash,
              onAction: () => _goToCash(context, ref),
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: AccountLabels.branchTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  AccountLabels.branchSubtitle,
                  style: EzyTextStyles.caption.copyWith(
                    color: context.surfaces.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                for (final branch in branches)
                  _BranchRow(
                    branch: branch,
                    isBusy: state.isSwitching,
                    onSelect: () => _confirmSwitch(context, ref, branch),
                  ),
                if (branches.isEmpty)
                  const NoticeBanner(
                    message: 'Tu usuario no tiene sucursales disponibles para cambiar.',
                    tone: EzySeverity.warn,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSwitch(
    BuildContext context,
    WidgetRef ref,
    AvailableBranch branch,
  ) async {
    if (branch.isCurrent) {
      return;
    }

    final confirmed = await showEzyConfirmDialog(
      context,
      title: AccountLabels.branchConfirm(branch.label),
      message: AccountLabels.branchConfirmMessage,
      confirmLabel: AccountLabels.branchChange,
    );

    if (!confirmed) {
      return;
    }

    final switched = await ref
        .read(branchSwitchControllerProvider.notifier)
        .switchTo(branch);

    if (switched && context.mounted) {
      // La sesión de caja pertenecía a la sucursal anterior (contrato §11b.1).
      _goToCash(context, ref);
    }
  }

  /// Regresa a la pestaña Caja si el usuario la tiene; si no, a Cuenta.
  void _goToCash(BuildContext context, WidgetRef ref) {
    final permissions = ref.read(permissionsProvider);
    final cashTab = AppTab.cashRegister;

    context.go(
      permissions.isTabVisible(cashTab) ? cashTab.path : AppTab.account.path,
    );
  }
}

/// Fila de sucursal: la activa lleva el check y su etiqueta, y no se puede
/// elegir.
class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.branch,
    required this.isBusy,
    required this.onSelect,
  });

  final AvailableBranch branch;
  final bool isBusy;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return EzyListTile(
      icon: branch.isCurrent ? Icons.check_circle : Icons.storefront_outlined,
      title: branch.label,
      showDivider: false,
      enabled: !isBusy,
      onTap: branch.isCurrent ? null : onSelect,
      trailing: branch.isCurrent
          ? const EzyChip(
              label: AccountLabels.branchCurrent,
              compact: true,
              tone: EzySeverity.success,
            )
          : (isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null),
    );
  }
}
