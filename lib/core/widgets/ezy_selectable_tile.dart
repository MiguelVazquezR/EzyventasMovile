import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Opción seleccionable del design system (§10, §12).
///
/// La usan el detalle de producto (variantes) y el cobro (clientes): antes cada
/// pantalla copiaba el mismo contenedor de radio 16, el mismo borde y el mismo
/// tinte azul del seleccionado. Con el check a la izquierda la selección no
/// depende solo del color.
class EzySelectableTile extends StatelessWidget {
  const EzySelectableTile({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
    this.caption,
    this.captionColor,
    this.value,
  });

  final String title;

  /// Segunda línea: stock de la variante o teléfono del cliente.
  final String? subtitle;
  final Color? subtitleColor;

  /// Tercera línea de apoyo (saldo y crédito del cliente).
  final String? caption;
  final Color? captionColor;

  /// Dato numérico a la derecha en cifras tabulares (precio de la variante).
  final String? value;

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
            if (isSelected) ...<Widget>[
              const Icon(
                Icons.check_circle,
                size: 20,
                color: EzyColors.primary,
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: EzyTextStyles.secondary.copyWith(
                        color: subtitleColor ?? surfaces.textSecondary,
                      ),
                    ),
                  ],
                  if (caption != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      caption!,
                      style: EzyTextStyles.caption.copyWith(
                        color: captionColor ?? surfaces.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (value != null) ...<Widget>[
              const SizedBox(width: 12),
              Text(
                value!,
                style: EzyTextStyles.moneyList.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
