import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/support_content.dart';
import 'support_widgets.dart';

/// Card de bienvenida del Centro de soporte (título, subtítulo y mensaje).
///
/// Todo el texto viene del servidor (`GET /support`); la app solo lo pinta.
class SupportWelcomeCard extends StatelessWidget {
  const SupportWelcomeCard({super.key, required this.welcome});

  final SupportContent welcome;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SupportSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SupportIconBox(
                icon: Icons.headset_mic_outlined,
                size: 32,
                radius: 10,
                iconSize: 17,
                background: SupportPalette.accentSoft,
                border: SupportPalette.accentBorder,
                color: SupportPalette.accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      welcome.title,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: surfaces.textPrimary,
                      ),
                    ),
                    if (welcome.subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        welcome.subtitle,
                        style: EzyTextStyles.caption.copyWith(
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
          if (welcome.message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              welcome.message,
              style: EzyTextStyles.body.copyWith(
                fontSize: 12,
                height: 1.45,
                color: surfaces.textBody,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
