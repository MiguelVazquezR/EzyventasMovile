import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/html_text.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_amount.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_quantity_stepper.dart';
import '../../../../core/widgets/ezy_selectable_tile.dart';
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
  return EzyBottomSheet.show<void>(
    context,
    maxHeightFactor: 0.96,
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EzySheetHeader(
          title: product.name,
          subtitle: _subtitle(product),
          trailing: EzyIconButton(
            icon: Icons.close,
            tooltip: 'Cerrar',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              ProductGallery(
                images: product.galleryImages,
                overrideImage: selected?.imageUrl,
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
                        EzySelectableTile(
                          title: combination.label,
                          subtitle: combination.isOutOfStock
                              ? 'Sin stock'
                              : '${Money.formatQuantity(combination.stock)} '
                                    'disponibles',
                          subtitleColor: combination.isOutOfStock
                              ? StatusPalette.text(context, EzySeverity.danger)
                              : null,
                          value: Money.format(combination.price),
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
                    style: EzyTextStyles.body.copyWith(
                      color: surfaces.textBody,
                    ),
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
        ),
      ],
    );
  }

  /// `SKU FIL-001 · Filtros` bajo el nombre; `null` si el producto no trae ni SKU
  /// ni categoría. La hoja completa los datos con `GET /catalog/products/{id}`, así
  /// que la línea puede cambiar después de abrir el sheet.
  String? _subtitle(Product product) {
    final parts = <String>[
      if (product.sku != null && product.sku!.isNotEmpty) 'SKU ${product.sku}',
      if (product.category != null && product.category!.isNotEmpty)
        product.category!,
    ];

    return parts.isEmpty ? null : parts.join(' · ');
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
              EzyQuantityStepper(
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
          const SizedBox(height: 16),
          EzyAmount(
            value: _lineTotal(),
            label: 'Total de la línea',
            size: EzyAmountSize.large,
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

/// Una imagen del producto **sin recortarla** (`BoxFit.contain`): la foto se ve
/// completa sobre el fondo interior de la superficie —igual que el
/// `object-contain` de la web— y con el marcador de la pantalla cuando la foto
/// no carga o no existe.
class ProductImage extends StatelessWidget {
  const ProductImage({super.key, required this.image});

  final String? image;

  @override
  Widget build(BuildContext context) {
    if ((image ?? '').trim().isEmpty) {
      return const ImagePlaceholder();
    }

    return ServerImage(
      image,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => const ImagePlaceholder(),
    );
  }
}

/// Flecha circular sobre la galería (misma lectura que los botones de la web).
class _GalleryArrow extends StatelessWidget {
  const _GalleryArrow({
    required this.alignment,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final Alignment alignment;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Material(
          color: surfaces.panel.withValues(alpha: 0.85),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Tooltip(
              message: tooltip,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(icon, size: 20, color: surfaces.textPrimary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Punto que indica cuál de las imágenes de la galería se está viendo.
class _GalleryDot extends StatelessWidget {
  const _GalleryDot({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: isActive ? 18 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: isActive ? EzyColors.primary : surfaces.borderStrong,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Galería del detalle de producto: recorre **todas** las fotos del producto con
/// deslizamiento, flechas y puntos (la web las llama `general_images`).
///
/// [overrideImage] es la foto de la variante elegida
/// (`variant_combinations[].image_url`): cuando existe se pinta la primera, así
/// al elegir «Talla M» el detalle muestra la foto de esa variante y al volver a
/// una sin foto propia se regresa a las del producto. Es la misma prioridad que
/// resuelve `ProductDetailModal.vue` en la web.
class ProductGallery extends StatefulWidget {
  const ProductGallery({
    super.key,
    required this.images,
    this.overrideImage,
    this.aspectRatio = 16 / 10,
  });

  /// Imágenes propias del producto, en orden (`Product.galleryImages`).
  final List<String> images;

  /// Imagen de la variante seleccionada, si tiene una propia.
  final String? overrideImage;

  /// Proporción de la caja de la galería.
  final double aspectRatio;

  /// Arma las páginas: primero la imagen de la variante (si trae) y después las
  /// del producto, **sin repetir** ninguna URL.
  static List<String> resolveImages(
    Iterable<String?> images, {
    String? overrideImage,
  }) {
    final result = <String>[];

    void add(String? url) {
      final value = Product.cleanImage(url);

      if (value != null && !result.contains(value)) {
        result.add(value);
      }
    }

    add(overrideImage);
    images.forEach(add);

    return result;
  }

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final PageController _controller = PageController();
  int _index = 0;

  List<String> get _images => ProductGallery.resolveImages(
    widget.images,
    overrideImage: widget.overrideImage,
  );

  @override
  void didUpdateWidget(covariant ProductGallery oldWidget) {
    super.didUpdateWidget(oldWidget);

    final before = ProductGallery.resolveImages(
      oldWidget.images,
      overrideImage: oldWidget.overrideImage,
    );

    // Al cambiar de variante (o cuando termina de llegar el detalle completo) la
    // galería vuelve a su primera página para que se vea la foto nueva. Se
    // difiere al final del frame: mover el `PageController` durante el build
    // tocaría el `ScrollPosition` a medio construir.
    if (!listEquals(before, _images)) {
      _index = 0;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final count = _images.length;

    if (count < 2) {
      return;
    }

    // La web da la vuelta en los extremos (`prevImage`/`nextImage`).
    _controller.animateToPage(
      (_index + delta + count) % count,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final images = _images;

    if (images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: const ImagePlaceholder(),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: ColoredBox(
          color: surfaces.panelInner,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) =>
                    ProductImage(image: images[index]),
              ),
              if (images.length > 1) ...<Widget>[
                _GalleryArrow(
                  alignment: Alignment.centerLeft,
                  icon: Icons.chevron_left,
                  tooltip: 'Imagen anterior',
                  onTap: () => _move(-1),
                ),
                _GalleryArrow(
                  alignment: Alignment.centerRight,
                  icon: Icons.chevron_right,
                  tooltip: 'Imagen siguiente',
                  onTap: () => _move(1),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      for (var index = 0; index < images.length; index++)
                        _GalleryDot(
                          key: Key('gallery-dot-$index'),
                          isActive: index == _index,
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
    final surfaces = context.surfaces;

    return ColoredBox(
      color: surfaces.panelInner,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 32,
          color: surfaces.textMuted,
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
          EzyAmount(value: price, size: EzyAmountSize.hero),
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
