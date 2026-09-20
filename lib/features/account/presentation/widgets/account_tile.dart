import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Fila de opción de la pestaña Cuenta (§14.2).
///
/// Sin sombras: panel `#232323`, radio 24 y separadores de 1 px.
class AccountTile extends StatelessWidget {
  const AccountTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.badgeCount,
    this.onTap,
    this.showChevron = true,
    this.isBusy = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Contenido a la derecha (chips, botones…).
  final Widget? trailing;

  /// Avisos pendientes: se pintan como badge en la fila.
  final int? badgeCount;

  final VoidCallback? onTap;
  final bool showChevron;

  /// La acción está en curso: se bloquea el toque y se muestra el spinner.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isEnabled = onTap != null && !isBusy;
    final badge = badgeCount ?? 0;

    return InkWell(
      onTap: isEnabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: EzyColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: EzyColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: isEnabled
                          ? surfaces.textPrimary
                          : surfaces.textSecondary,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: EzyTextStyles.caption.copyWith(
                        color: surfaces.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badge > 0) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: EzyColors.danger,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  style: EzyTextStyles.badge.copyWith(
                    color: EzyColors.white,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
            if (trailing != null) ...<Widget>[
              const SizedBox(width: 8),
              trailing!,
            ],
            if (isBusy) ...<Widget>[
              const SizedBox(width: 10),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else if (showChevron && onTap != null) ...<Widget>[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: surfaces.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Agrupa filas de [AccountTile] en un panel con separadores finos.
class AccountMenuCard extends StatelessWidget {
  const AccountMenuCard({super.key, required this.children, this.title});

  final List<Widget> children;

  /// Micro-etiqueta en mayúsculas del bloque.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!.toUpperCase(),
              style: EzyTextStyles.microLabel.copyWith(
                color: surfaces.textMuted,
              ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: surfaces.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: surfaces.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: <Widget>[
              for (var index = 0; index < children.length; index++) ...<Widget>[
                if (index > 0)
                  Divider(height: 1, thickness: 1, color: surfaces.border),
                children[index],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
