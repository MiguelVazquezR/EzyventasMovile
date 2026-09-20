import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/application/account_providers.dart';
import '../../features/auth/application/auth_controller.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Cabecera de pantalla: título sin margen (`h1`), botón de sucursal activa y
/// campana de notificaciones (§4.1).
///
/// El botón de sucursal solo aparece si el usuario tiene
/// `system.branches.switch`; la campana solo con `transactions.access` y navega a
/// la pantalla de notificaciones (con el total del servidor como badge).
class AppScreenHeader extends ConsumerWidget {
  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.onNotificationsTap,
    this.notificationCount,
    this.showBranchChip = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  /// Acción propia de la campana; por defecto abre las notificaciones.
  final VoidCallback? onNotificationsTap;

  /// Contador de la campana (`GET /notifications`). Si se omite, se usa el del
  /// servidor (`notificationsTotalProvider`).
  final int? notificationCount;
  final bool showBranchChip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final permissions = ref.watch(permissionsProvider);
    final accessContext = ref.watch(authControllerProvider).context;

    final canSwitchBranch = permissions.can('system.branches.switch');
    final hasBranchChip =
        showBranchChip && canSwitchBranch && accessContext != null;
    final showBell = permissions.can('transactions.access');

    // El badge solo consulta `GET /notifications` cuando la campana se pinta:
    // sin `transactions.access` esa llamada no aporta nada (el servidor
    // devolvería ceros).
    final count =
        notificationCount ?? (showBell ? ref.watch(notificationsTotalProvider) : 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: EzyTextStyles.screenTitle.copyWith(
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
              if (showBell) ...<Widget>[
                const SizedBox(width: 8),
                _NotificationBell(
                  count: count,
                  onTap:
                      onNotificationsTap ??
                      () => context.push(notificationsPath),
                ),
              ],
              ...actions,
            ],
          ),
          if (hasBranchChip) ...<Widget>[
            const SizedBox(height: 12),
            _BranchChip(
              businessName: accessContext.businessName,
              branchName:
                  accessContext.currentBranch?.label ??
                  accessContext.user.branch?.name ??
                  'Sucursal',
              onTap: () => context.push(branchSwitchPath),
            ),
          ],
        ],
      ),
    );
  }
}

class _BranchChip extends StatelessWidget {
  const _BranchChip({
    required this.businessName,
    required this.branchName,
    this.onTap,
  });

  final String businessName;
  final String branchName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: surfaces.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.storefront_outlined,
              size: 16,
              color: EzyColors.primary,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$businessName · $branchName',
                overflow: TextOverflow.ellipsis,
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.onTap, this.count});

  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final total = count ?? 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: surfaces.panel,
          shape: BoxShape.circle,
          border: Border.all(color: surfaces.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(
              Icons.notifications_none,
              size: 20,
              color: surfaces.textSecondary,
            ),
            if (total > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: EzyColors.danger,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    total > 9 ? '9+' : '$total',
                    style: EzyTextStyles.badge.copyWith(
                      color: EzyColors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
