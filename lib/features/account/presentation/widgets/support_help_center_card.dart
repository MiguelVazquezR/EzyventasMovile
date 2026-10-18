import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/external_links.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../data/models/support_content.dart';
import '../account_labels.dart';
import 'support_widgets.dart';

/// Card «Centro de ayuda y guías».
///
/// Muestra los temas informativos del servidor y el botón que abre el Centro
/// de ayuda web en el navegador externo (`url_launcher`).
class SupportHelpCenterCard extends StatelessWidget {
  const SupportHelpCenterCard({super.key, required this.topics, this.url});

  final List<SupportTopic> topics;

  /// URL del Centro de ayuda entregada por el servidor (`help_center_url`).
  final String? url;

  @override
  Widget build(BuildContext context) {
    final serverUrl = url?.trim() ?? '';
    final target = serverUrl.isEmpty ? AppConfig.helpCenterUrl : serverUrl;

    return SupportSectionCard(
      header: const SupportMicroTitle(AccountMoreLabels.supportHelpCenterGuides),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (topics.isNotEmpty) ...<Widget>[
            for (var i = 0; i < topics.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 16,
                  thickness: 1,
                  color: SupportPalette.divider(context),
                ),
              _TopicTile(topic: topics[i]),
            ],
            const SizedBox(height: 14),
          ],
          _HelpCenterButton(url: target),
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final SupportTopic topic;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          topic.title,
          style: EzyTextStyles.caption.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: surfaces.textPrimary,
          ),
        ),
        if (topic.description.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            topic.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: surfaces.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Botón «Abrir centro de ayuda»: abre la web en el navegador externo.
class _HelpCenterButton extends StatelessWidget {
  const _HelpCenterButton({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return EzyButton(
      label: AccountMoreLabels.supportHelpCenterAction,
      icon: Icons.open_in_new,
      variant: EzyButtonVariant.outlinePrimary,
      onPressed: () => ExternalLinks.open(context, url),
    );
  }
}

