import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/server_image.dart';
import '../../application/cart_controller.dart';
import '../../data/models/cart_line.dart';
import 'cart_line_editor_sheet.dart';

/// Tarjeta de una línea del carrito (§2 y §4 del rediseño).
///
/// Renglones: miniatura de 76 px con el detalle del producto y sus acciones
/// rápidas, el precio unitario —con el de lista tachado—, la pastilla del
/// descuento y, al pie, el contador de cantidad junto al total de la línea.
///
/// El lápiz abre el editor de la línea y la papelera la quita del carrito: los
/// dos siguen llamando al mismo `CartController` de siempre.
class CartLineTile extends ConsumerWidget {
  const CartLineTile({super.key, required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final controller = ref.read(cartControllerProvider.notifier);
    final variant = line.variantLabel;
    final reason = line.discountReason;
    final dangerText = StatusPalette.text(context, EzySeverity.danger);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border, width: 1.5),
        boxShadow: EzyColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Thumbnail(url: line.imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                line.productName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: EzyTextStyles.bodyStrong.copyWith(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                  color: surfaces.textPrimary,
                                ),
                              ),
                              if (variant != null &&
                                  variant.isNotEmpty) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  variant,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: EzyTextStyles.caption.copyWith(
                                    fontSize: 11.5,
                                    color: surfaces.textSecondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _QuickAction(
                          icon: Icons.edit_outlined,
                          tooltip: 'Editar cantidad y descuento',
                          onTap: () =>
                              showCartLineEditorSheet(context, line: line),
                        ),
                        const SizedBox(width: 6),
                        _QuickAction(
                          icon: Icons.delete_outline,
                          tooltip: 'Quitar del carrito',
                          color: dangerText,
                          background: StatusPalette.soft(EzySeverity.danger),
                          border: StatusPalette.border(EzySeverity.danger),
                          onTap: () => controller.removeLine(line),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Text(
                          '${Money.format(line.unitPrice)} c/u',
                          style: EzyTextStyles.moneyList.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: EzyColors.primary,
                          ),
                        ),
                        if (line.hasDiscount) ...<Widget>[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              Money.format(line.listPrice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: EzyTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: surfaces.textMuted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (line.hasDiscount) ...<Widget>[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _DiscountPill(
                          label:
                              '- ${Money.format(line.discountPerUnit)} c/u'
                              '${reason == null || reason.isEmpty ? '' : ' • $reason'}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: surfaces.border),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              _LineStepper(line: line),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'TOTAL LÍNEA',
                    style: EzyTextStyles.microLabel.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    Money.format(line.lineTotal),
                    style: EzyTextStyles.moneyList.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: EzyColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pastilla del descuento de la línea: ahorro por unidad y su motivo.
class _DiscountPill extends StatelessWidget {
  const _DiscountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final success = StatusPalette.text(context, EzySeverity.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.success),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(EzySeverity.success)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.local_offer_outlined, size: 12, color: success),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.caption.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acción rápida de la tarjeta: 28 px de lado, con su `Tooltip`.
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.background,
    this.border,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final Color? background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: background ?? surfaces.panelInner,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border ?? surfaces.border),
          ),
          child: Icon(
            icon,
            size: 15,
            color: color ?? surfaces.textSecondary,
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

/// Contador de la línea: radio 12, botones táctiles y el «+» con el tinte de
/// marca. Llama a los mismos `incrementLine` / `decrementLine` del carrito.
class _LineStepper extends ConsumerWidget {
  const _LineStepper({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final controller = ref.read(cartControllerProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepperButton(
            icon: Icons.remove,
            tooltip: 'Quitar una unidad',
            onTap: () => controller.decrementLine(line),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 34),
            child: Text(
              Money.formatQuantity(line.quantity),
              textAlign: TextAlign.center,
              style: EzyTextStyles.bodyStrong.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: surfaces.textPrimary,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add,
            tooltip: 'Agregar una unidad',
            emphasized: true,
            onTap: () => controller.incrementLine(line),
          ),
        ],
      ),
    );
  }
}

/// Extremo del contador: 30 px de lado; el «+» lleva el tinte de marca.
class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: emphasized
                ? EzyColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            icon,
            size: 16,
            color: emphasized ? EzyColors.primary : surfaces.textSecondary,
            semanticLabel: tooltip,
          ),
        ),
      ),
    );
  }
}

/// Miniatura de una línea del carrito (§4): 76 × 76 con la foto del producto o
/// de su variante y el icono del sistema cuando no hay imagen.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.url});

  final String? url;

  static const double _side = 76;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final image = url?.trim() ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: _side,
        height: _side,
        decoration: BoxDecoration(
          color: surfaces.panelInner,
          borderRadius: BorderRadius.circular(12),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surfaces.border),
        ),
        child: image.isEmpty
            ? _placeholder(context)
            : ServerImage(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _placeholder(context),
              ),
      ),
    );
  }

  /// Placeholder cuando el producto no tiene foto en el catálogo.
  Widget _placeholder(BuildContext context) => Center(
    child: Icon(
      Icons.image_outlined,
      size: 20,
      color: context.surfaces.textMuted,
    ),
  );
}
