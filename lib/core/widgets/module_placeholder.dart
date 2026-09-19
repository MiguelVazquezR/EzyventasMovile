import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/status_palette.dart';
import 'notice_banner.dart';
import 'section_card.dart';

/// Pantalla de módulo todavía no habilitada en esta entrega.
///
/// En lugar de un "en construcción" vacío, muestra el estado real que ya conoce
/// la sesión (módulo contratado, permisos efectivos) para que el usuario sepa
/// por qué la ve y qué llegará.
class ModulePlaceholder extends StatelessWidget {
  const ModulePlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.upcoming = const <String>[],
    this.footer,
  });

  final String title;
  final String description;
  final IconData icon;

  /// Funciones que se habilitan en la siguiente entrega.
  final List<String> upcoming;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaces.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: surfaces.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: EzyColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: EzyColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(icon, color: EzyColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        fontSize: 16,
                        color: surfaces.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                description,
                style: EzyTextStyles.body.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (upcoming.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Siguiente entrega',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final item in upcoming)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(
                            Icons.circle,
                            size: 6,
                            color: EzyColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item,
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
        if (footer != null) ...<Widget>[
          const SizedBox(height: 12),
          footer!,
        ],
        const SizedBox(height: 12),
        NoticeBanner(
          message:
              'Esta pantalla se habilita en la siguiente entrega de la app (etapas 2 a 6).',
          tone: EzySeverity.info,
        ),
      ],
    );
  }
}
