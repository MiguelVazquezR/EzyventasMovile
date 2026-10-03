import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/support_content.dart';
import '../account_labels.dart';
import 'support_widgets.dart';

/// Card «Horario de atención»: filas dinámicas del servidor.
class SupportScheduleCard extends StatelessWidget {
  const SupportScheduleCard({super.key, required this.rows});

  final List<SupportScheduleRow> rows;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SupportSectionCard(
      header: const SupportMicroTitle(AccountMoreLabels.supportSchedule),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (var i = 0; i < rows.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const SupportIconBox(icon: Icons.schedule),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rows[i].display,
                    style: EzyTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: surfaces.textBody,
                    ),
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
