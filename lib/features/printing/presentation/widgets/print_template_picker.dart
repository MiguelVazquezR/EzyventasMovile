import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../data/models/print_template.dart';

/// Selección de la plantilla con la que se imprime el documento.
///
/// La lista la trae el servidor (`GET /print/templates`): la app nunca dibuja
/// ni interpreta la plantilla, solo elige su `id`.
class PrintTemplatePicker extends StatelessWidget {
  const PrintTemplatePicker({
    super.key,
    required this.templates,
    required this.selectedId,
    required this.onSelected,
    this.emptyMessage,
  });

  final List<PrintTemplate> templates;
  final int? selectedId;
  final ValueChanged<PrintTemplate> onSelected;

  /// Texto cuando el negocio no tiene plantillas para ese tipo/contexto.
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    if (templates.isEmpty) {
      return NoticeBanner(
        message:
            emptyMessage ??
            'No hay plantillas de impresión configuradas para este documento.',
        tone: EzySeverity.info,
        icon: Icons.info_outline,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final template in templates)
          _TemplateTile(
            template: template,
            isSelected: template.id == selectedId,
            onTap: () => onSelected(template),
          ),
        const SizedBox(height: 4),
        Text(
          'Las plantillas se editan en la web; la app solo elige cuál usar.',
          style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
        ),
      ],
    );
  }
}

/// Una plantilla del negocio (nombre, tipo, papel y predeterminada).
class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.template,
    required this.isSelected,
    required this.onTap,
  });

  final PrintTemplate template;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? EzyColors.primary.withValues(alpha: 0.12)
              : surfaces.panelInner,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? EzyColors.primary.withValues(alpha: 0.5)
                : surfaces.border,
          ),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: isSelected ? EzyColors.primary : surfaces.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    template.name,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    template.detailLabel,
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
