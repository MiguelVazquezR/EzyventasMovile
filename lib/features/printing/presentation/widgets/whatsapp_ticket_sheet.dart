import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../data/whatsapp_message_builder.dart';

/// Previsualización del mensaje de WhatsApp antes de abrirlo.
///
/// El texto ya viene formateado (lo arma el servidor para ventas, abonos y
/// pedidos, o [WhatsAppMessageBuilder] para el corte de caja); aquí solo se
/// muestra, se copia y se abre `wa.me`.
Future<void> showWhatsAppMessageSheet(
  BuildContext context, {
  required String message,
  String? phone,
  String? title,
  String? subtitle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _WhatsAppMessageSheet(
      message: message,
      phone: phone,
      title: title ?? 'Enviar por WhatsApp',
      subtitle: subtitle,
    ),
  );
}

class _WhatsAppMessageSheet extends StatefulWidget {
  const _WhatsAppMessageSheet({
    required this.message,
    required this.phone,
    required this.title,
    required this.subtitle,
  });

  final String message;
  final String? phone;
  final String title;
  final String? subtitle;

  @override
  State<_WhatsAppMessageSheet> createState() => _WhatsAppMessageSheetState();
}

class _WhatsAppMessageSheetState extends State<_WhatsAppMessageSheet> {
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final hasPhone = (widget.phone ?? '').trim().isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          EzySheetHeader(
            title: widget.title,
            subtitle: hasPhone
                ? 'Se abrirá WhatsApp con el mensaje listo para ${widget.phone}.'
                : 'El cliente no tiene teléfono: se abrirá WhatsApp para que '
                      'elijas el contacto.',
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
          ),
          if (widget.subtitle != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              widget.subtitle!,
              style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
            ),
          ],
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(
              message: _errorMessage!,
              actionLabel: 'Ocultar',
              onAction: () => setState(() => _errorMessage = null),
            ),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: 'Mensaje',
            child: SelectableText(
              widget.message,
              style: EzyTextStyles.body.copyWith(
                color: surfaces.textBody,
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 16),
          EzyButton(
            label: 'Abrir WhatsApp',
            icon: Icons.chat_outlined,
            onPressed: _openWhatsApp,
          ),
          const SizedBox(height: 8),
          EzyButton(
            label: 'Copiar mensaje',
            variant: EzyButtonVariant.outline,
            onPressed: _copyMessage,
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final link = WhatsAppMessageBuilder.link(
      phone: widget.phone,
      message: widget.message,
    );

    try {
      final opened = await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showError('No se pudo abrir WhatsApp en este teléfono.');
      }
    } on Object {
      _showError('No se pudo abrir WhatsApp en este teléfono.');
    }
  }

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: widget.message));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensaje copiado.')),
    );
  }

  void _showError(String message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }
}
