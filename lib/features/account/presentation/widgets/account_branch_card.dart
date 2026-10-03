import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../account_labels.dart';
import 'account_card.dart';

/// Card: sucursal activa con la acción de cambio (§9b.1 del rediseño).
///
/// La leyenda y el botón "Cambiar de sucursal" son reactivos: el botón solo se
/// pinta con permiso `system.branches.switch` **y** más de una sucursal.
class AccountBranchCard extends StatelessWidget {
  const AccountBranchCard({
    super.key,
    required this.branchName,
    required this.branchCount,
    required this.canSwitchBranch,
    required this.onChangeBranch,
  });

  final String branchName;
  final int branchCount;
  final bool canSwitchBranch;
  final VoidCallback onChangeBranch;

  String get _legend {
    if (!canSwitchBranch) {
      return AccountLabels.noBranchPermission;
    }
    if (branchCount <= 1) {
      return AccountLabels.singleBranchRegistered;
    }

    return AccountLabels.branchCountLegend(branchCount);
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final canChange = canSwitchBranch && branchCount > 1;

    return AccountCard(
      title: AccountLabels.branchActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.storefront_outlined,
                size: 18,
                color: EzyColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  branchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: surfaces.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _legend,
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          if (canChange) ...<Widget>[
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onChangeBranch,
                icon: const Icon(
                  Icons.swap_horiz,
                  size: 18,
                  color: EzyColors.primary,
                ),
                label: Text(
                  AccountLabels.changeBranch,
                  style: EzyTextStyles.button.copyWith(
                    color: surfaces.textPrimary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: BorderSide(color: surfaces.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
