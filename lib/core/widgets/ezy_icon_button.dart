import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Botón circular de icono: 44 px de lado, borde de 1 px y `elevation: 0` (§4.1).
///
/// Sustituye los botones ad-hoc de cabecera (campana, ayuda, ajustes) para que
/// todos compartan el mismo blanco táctil y el mismo punto de conteo.
class EzyIconButton extends StatelessWidget {
  const EzyIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.size = 44,
    this.iconSize = 20,
    this.badgeCount,
    this.badgeColor = EzyColors.danger,
    this.color,
    this.background,
    this.borderColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Lado del círculo; 44 px cubre el mínimo táctil recomendado.
  final double size;
  final double iconSize;

  /// Conteo del servidor. `null` o `0` = sin punto; a partir de 10 se pinta `9+`.
  final int? badgeCount;
  final Color badgeColor;

  /// Color del icono; por defecto el tono secundario de la superficie.
  final Color? color;

  /// Relleno del círculo; por defecto `panel`. Sobre la cabecera con degradado
  /// (POS, menú lateral) se pasa un blanco translúcido para que el botón se lea
  /// sin abrir un agujero oscuro en la banda.
  final Color? background;

  /// Color del borde de 1 px; por defecto `border`.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final total = badgeCount ?? 0;
    final isEnabled = onTap != null;

    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? surfaces.panel,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor ?? surfaces.border),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: iconSize,
              color:
                  color ??
                  (isEnabled ? surfaces.textSecondary : surfaces.textMuted),
            ),
            if (total > 0)
              Positioned(
                top: size * 0.18,
                right: size * 0.18,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    total > 9 ? '9+' : '$total',
                    style: EzyTextStyles.badge.copyWith(
                      color: EzyColors.white,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}
