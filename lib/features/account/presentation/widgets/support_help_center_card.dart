import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/support_content.dart';
import '../account_labels.dart';
import 'support_widgets.dart';

/// Card «Centro de ayuda y guías».
///
/// La base de tutoriales interactiva aún no está disponible: muestra los temas
/// informativos del servidor, la pastilla ámbar «Viene pronto» y el botón de
/// acceso **deshabilitado** (`onPressed: null`).
class SupportHelpCenterCard extends StatelessWidget {
  const SupportHelpCenterCard({super.key, required this.topics});

  final List<SupportTopic> topics;

  @override
  Widget build(BuildContext context) {
    return SupportSectionCard(
      header: const SupportMicroTitle(AccountMoreLabels.supportHelpCenterGuides),
      trailing: const _SoonPill(),
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
          const _ComingSoonBanner(),
          const SizedBox(height: 12),
          const _HelpCenterButton(),
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

/// Pastilla ámbar «VIENE PRONTO».
class _SoonPill extends StatelessWidget {
  const _SoonPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SupportPalette.warnSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: SupportPalette.warnBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.schedule,
            size: 12,
            color: SupportPalette.warnText(context),
          ),
          const SizedBox(width: 4),
          Text(
            AccountMoreLabels.supportSoonUpper,
            style: EzyTextStyles.badge.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: SupportPalette.warnText(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner explicativo de la próxima actualización.
class _ComingSoonBanner extends StatelessWidget {
  const _ComingSoonBanner();

  @override
  Widget build(BuildContext context) {
    final tone = SupportPalette.warnText(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SupportPalette.warnBannerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SupportPalette.warnBannerBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.auto_awesome, size: 16, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AccountMoreLabels.supportHelpBanner,
              style: EzyTextStyles.caption.copyWith(
                fontSize: 11,
                height: 1.4,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón «Abrir centro de ayuda (Viene pronto)» completamente deshabilitado.
class _HelpCenterButton extends StatelessWidget {
  const _HelpCenterButton();

  @override
  Widget build(BuildContext context) {
    final tone = SupportPalette.disabledText(context);

    return Semantics(
      button: true,
      enabled: false,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: SupportPalette.disabledBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SupportPalette.disabledBorder(context)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.open_in_new, size: 16, color: tone),
            const SizedBox(width: 10),
            Text(
              AccountMoreLabels.supportHelpCenterActionSoon,
              style: EzyTextStyles.button.copyWith(color: tone),
            ),
          ],
        ),
      ),
    );
  }
}
