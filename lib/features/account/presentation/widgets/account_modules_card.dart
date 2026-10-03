import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../account_labels.dart';
import 'account_card.dart';

/// Card: módulos contratados por la suscripción.
///
/// Cada módulo activo se marca con un check verde y la etiqueta `ACTIVO`; sin
/// módulos se muestra el aviso ámbar del sistema.
class AccountModulesCard extends StatelessWidget {
  const AccountModulesCard({super.key, required this.modules});

  final List<String> modules;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return AccountCard(
      title: AccountLabels.modules,
      child: modules.isEmpty
          ? const NoticeBanner(
              message: AccountLabels.modulesEmpty,
              tone: EzySeverity.warn,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < modules.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          modules[i],
                          style: EzyTextStyles.body.copyWith(
                            color: surfaces.textBody,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: EzyColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AccountLabels.active,
                        style: EzyTextStyles.badge.copyWith(
                          letterSpacing: 0,
                          fontWeight: FontWeight.w800,
                          color: EzyColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
