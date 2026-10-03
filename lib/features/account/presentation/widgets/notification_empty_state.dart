import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../account_labels.dart';

/// Estado vacío de la campana (§14.6): círculo naranja de 64 px con el icono y
/// la explicación de que no hay pendientes por ahora.
class NotificationEmptyState extends StatelessWidget {
  const NotificationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: EzyColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: EzyColors.primary.withValues(alpha: 0.30),
                ),
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                color: EzyColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AccountLabels.notificationsEmptyTitle,
              textAlign: TextAlign.center,
              style: EzyTextStyles.bodyStrong.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: surfaces.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AccountLabels.notificationsEmptyMessage,
              textAlign: TextAlign.center,
              style: EzyTextStyles.caption.copyWith(
                fontSize: 12,
                height: 1.45,
                color: surfaces.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
