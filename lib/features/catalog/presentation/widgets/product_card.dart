import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../data/models/product.dart';

/// Tarjeta de producto del catálogo: imagen, nombre, precio con promoción y
/// stock de la sucursal (Tesla UI: panel `#232323`, radio 24, borde de 1 px).
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAdd,
  });

  final Product product;
  final VoidCallback? onTap;

  /// Agregado rápido de una unidad (solo productos sin variantes y con stock).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: surfaces.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Thumbnail(product: product, onAdd: onAdd),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        color: surfaces.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _PriceLine(product: product),
                    const SizedBox(height: 8),
                    _StockLine(product: product),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.product, this.onAdd});

  final Product product;

  /// Botón de agregado rápido (una unidad) para productos simples.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final image = product.displayImage;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: AspectRatio(
        aspectRatio: 1.1,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (image != null)
              Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _placeholder(),
              )
            else
              _placeholder(),
            if (product.hasPromotion)
              Positioned(
                top: 10,
                left: 10,
                child: _Badge(
                  label: 'Promoción',
                  background: EzyColors.primary,
                  foreground: EzyColors.black1,
                ),
              ),
            if (product.hasVariants)
              Positioned(
                top: 10,
                right: 10,
                child: _Badge(
                  label: 'Variantes',
                  background: surfaces.panel,
                  foreground: surfaces.textSecondary,
                  border: surfaces.border,
                ),
              ),
            if (onAdd != null && !product.isOutOfStock)
              Positioned(
                bottom: 10,
                right: 10,
                child: Material(
                  color: EzyColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onAdd,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: EzyColors.black1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const ColoredBox(
      color: EzyColors.surfaceDarkInner,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 28,
          color: EzyColors.gray66,
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          Money.format(product.price),
          style: EzyTextStyles.moneyList.copyWith(
            fontSize: 16,
            color: surfaces.textPrimary,
          ),
        ),
        if (product.hasPromotion) ...<Widget>[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              Money.format(product.originalPrice),
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textMuted,
                decoration: TextDecoration.lineThrough,
                decorationColor: surfaces.textMuted,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StockLine extends StatelessWidget {
  const _StockLine({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final severity = product.isOutOfStock
        ? EzySeverity.danger
        : EzySeverity.neutral;
    final color = StatusPalette.text(context, severity);
    final unit = product.measureUnit.isEmpty ? '' : ' ${product.measureUnit}';

    return Row(
      children: <Widget>[
        Icon(
          product.isOutOfStock
              ? Icons.remove_circle_outline
              : Icons.inventory_2_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            product.isOutOfStock
                ? 'Sin stock'
                : '${Money.formatQuantity(product.stock)}$unit',
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.caption.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
    this.border,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.badge.copyWith(color: foreground),
      ),
    );
  }
}
