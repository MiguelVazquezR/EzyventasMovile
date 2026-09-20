import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/external_links.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../application/account_providers.dart';
import '../data/models/support_content.dart';
import 'account_labels.dart';
import 'widgets/account_scaffold.dart';

/// Centro de soporte (`GET /support`, contrato §11b.3).
///
/// Todo el contenido (mensaje, horario, canales y temas) viene del servidor:
/// cambiarlo en `config/support.php` no requiere publicar una versión nueva de la
/// app. Los canales se abren con el manejador del sistema.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(supportProvider);

    return AccountScaffold(
      title: AccountMoreLabels.supportTitle,
      onRefresh: () async => ref.invalidate(supportProvider),
      body: support.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            ErrorNotice(
              message: error is ApiException
                  ? error.message
                  : 'No pudimos cargar el centro de soporte.',
              onRetry: () => ref.invalidate(supportProvider),
            ),
          ],
        ),
        data: (content) => _SupportBody(content: content),
      ),
    );
  }
}

class _SupportBody extends StatelessWidget {
  const _SupportBody({required this.content});

  final SupportContent content;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        SectionCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                content.title,
                style: EzyTextStyles.bodyStrong.copyWith(
                  fontSize: 18,
                  color: surfaces.textPrimary,
                ),
              ),
              if (content.subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  content.subtitle,
                  style: EzyTextStyles.secondary.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
              if (content.message.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  content.message,
                  style: EzyTextStyles.body.copyWith(
                    color: surfaces.textBody,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (content.schedule.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          SectionCard(
            title: AccountMoreLabels.supportSchedule,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final row in content.schedule)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.schedule_outlined,
                          size: 16,
                          color: surfaces.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            row.display,
                            style: EzyTextStyles.body.copyWith(
                              color: surfaces.textBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (content.channels.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          SectionCard(
            title: AccountMoreLabels.supportChannels,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final channel in content.channels)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: EzyButton(
                      label: channel.display,
                      icon: _channelIcon(channel.type),
                      variant: EzyButtonVariant.outline,
                      onPressed: () => ExternalLinks.open(context, channel.url),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (content.helpCenterUrl != null || content.helpTopics.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SectionCard(
              title: AccountMoreLabels.supportHelpCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final topic in content.helpTopics)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            topic.title,
                            style: EzyTextStyles.bodyStrong.copyWith(
                              color: surfaces.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            topic.description,
                            style: EzyTextStyles.caption.copyWith(
                              color: surfaces.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (content.helpCenterUrl != null)
                    EzyButton(
                      label: AccountMoreLabels.supportHelpCenterAction,
                      icon: Icons.open_in_new,
                      onPressed: () =>
                          ExternalLinks.open(context, content.helpCenterUrl),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Icono por tipo de canal; el servidor manda `email` y `whatsapp`.
  IconData _channelIcon(String type) => switch (type) {
    'email' => Icons.mail_outline,
    'whatsapp' => Icons.chat_bubble_outline,
    _ => Icons.link_outlined,
  };
}

