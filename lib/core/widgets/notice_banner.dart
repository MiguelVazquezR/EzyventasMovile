import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/status_palette.dart';

/// Banner de aviso dentro de una pantalla o formulario.
///
/// Se usa para el `message` del servidor (errores), para advertencias como
/// `cash_register_in_use` y para confirmaciones puntuales. **Nunca** se inventa
/// el texto: siempre viene del servidor o del microcopy aprobado.
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.tone = EzySeverity.danger,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final EzySeverity tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  IconData get _defaultIcon => switch (tone) {
    EzySeverity.danger => Icons.error_outline,
    EzySeverity.warn => Icons.warning_amber_rounded,
    EzySeverity.success => Icons.check_circle_outline,
    EzySeverity.info => Icons.info_outline,
    EzySeverity.neutral => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, tone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StatusPalette.soft(tone),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StatusPalette.border(tone)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon ?? _defaultIcon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message,
                  style: EzyTextStyles.body.copyWith(color: color),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onAction,
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      actionLabel!,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        color: color,
                        decoration: TextDecoration.underline,
                        decorationColor: color,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de error con acción "Reintentar" (§12).
class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return NoticeBanner(
      message: message,
      tone: EzySeverity.danger,
      actionLabel: onRetry == null ? null : 'Reintentar',
      onAction: onRetry,
    );
  }
}

/// Texto de error bajo un campo (`errors.campo[0]` del `422`).
class FieldErrorText extends StatelessWidget {
  const FieldErrorText({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style: EzyTextStyles.caption.copyWith(color: EzyColors.danger),
      ),
    );
  }
}
