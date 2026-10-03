import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/html_text.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
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
    // §1: la hoja se apoya en el lienzo, con el radio superior de 24 px del
    // design system y con el asa que pinta `_SheetGrabber` (el tema la pinta en
    // gris; aquí va con el borde fuerte de la superficie).
    backgroundColor: context.surfaces.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    showDragHandle: false,
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
        // §1: asa de arrastre + cabecera fija. Fuera del scroll: el nombre del
        // producto y su SKU no se pierden al bajar por las secciones.
        const _SheetGrabber(),
        _ProductDetailHeader(
          title: product.name,
          subtitle: _subtitle(product),
          onClose: () => Navigator.of(context).maybePop(),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: <Widget>[
              ProductGallery(
                images: product.galleryImages,
                overrideImage: selected?.imageUrl,
              ),
              const SizedBox(height: 16),
              ProductPriceBlock(product: product, price: price, stock: stock),
              if (product.hasVariants) ...<Widget>[
                const SizedBox(height: 12),
                _VariantsCard(
                  combinations: product.variantCombinations,
                  selectedId: selected?.id,
                  onSelect: (id) => setState(() => _selectedCombinationId = id),
                ),
              ],
              if (description.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _DetailCard(
                  title: 'DESCRIPCIÓN',
                  titleSize: 11,
                  child: Text(
                    description,
                    style: EzyTextStyles.body.copyWith(
                      fontSize: 12.5,
                      height: 1.45,
                      color: surfaces.textBody,
                    ),
                  ),
                ),
              ],
              if (product.components.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                _DetailCard(
                  title: 'INCLUYE EN EL PAQUETE',
                  titleSize: 11,
                  child: Column(
                    children: <Widget>[
                      for (final component in product.components)
                        _ComponentRow(component: component),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // §5: la zona de acción vive fija al pie, fuera del scroll —el CTA no se
        // busca bajando—. Los banners de bloqueo y la card de cantidad los pone
        // `_AddToCartSection`.
        _ActionFooter(
          child: _AddToCartSection(
            product: product,
            variant: selected,
            onAdded: () => Navigator.of(context).maybePop(),
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

    // §5: los dos bloqueos se anuncian con su banner y el pie se queda sin CTA.
    if (!canSell) {
      return const NoticeBanner(
        title: 'Acción restringida',
        message: 'Tu usuario no tiene permiso para esta acción.',
        tone: EzySeverity.info,
        icon: Icons.lock_outline,
      );
    }

    if (stock <= 0) {
      return const NoticeBanner(
        title: 'Stock agotado',
        message: 'El producto ya no tiene stock suficiente.',
        tone: EzySeverity.warn,
      );
    }

    return SectionCard(
      title: 'Agregar a la venta',
      // §5: flota en el pie, como el resto de tarjetas del lienzo.
      boxShadow: EzyColors.cardShadow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              EzyQuantityStepper(
                quantity: _quantity,
                measureUnit: widget.product.measureUnit,
                // §5: el stepper del detalle va en caja (radio 12 px, fondo
                // `panelInner` y borde fuerte) con el «+» resaltado en marca.
                style: EzyQuantityStepperStyle.box,
                onDecrease: _quantity > step
                    ? () => setState(() => _quantity = _quantity - step)
                    : null,
                onIncrease: _quantity + step <= stock
                    ? () => setState(() => _quantity = _quantity + step)
                    : null,
              ),
              const SizedBox(width: 12),
              // Total de la línea: rótulo micro arriba y el monto en el naranja
              // de marca, pegado al borde derecho. El bloque se queda con el
              // ancho que sobra y no con su ancho natural: en un teléfono
              // estrecho el monto se encoge en lugar de desbordar el renglón.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'TOTAL DE LA LÍNEA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.microLabel.copyWith(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        color: surfaces.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        Money.format(_lineTotal()),
                        style: EzyTextStyles.moneyMedium.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: EzyColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          EzyPrimary3dButton(
            label: 'Agregar al carrito',
            icon: Icons.shopping_cart_outlined,
            height: 52,
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
        child: Tooltip(
          message: tooltip,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                // §2: la flecha flota sobre la foto con el panel al 85 %, el
                // borde sutil y una sombra baja que la despega del lienzo.
                color: surfaces.panel.withValues(alpha: 0.85),
                shape: BoxShape.circle,
                border: Border.all(color: surfaces.border),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: EzyColors.black2.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: surfaces.textPrimary),
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
      // §2: el activo se expande a 16×6; los inactivos son puntos de 6×6.
      width: isActive ? 16 : 6,
      height: 6,
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

    return Container(
      // §2: pieza de 16:10 con el fondo interior de la superficie, borde de
      // 1 px y esquinas de 16 px.
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: images.isEmpty
            ? const ImagePlaceholder()
            : Stack(
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
                    // §2: los puntos viven en una cápsula en la esquina
                    // inferior derecha de la galería.
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: EzyColors.black2.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (var index = 0; index < images.length; index++)
                              _GalleryDot(
                                key: Key('gallery-dot-$index'),
                                isActive: index == _index,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Marcador del producto sin foto: icono centrado sobre un halo de marca sutil
/// (§2 del rediseño).
class ImagePlaceholder extends StatelessWidget {
  const ImagePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        gradient: RadialGradient(
          colors: <Color>[
            EzyColors.primary.withValues(alpha: 0.12),
            EzyColors.primary.withValues(alpha: 0),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 34,
          color: surfaces.textMuted,
        ),
      ),
    );
  }
}

/// Bloque de precio (§3): monto vigente, disponibilidad, promoción activa y
/// precios de mayoreo.
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

    return _DetailCard(
      // §3: la pieza flota sobre el lienzo de la hoja.
      boxShadow: EzyColors.cardShadow,
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
                      'PRECIO UNITARIO',
                      style: EzyTextStyles.microLabel.copyWith(
                        fontSize: 10.5,
                        color: surfaces.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            Money.format(price),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EzyTextStyles.moneyLarge.copyWith(
                              fontSize: 29,
                              fontWeight: FontWeight.w900,
                              color: EzyColors.primary,
                            ),
                          ),
                        ),
                        // §3: el precio de lista tachado solo cuando la
                        // promoción lo bajó (`price < original_price`).
                        if (product.hasPromotion) ...<Widget>[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                'Antes ${Money.format(product.originalPrice)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: EzyTextStyles.secondary.copyWith(
                                  fontSize: 13,
                                  color: surfaces.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: surfaces.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AvailabilityChip(stock: stock, measureUnit: product.measureUnit),
            ],
          ),
          if (product.promotions.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _PromotionBanner(
              promotion: product.promotions.first,
              price: price,
              originalPrice: product.originalPrice,
            ),
          ],
          if (product.hasPriceTiers) ...<Widget>[
            const SizedBox(height: 14),
            _WholesalePrices(product: product, price: price),
          ],
        ],
      ),
    );
  }
}

/// Card del detalle de producto: panel, radio 16 px, borde de 1 px y padding
/// compacto (§3–§4 del rediseño). Sustituye a `SectionCard` —radio 24— en las
/// piezas del detalle, donde el diseño pide 16.
class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.child,
    this.title,
    this.trailing,
    this.boxShadow,
    this.titleSize = 12,
  });

  final Widget child;

  /// Título de la card, tal como se pinta (las secciones lo pasan ya en
  /// MAYÚSCULAS: es el registro del design system).
  final String? title;

  /// Acción o badge a la derecha del título (`N opciones`).
  final Widget? trailing;

  /// Sombra cuando la pieza flota sobre el lienzo de la hoja.
  final List<BoxShadow>? boxShadow;

  final double titleSize;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
        boxShadow: boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title!,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      color: surfaces.textPrimary,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

/// Asa de arrastre de la hoja: 40×5 px en el borde fuerte de la superficie.
class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      decoration: BoxDecoration(
        color: context.surfaces.borderStrong,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Cabecera fija del detalle: nombre, badge `En Catálogo`, `SKU · categoría` y
/// cierre. Vive fuera del scroll para que el nombre no se pierda al bajar (§1).
class _ProductDetailHeader extends StatelessWidget {
  const _ProductDetailHeader({
    required this.title,
    this.subtitle,
    required this.onClose,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      decoration: BoxDecoration(
        color: surfaces.panel,
        border: Border(bottom: BorderSide(color: surfaces.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.bodyStrong.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: surfaces.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _CatalogBadge(),
                  ],
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: EzyTextStyles.secondary.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: surfaces.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CloseChip(onTap: onClose),
        ],
      ),
    );
  }
}

/// Badge «En Catálogo»: verde de estado muy tenue (§1).
class _CatalogBadge extends StatelessWidget {
  const _CatalogBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: EzyColors.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'En Catálogo',
        style: EzyTextStyles.badge.copyWith(
          fontSize: 10.5,
          letterSpacing: 0.2,
          color: StatusPalette.text(context, EzySeverity.success),
        ),
      ),
    );
  }
}

/// Cierre de la hoja: blanco táctil de 32 px con el borde fuerte (§1).
class _CloseChip extends StatelessWidget {
  const _CloseChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Tooltip(
      message: 'Cerrar',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: surfaces.panelInner,
            shape: BoxShape.circle,
            border: Border.all(color: surfaces.borderStrong),
          ),
          child: Icon(Icons.close, size: 18, color: surfaces.textSecondary),
        ),
      ),
    );
  }
}

