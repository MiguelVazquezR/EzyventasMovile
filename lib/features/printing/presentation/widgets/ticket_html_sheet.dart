import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../data/models/print_payloads.dart';

/// Respaldo del ticket en HTML para cuando no hay impresora Bluetooth.
///
/// El servidor genera el mismo documento que usa la web (`POST
/// /print/ticket-html`): aquí se muestra para copiarlo y compartirlo desde el
/// teléfono (un PDF real requeriría un paquete de impresión fuera del stack
/// aprobado).
Future<void> showTicketHtmlSheet(
  BuildContext context, {
  required TicketHtml html,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _TicketHtmlSheet(html: html),
  );
}

class _TicketHtmlSheet extends StatelessWidget {
  const _TicketHtmlSheet({required this.html});

  final TicketHtml html;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'Respaldo del ticket',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            <String>[
              if (html.templateName != null) html.templateName!,
              html.paperWidth,
            ].join(' · '),
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          const NoticeBanner(
            message:
                'Copia el HTML y compártelo (correo, WhatsApp o el navegador) '
                'cuando no tengas la impresora a mano.',
            tone: EzySeverity.info,
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 360),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaces.panel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: surfaces.border),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                html.html,
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textBody,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          EzyButton(
            label: 'Copiar HTML',
            icon: Icons.copy_outlined,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: html.html));

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('HTML copiado.')),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          EzyButton(
            label: 'Cerrar',
            variant: EzyButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
