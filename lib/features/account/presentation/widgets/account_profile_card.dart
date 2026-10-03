import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../../../auth/data/models/auth_user.dart';
import '../account_labels.dart';
import 'account_card.dart';

/// Card: perfil del usuario (avatar 56x56 radio 16, datos y chips de contexto).
class AccountProfileCard extends StatelessWidget {
  const AccountProfileCard({
    super.key,
    required this.user,
    required this.businessName,
  });

  final AuthUser user;
  final String businessName;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return AccountCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Avatar(name: user.name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: surfaces.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.secondary.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: surfaces.textSecondary,
                      ),
                    ),
                    if (user.phone != null && user.phone!.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        user.phone!,
                        style: EzyTextStyles.secondary.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
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
              EzyChip(
                label: businessName,
                icon: Icons.storefront_outlined,
                inner: true,
              ),
              if (user.isSubscriptionOwner)
                const EzyChip(
                  label: AccountLabels.owner,
                  icon: Icons.workspace_premium,
                  selected: true,
                  inner: true,
                ),
              if (!user.isEmailVerified)
                const EzyChip(
                  label: AccountLabels.emailUnverified,
                  icon: Icons.warning_amber_rounded,
                  tone: EzySeverity.warn,
                  inner: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Avatar cuadrado de 56x56 con radio 16: iniciales en naranja de marca.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: EzyColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: EzyColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        AppFormatters.initials(name),
        style: EzyTextStyles.bodyStrong.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: EzyColors.primary,
        ),
      ),
    );
  }
}
