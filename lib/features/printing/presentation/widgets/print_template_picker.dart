import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_selectable_tile.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../data/models/print_template.dart';

/// Selección de la plantilla con la que se imprime el documento.
///
/// La lista la trae el servidor (`GET /print/templates`): la app nunca dibuja ni
/// interpreta la plantilla, solo elige su `id`. Cada plantilla es una fila del
/// design system ([EzySelectableTile]) —contenedor `panelInner`, radio 16 y
/// borde— así que el bloque **no** anida tarjetas: la card la pone quien lo usa
/// (la sección «Etiqueta» de la hoja) y, suelto en la hoja, cada fila ya se lee
/// como una card más.
class PrintTemplatePicker extends StatelessWidget {
  const PrintTemplatePicker({
    super.key,
    required this.templates,
    required this.selectedId,
    required this.onSelected,
    this.emptyMessage,
    this.title = 'PLANTILLA DE IMPRESIÓN',
    this.showRecordedChip = true,
    this.compact = false,
  });

  final List<PrintTemplate> templates;
  final int? selectedId;
  final ValueChanged<PrintTemplate> onSelected;

  /// Texto cuando el negocio no tiene plantillas para ese tipo/contexto.
  final String? emptyMessage;

  /// Micro-etiqueta del encabezado; `null` pinta solo las filas, para las
  /// secciones que ya traen su propio título (las etiquetas TSPL).
  final String? title;

  /// Chip «Recordada»: la hoja lo enciende cuando la plantilla vigente es la
  /// que quedó guardada de la última impresión.
  final bool showRecordedChip;

  /// Filas compactas (sin contenedor) para opciones anidadas dentro de otra
  /// tarjeta: la sección «Etiqueta» ya aporta su caja y no se anidan cards.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final title = this.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (title != null) ...<Widget>[
          _PickerHeader(title: title, showRecordedChip: showRecordedChip),
          const SizedBox(height: 12),
        ],
        if (templates.isEmpty)
          NoticeBanner(
            message:
                emptyMessage ??
                'No hay plantillas de impresión configuradas para este '
                    'documento.',
            tone: EzySeverity.info,
            icon: Icons.info_outline,
          )
        else
          for (final template in templates)
            EzySelectableTile(
              title: template.name,
              // El detalle es el contexto de la plantilla y, cuando el negocio
              // la marcó, que es la predeterminada.
              subtitle: template.isDefault
                  ? '${template.contextLabel} · predeterminada'
                  : template.contextLabel,
              value: template.paperWidth,
              isSelected: template.id == selectedId,
              compact: compact,
              onTap: () => onSelected(template),
            ),
        // La nota al pie es del bloque rotulado: dentro de una sección que ya
        // tiene su título (y su propio microcopy) sobraría.
        if (title != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Las plantillas se editan en la web; la app solo elige cuál usar.',
            style: TextStyle(
              fontFamily: EzyTextStyles.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              height: 1.3,
              color: surfaces.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// Encabezado del bloque: micro-etiqueta y chip de plantilla recordada.
class _PickerHeader extends StatelessWidget {
  const _PickerHeader({required this.title, required this.showRecordedChip});

  final String title;
  final bool showRecordedChip;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: EzyTextStyles.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: surfaces.textPrimary,
            ),
          ),
        ),
        if (showRecordedChip) ...<Widget>[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: EzyColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Recordada',
              style: TextStyle(
                fontFamily: EzyTextStyles.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: EzyColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
