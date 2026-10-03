import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/external_links.dart';
import '../../data/models/support_content.dart';
import '../account_labels.dart';
import 'support_widgets.dart';

/// Card «Canales de contacto directo»: botones outline que abren el canal con
/// el manejador del sistema (`mailto:`, `wa.me`, `tel:`).
class SupportChannelsCard extends StatelessWidget {
  const SupportChannelsCard({super.key, required this.channels});

  final List<SupportChannel> channels;

  @override
  Widget build(BuildContext context) {
    return SupportSectionCard(
      header: const SupportMicroTitle(AccountMoreLabels.supportChannelsDirect),
      child: Column(
        children: <Widget>[
          for (var i = 0; i < channels.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            _ChannelButton(channel: channels[i]),
          ],
        ],
      ),
    );
  }
}

class _ChannelButton extends StatelessWidget {
  const _ChannelButton({required this.channel});

  final SupportChannel channel;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final tone = _ChannelTone.of(channel.type);

    return InkWell(
      onTap: channel.isUsable
          ? () => ExternalLinks.open(context, channel.url)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SupportPalette.border(context)),
        ),
        child: Row(
          children: <Widget>[
            SupportIconBox(
              icon: tone?.icon ?? Icons.link_outlined,
              background: tone?.soft ?? surfaces.panelInner,
              border: tone?.border ?? SupportPalette.border(context),
              color: tone?.color ?? surfaces.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    channel.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: surfaces.textPrimary,
                    ),
                  ),
                  if (channel.value.isNotEmpty)
                    Text(
                      channel.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: surfaces.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, size: 15, color: surfaces.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Tinte del cuadro de icono según el tipo de canal que manda el servidor.
class _ChannelTone {
  const _ChannelTone(this.icon, this.color, this.soft, this.border);

  final IconData icon;
  final Color color;
  final Color soft;
  final Color border;

  static _ChannelTone? of(String type) => switch (type) {
    'whatsapp' => const _ChannelTone(
      Icons.chat_bubble_outline,
      EzyColors.success,
      Color(0x1A22C55E),
      Color(0x4D22C55E),
    ),
    'email' => const _ChannelTone(
      Icons.mail_outline,
      EzyColors.info,
      Color(0x1A3B82F6),
      Color(0x4D3B82F6),
    ),
    _ => null,
  };
}
