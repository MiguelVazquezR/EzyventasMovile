import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../dashboard_labels.dart';

/// Cabecera de una pantalla de listado a pantalla completa (fuera del cascarón
/// de pestañas): botón de volver, título y contexto de la ventana.
class DashboardScreenHeader extends StatelessWidget {
  const DashboardScreenHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: <Widget>[
          Tooltip(
            message: DashboardLabels.closeWindow,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: surfaces.panel,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: surfaces.border),
                ),
                child: Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: surfaces.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: EzyTextStyles.screenTitle.copyWith(
                    fontSize: 20,
                    color: surfaces.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: EzyTextStyles.caption.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtro de la ventana de días (`days`, entero **1-30**; por defecto 3).
///
/// Solo ofrece valores válidos: el servidor responde `422` con `0`, negativos,
/// texto o más de 30, así que el cliente no puede enviarlos.
class DashboardWindowFilter extends StatelessWidget {
  const DashboardWindowFilter({
    super.key,
    required this.days,
    required this.onChanged,
  });

  /// Ventana aplicada, tal como la devolvió el servidor.
  final int days;

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: DashboardLabels.dayOptions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = DashboardLabels.dayOptions[index];

          return EzyChip(
            label: DashboardLabels.dayOption(option),
            compact: true,
            selected: option == days,
            onTap: option == days ? null : () => onChanged(option),
          );
        },
      ),
    );
  }
}
