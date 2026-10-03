import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../account_labels.dart';
import 'account_card.dart';

/// Card: preferencias locales del dispositivo (modo oscuro).
///
/// El switch altera el tema de la app y persiste la selección en el
/// almacenamiento local a través de `themeModeProvider`.
class AccountPreferencesCard extends ConsumerWidget {
  const AccountPreferencesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return AccountCard(
      title: AccountLabels.preferences,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AccountLabels.darkMode,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    color: surfaces.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AccountLabels.darkModeSubtitle,
                  style: EzyTextStyles.secondary.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: isDark,
            onChanged: (value) => ref
                .read(themeModeProvider.notifier)
                .setMode(value ? ThemeMode.dark : ThemeMode.light),
          ),
        ],
      ),
    );
  }
}