/// Pie fijo del detalle: la barra de acciones del design system más la sombra
/// de elevación que la despega del contenido que scrollea (§5).
class _ActionFooter extends StatelessWidget {
  const _ActionFooter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: EzyColors.black2.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: EzyActionBar(child: child),
    );
  }
}

/// Chip de disponibilidad del bloque de precio (§3): micro-etiqueta, punto de
/// estado y las piezas que la sucursal tiene disponibles.
class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.stock, required this.measureUnit});

  final double stock;
  final String measureUnit;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final outOfStock = stock <= 0;
    final label = outOfStock
        ? 'Sin stock disponible'
        : '${Money.formatQuantity(stock)} $measureUnit disponibles'.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Text(
          'DISPONIBILIDAD',
          style: EzyTextStyles.microLabel.copyWith(
            fontSize: 10.5,
            color: surfaces.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: StatusPalette.soft(EzySeverity.neutral),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: StatusPalette.border(EzySeverity.neutral),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: outOfStock ? EzyColors.danger : EzyColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: EzyTextStyles.caption.copyWith(
                  fontSize: 11.5,
                  color: outOfStock
                      ? StatusPalette.text(context, EzySeverity.danger)
                      : surfaces.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Banner de la promoción activa (§3): etiqueta, ahorro por pieza y badge con
/// el porcentaje del descuento.
class _PromotionBanner extends StatelessWidget {
  const _PromotionBanner({
    required this.promotion,
    required this.price,
    required this.originalPrice,
  });

  final ProductPromotion promotion;
  final double price;
  final double originalPrice;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final saving = Money.round2(originalPrice - price);
    final percent = originalPrice > 0
        ? ((saving / originalPrice) * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: EzyColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: EzyColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: EzyColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              size: 14,
              color: EzyColors.white,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  promotion.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: surfaces.textPrimary,
                  ),
                ),
                if (saving > 0) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    'Ahorras ${Money.format(saving)} por pieza',
                    style: EzyTextStyles.secondary.copyWith(
                      fontSize: 11,
                      color: surfaces.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (percent > 0) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: EzyColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '-$percent%',
                style: EzyTextStyles.badge.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 0,
                  color: EzyColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Escala de mayoreo (§3): la tarjeta base con el rango regular y una tarjeta
/// por nivel de precio. La app no recalcula nada: pinta `price_tiers`.
class _WholesalePrices extends StatelessWidget {
  const _WholesalePrices({required this.product, required this.price});

  final Product product;
  final double price;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final tiers = product.priceTiers;
    final first = tiers.first.minQuantity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Text(
                'Precios de Mayoreo',
                style: EzyTextStyles.bodyStrong.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: surfaces.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Aplica en caja automáticamente',
              style: EzyTextStyles.secondary.copyWith(
                fontSize: 11,
                color: surfaces.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 8.0;
            final cards = tiers.length + 1;
            final columns = cards < 3 ? cards : 3;
            final width =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: <Widget>[
                _TierCard(
                  width: width,
                  range: first > 1
                      ? '1 - ${Money.formatQuantity(first - 1)}'
                      : '1',
                  price: price,
                  caption: 'Precio regular',
                  highlighted: false,
                ),
                for (final tier in tiers)
                  _TierCard(
                    width: width,
                    range: '${Money.formatQuantity(tier.minQuantity)}+',
                    price: tier.price,
                    caption: price > tier.price
                        ? 'Ahorra ${Money.format(price - tier.price)} c/u'
                        : 'Precio de mayoreo',
                    highlighted: true,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Celda de la escala de mayoreo: rango de piezas, precio del nivel y el ahorro
/// por unidad cuando el nivel baja el precio.
class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.width,
    required this.range,
    required this.price,
    required this.caption,
    required this.highlighted,
  });

  final double width;
  final String range;
  final double price;
  final String caption;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: width,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlighted
            ? EzyColors.primary.withValues(alpha: 0.05)
            : surfaces.panelInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? EzyColors.primary.withValues(alpha: 0.40)
              : surfaces.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            range,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.secondary.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: highlighted ? EzyColors.primary : surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(price),
              style: EzyTextStyles.moneyList.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: surfaces.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.secondary.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: highlighted
                  ? StatusPalette.text(context, EzySeverity.success)
                  : surfaces.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de variantes (§4): encabezado con el conteo de opciones y una fila
/// por combinación vendible. La selección es la que manda el servidor: la app
/// solo devuelve el `id` elegido.
class _VariantsCard extends StatelessWidget {
  const _VariantsCard({
    required this.combinations,
    required this.selectedId,
    required this.onSelect,
  });

  final List<VariantCombination> combinations;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'VARIANTES',
      trailing: _CountBadge(label: '${combinations.length} opciones'),
      child: Column(
        children: <Widget>[
          for (final combination in combinations)
            _VariantTile(
              combination: combination,
              isSelected: combination.id == selectedId,
              onTap: () => onSelect(combination.id),
            ),
        ],
      ),
    );
  }
}

/// Badge naranja de conteo del encabezado de una card (`N opciones`, §4).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: EzyColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: EzyColors.primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: EzyTextStyles.badge.copyWith(
          fontSize: 10.5,
          letterSpacing: 0.2,
          color: EzyColors.primary,
        ),
      ),
    );
  }
}

/// Fila de una combinación vendible (§4): la pieza del design system con la
/// etiqueta de la variante, su stock disponible y el precio unitario a la
/// derecha.
class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.combination,
    required this.isSelected,
    required this.onTap,
  });

  final VariantCombination combination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outOfStock = combination.isOutOfStock;

    return EzySelectableTile(
      title: combination.label,
      subtitle: outOfStock
          ? 'Sin stock'
          : '${Money.formatQuantity(combination.stock)} disponibles',
      subtitleColor: outOfStock
          ? StatusPalette.text(context, EzySeverity.danger)
          : null,
      value: Money.format(combination.price),
      isSelected: isSelected,
      onTap: onTap,
    );
  }
}

/// Fila de un insumo del paquete (§4): nombre a la izquierda y cantidad a la
/// derecha en el naranja de marca (`1 pza`, `1 doc`).
class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});

  final ProductComponent component;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final unit = component.componentType == 'document' ? 'doc' : 'pza';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              component.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EzyTextStyles.body.copyWith(
                fontSize: 12.5,
                color: surfaces.textBody,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${Money.formatQuantity(component.quantity)} $unit',
            style: EzyTextStyles.bodyStrong.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: EzyColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
