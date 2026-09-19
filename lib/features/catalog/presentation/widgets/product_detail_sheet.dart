import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../application/catalog_providers.dart';
import '../../data/models/product.dart';

/// Abre el detalle del producto en un bottom sheet.
///
/// Muestra los datos del listado al instante y los completa con
/// `GET /catalog/products/{id}` (variantes y componentes completos).
Future<void> showProductDetail(BuildContext context, Product product) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ProductDetailSheet(initial: product),
  );
}

class _ProductDetailSheet extends ConsumerStatefulWidget {
  const _ProductDetailSheet({required this.initial});

  final Product initial;

  @override
  ConsumerState<_ProductDetailSheet> createState() =>
      _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<_ProductDetailSheet> {
  int? _selectedCombinationId;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final detail = ref.watch(productDetailProvider(widget.initial.id));
    final product = detail.asData?.value ?? widget.initial;
    final selected = _selectedCombination(product);
    final price = selected?.price ?? product.price;
    final stock = selected?.stock ?? product.stock;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          ProductImage(product: product),
          const SizedBox(height: 16),
          Text(
            product.name,
            style: EzyTextStyles.bodyStrong.copyWith(
              fontSize: 18,
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            <String>[
              if (product.sku != null && product.sku!.isNotEmpty)
                'SKU ${product.sku}',
              if (product.category != null && product.category!.isNotEmpty)
                product.category!,
            ].join(' · '),
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ProductPriceBlock(product: product, price: price, stock: stock),
          if (product.hasVariants) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Variantes',
              child: Column(
                children: <Widget>[
                  for (final combination in product.variantCombinations)
                    ProductVariantTile(
                      combination: combination,
                      isSelected: combination.id == selected?.id,
                      onTap: () => setState(
                        () => _selectedCombinationId = combination.id,
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (product.description != null &&
              product.description!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Descripción',
              child: Text(
                product.description!,
                style: EzyTextStyles.body.copyWith(color: surfaces.textBody),
              ),
            ),
          ],
          if (product.components.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Incluye',
              child: Column(
                children: <Widget>[
                  for (final component in product.components)
                    SectionRow(
                      label: component.name,
                      value: Money.formatQuantity(component.quantity),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const NoticeBanner(
            message:
                'El carrito y el cobro se habilitan en la siguiente entrega de la app.',
            tone: EzySeverity.info,
          ),
        ],
      ),
    );
  }

  VariantCombination? _selectedCombination(Product product) {
    if (!product.hasVariants) {
      return null;
    }

    for (final combination in product.variantCombinations) {
      if (combination.id == _selectedCombinationId) {
        return combination;
      }
    }

    return product.variantCombinations.first;
  }
}

/// Imagen del producto con respaldo cuando no hay foto.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    this.aspectRatio = 16 / 10,
  });

  final Product product;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final image = product.displayImage;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: image == null
            ? const ImagePlaceholder()
            : Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const ImagePlaceholder(),
              ),
      ),
    );
  }
}

/// Fondo con icono cuando el producto no tiene imagen.
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: EzyColors.surfaceDarkInner,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 32,
          color: EzyColors.gray66,
        ),
      ),
    );
  }
}

/// Bloque de precio: precio vigente, lista tachada, promoción y mayoreo.
class ProductPriceBlock extends StatelessWidget {
  const ProductPriceBlock({
    super.key,
    required this.product,
    required this.price,
    required this.stock,
  });

  final Product product;
  final double price;
  final double stock;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final outOfStock = stock <= 0;
    final stockColor = StatusPalette.text(
      context,
      outOfStock ? EzySeverity.danger : EzySeverity.neutral,
    );

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            Money.format(price),
            style: EzyTextStyles.moneyLarge.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          if (product.hasPromotion) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              'Antes ${Money.format(product.originalPrice)}',
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textMuted,
                decoration: TextDecoration.lineThrough,
                decorationColor: surfaces.textMuted,
              ),
            ),
          ],
          if (product.promotions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final promotion in product.promotions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.local_offer_outlined,
                      size: 14,
                      color: EzyColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        promotion.label,
                        style: EzyTextStyles.caption.copyWith(
                          color: EzyColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Icon(
                outOfStock
                    ? Icons.remove_circle_outline
                    : Icons.inventory_2_outlined,
                size: 15,
                color: stockColor,
              ),
              const SizedBox(width: 8),
              Text(
                outOfStock
                    ? 'Sin stock disponible'
                    : '${Money.formatQuantity(stock)} ${product.measureUnit} disponibles'
                          .trim(),
                style: EzyTextStyles.caption.copyWith(color: stockColor),
              ),
            ],
          ),
          if (product.hasPriceTiers) ...<Widget>[
            const Divider(height: 24),
            for (final tier in product.priceTiers)
              SectionRow(
                label: 'Desde ${Money.formatQuantity(tier.minQuantity)} pzas',
                value: Money.format(tier.price),
              ),
          ],
        ],
      ),
    );
  }
}

/// Combinación de variante seleccionable (`product_attribute_id`).
class ProductVariantTile extends StatelessWidget {
  const ProductVariantTile({
    super.key,
    required this.combination,
    required this.isSelected,
    required this.onTap,
  });

  final VariantCombination combination;
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    combination.label,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    combination.isOutOfStock
                        ? 'Sin stock'
                        : '${Money.formatQuantity(combination.stock)} disponibles',
                    style: EzyTextStyles.secondary.copyWith(
                      color: combination.isOutOfStock
                          ? StatusPalette.text(context, EzySeverity.danger)
                          : surfaces.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              Money.format(combination.price),
              style: EzyTextStyles.moneyList.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
