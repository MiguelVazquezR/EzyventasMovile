import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../account_labels.dart';
import 'account_card.dart';

/// Card: menú principal de opciones (§14.2), con divisores de 1 px y cuadros de
/// icono de 32x32.
///
/// "Mi suscripción" solo se pinta para el propietario; Notificaciones lleva la
/// pastilla de conteo del servidor (`9+` a partir de diez, oculta con `0`).
class AccountMenuCard extends StatelessWidget {
  const AccountMenuCard({
    super.key,
    required this.isOwner,
    required this.notificationTotal,
    required this.onProfile,
    required this.onSubscription,
    required this.onNotifications,
    required this.onSupport,
    this.subscriptionBadge,
  });

  final bool isOwner;
  final int notificationTotal;
  final VoidCallback onProfile;
  final VoidCallback onSubscription;
  final VoidCallback onNotifications;
  final VoidCallback onSupport;

  /// Badge opcional de estado junto a "Mi suscripción" (p. ej. `POR VENCER`).
  final String? subscriptionBadge;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _MenuRow(
        icon: Icons.person_outline,
        title: AccountLabels.profile,
        onTap: onProfile,
      ),
      if (isOwner)
        _MenuRow(
          icon: Icons.credit_card_outlined,
          title: AccountLabels.subscription,
          badgeLabel: subscriptionBadge,
          onTap: onSubscription,
        ),
      _MenuRow(
        icon: Icons.notifications_outlined,
        title: AccountLabels.notifications,
        badgeCount: notificationTotal,
        onTap: onNotifications,
      ),
      _MenuRow(
        icon: Icons.help_outline,
        title: AccountLabels.support,
        onTap: onSupport,
      ),
    ];

    return AccountCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++) ...<Widget>[
            rows[i],
            if (i < rows.length - 1)
              Divider(height: 1, thickness: 1, color: context.surfaces.border),
          ],
        ],
      ),
    );
  }
}

/// Fila del menú: cuadro de icono 32x32 (radio 8), título y chevron.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badgeCount,
    this.badgeLabel,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final int? badgeCount;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            AccountIconBox(icon: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ),
            if (badgeLabel != null) ...<Widget>[
              const SizedBox(width: 8),
              _StatusBadge(label: badgeLabel!),
            ],
            if (badgeCount != null && badgeCount! > 0) ...<Widget>[
              const SizedBox(width: 8),
              AccountCountPill(count: badgeCount!),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 20, color: surfaces.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Badge de estado ámbar (texto `#FCD34D` oscuro / `#B45309` claro).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = _warnText(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: EzyColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: EzyColors.warning.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.badge.copyWith(
          letterSpacing: 0,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  static Color _warnText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? EzyColors.warnTextDark
      : EzyColors.warnTextLight;
}
