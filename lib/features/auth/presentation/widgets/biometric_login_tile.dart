import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/status_badge.dart';

/// Tarjeta compacta de acceso biométrico (huella dactilar / Face ID).
///
/// Se monta cuando el teléfono tiene el sensor configurado y activo. Si todavía
/// no hay una sesión guardada en el almacenamiento seguro, la pantalla explica
/// cómo activar el ingreso rápido en vez de disparar el prompt contra la nada.
/// El badge píldora «DISPONIBLE» con punto pulsante vive en `StatusBadge` (§7).
class BiometricLoginTile extends StatelessWidget {
  const BiometricLoginTile({
    super.key,
    required this.onPressed,
    this.icon = Icons.fingerprint,
    this.enabled = true,
    this.isBusy = false,
  });

  /// Invoca el prompt del sistema (huella / rostro).
  final VoidCallback? onPressed;

  /// Huella o rostro, según la biometría inscrita del teléfono.
  final IconData icon;

  final bool enabled;

  /// Mientras el prompt está en curso el botón muestra su spinner.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: EzyColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: EzyColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // `Wrap` para que en pantallas angostas la píldora baje de línea
                // en vez de desbordar la fila.
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      'Ingreso biométrico',
                      style: EzyTextStyles.bodyStrong.copyWith(
                        color: surfaces.textPrimary,
                      ),
                    ),
                    const StatusBadge(
                      label: 'Disponible',
                      severity: EzySeverity.success,
                      showDot: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Entrar rápido con Huella o Face ID',
                  style: EzyTextStyles.caption.copyWith(
                    color: surfaces.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _UseButton(enabled: enabled, isBusy: isBusy, onPressed: onPressed),
        ],
      ),
    );
  }
}

/// Botón compacto «Usar» con ícono de escaneo (relleno de marca translúcido).
class _UseButton extends StatelessWidget {
  const _UseButton({
    required this.enabled,
    required this.isBusy,
    this.onPressed,
  });

  final bool enabled;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final active = enabled && onPressed != null && !isBusy;
    final color = active || isBusy ? EzyColors.primary : surfaces.textMuted;

    return Material(
      color: active
          ? EzyColors.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: active ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active
                  ? EzyColors.primary.withValues(alpha: 0.35)
                  : surfaces.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (isBusy)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(Icons.qr_code_scanner, size: 16, color: color),
              const SizedBox(width: 6),
              Text('Usar', style: EzyTextStyles.button.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
