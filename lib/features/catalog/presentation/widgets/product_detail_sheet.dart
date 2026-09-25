import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/html_text.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/server_image.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../pos/application/cart_controller.dart';
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

    // La descripción llega como texto enriquecido (`<p>…</p>`): se muestra el
    // texto, sin etiquetas.
    final description = HtmlText.toPlain(product.description);

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
          if (description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Descripción',
              child: Text(
                description,
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
          if (stock <= 0)
            const NoticeBanner(
              message: 'El producto ya no tiene stock suficiente.',
              tone: EzySeverity.warn,
            )
          else
            _AddToCartSection(
              product: product,
              variant: selected,
              onAdded: () => Navigator.of(context).maybePop(),
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

/// Cantidad y botón "Agregar al carrito" del detalle de producto.
///
/// Solo aparece con `pos.create_sale`: la sesión de caja la valida el carrito
/// (y el servidor con `session_required`).
class _AddToCartSection extends ConsumerStatefulWidget {
  const _AddToCartSection({
    required this.product,
    required this.variant,
    required this.onAdded,
  });

  final Product product;
  final VariantCombination? variant;
  final VoidCallback onAdded;

  @override
  ConsumerState<_AddToCartSection> createState() => _AddToCartSectionState();
}

class _AddToCartSectionState extends ConsumerState<_AddToCartSection> {
  double _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final canSell = ref.watch(permissionsProvider).can('pos.create_sale');
    final stock = widget.variant?.stock ?? widget.product.stock;
    final step = widget.product.isBulk ? 0.5 : 1.0;

    if (!canSell) {
      return const NoticeBanner(
        message: 'Tu usuario no tiene permiso para esta acción.',
        tone: EzySeverity.info,
        icon: Icons.lock_outline,
      );
    }

    return SectionCard(
      title: 'Agregar a la venta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Cantidad',
                style: EzyTextStyles.microLabel.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
              const Spacer(),
              _QuantityControl(
                quantity: _quantity,
                measureUnit: widget.product.measureUnit,
                onDecrease: _quantity > step
                    ? () => setState(() => _quantity = _quantity - step)
                    : null,
                onIncrease: _quantity + step <= stock
                    ? () => setState(() => _quantity = _quantity + step)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Total de la línea: '
            '${Money.format(_lineTotal())}',
            style: EzyTextStyles.moneyMedium.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          EzyButton(
            label: 'Agregar al carrito',
            icon: Icons.add_shopping_cart_outlined,
            onPressed: _add,
          ),
        ],
      ),
    );
  }

  double _unitPrice() {
    final variant = widget.variant;
    if (variant != null) {
      return variant.price;
    }

    return widget.product.priceForQuantity(_quantity);
  }

  double _lineTotal() => Money.round2(_unitPrice() * _quantity);

  void _add() {
    ref
        .read(cartControllerProvider.notifier)
        .addProduct(
          widget.product,
          variant: widget.variant,
          quantity: _quantity,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${widget.product.name} agregado al carrito '
          '(${Money.formatQuantity(_quantity)}).',
        ),
      ),
    );

    widget.onAdded();
  }
}

/// Control de cantidad con botones − / +.
class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.measureUnit,
    required this.onDecrease,
    required this.onIncrease,
  });

  final double quantity;
  final String measureUnit;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final unit = measureUnit.isEmpty ? '' : ' $measureUnit';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          onPressed: onDecrease,
          tooltip: 'Quitar una unidad',
          icon: const Icon(Icons.remove, size: 18),
        ),
        Text(
          '${Money.formatQuantity(quantity)}$unit',
          style: EzyTextStyles.bodyStrong.copyWith(
            color: surfaces.textPrimary,
          ),
        ),
        IconButton(
          onPressed: onIncrease,
          tooltip: 'Agregar una unidad',
          icon: const Icon(Icons.add, size: 18),
        ),
      ],
    );
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
            : ServerImage(
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
