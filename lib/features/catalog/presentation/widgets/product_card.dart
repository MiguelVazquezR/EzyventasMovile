import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/server_image.dart';
import '../../data/models/product.dart';

/// Tarjeta de producto del catálogo: imagen, nombre, precio con promoción,
/// stock de la sucursal y el contador `[-] n [+]` (§9).
///
/// **El contador.** Con el producto fuera del carrito la tarjeta ofrece «+»; con
/// unidades dentro, ese mismo hueco se convierte en el contador `[-] 2 [+]`, así
/// que el cajero ve y corrige la cantidad sin abrir nada. Es compacto (30 px por
/// extremo) porque el del design system (`EzyQuantityStepper`, 40 px) no cabe en
/// una tarjeta de 174 px de ancho; los textos de ayuda son los mismos.
///
/// La tarjeta es **presentacional**: quién está en el carrito y qué se hace al
/// pulsar lo decide quien la usa (la celda del catálogo del POS), no ella.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAdd,
    this.quantity = 0,
    this.onIncrement,
    this.onDecrement,
  });

  final Product product;
  final VoidCallback? onTap;

  /// Agregado rápido de una unidad (solo productos sin variantes y con stock).
  final VoidCallback? onAdd;

  /// Unidades de este producto en el carrito (`0` = sin agregar).
  final double quantity;

  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          // La promoción tiñe el borde de la tarjeta: se distingue sin leer.
          color: product.hasPromotion
              ? EzyColors.primary.withValues(alpha: 0.5)
              : surfaces.border,
        ),
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
              // La imagen cede el espacio que necesita el texto: en la reja de
              // dos columnas del teléfono (174.4 x 256.4 px) un nombre de dos
              // líneas desbordaba el `Column` por 1.1 px
              // (`RenderFlex overflowed by 1.1 pixels on the bottom`).
              Expanded(child: _Thumbnail(product: product)),
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
                    if (onAdd != null || quantity > 0) ...<Widget>[
                      const SizedBox(height: 10),
                      _QuantityControl(
                        quantity: quantity,
                        onAdd: onAdd,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement,
                      ),
                    ],
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

/// Marco de la foto: fondo interior del panel, `BoxFit.contain` y las pastillas
/// de promoción y de stock encima.
///
/// `cardImage` en lugar de `displayImage`: el producto que solo tiene fotos por
/// variante muestra la de su primera combinación en lugar del marcador del
/// servidor.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final image = product.cardImage;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: ColoredBox(
        color: surfaces.panelInner,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8),
              child: image == null || image.isEmpty
                  ? _placeholder(context)
                  : ServerImage(
                      image,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          _placeholder(context),
                    ),
            ),
            if (product.hasPromotion)
              const Positioned(
                top: 8,
                left: 8,
                child: _Badge(
                  label: 'Promo',
                  background: EzyColors.primary,
                  foreground: EzyColors.white,
                ),
              ),
            if (product.isOutOfStock)
              Positioned(
                top: 8,
                right: 8,
                child: _Badge(
                  label: 'Sin stock',
                  background: StatusPalette.soft(EzySeverity.danger),
                  foreground: StatusPalette.text(context, EzySeverity.danger),
                  border: StatusPalette.border(EzySeverity.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Marcador cuando el producto no tiene foto: el icono en el tono mínimo, sin
  /// inventar una imagen que no existe.
  Widget _placeholder(BuildContext context) => Center(
    child: Icon(
      Icons.image_outlined,
      size: 32,
      color: context.surfaces.textMuted,
    ),
  );
}


/// Control de cantidad de la tarjeta, alineado a la derecha del pie.
///
/// Sin permiso de venta (`onAdd` nulo) no se pinta nada: la tarjeta no ofrece una
/// acción que el servidor vaya a rechazar. Con el carrito a cero muestra el «+»;
/// con unidades, el contador `[-] n [+]`.
class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
  });

  final double quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    if (onAdd == null) {
      return const SizedBox.shrink();
    }

    if (quantity <= 0) {
      return Align(
        alignment: Alignment.centerRight,
        child: Tooltip(
          message: 'Agregar al carrito',
          child: GestureDetector(
            onTap: onAdd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: EzyColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 20, color: EzyColors.white),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          color: surfaces.panelInner,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: surfaces.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _StepButton(
              icon: Icons.remove,
              tooltip: 'Quitar una unidad',
              color: surfaces.textSecondary,
              onTap: onDecrement,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                Money.formatQuantity(quantity),
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              tooltip: 'Agregar una unidad',
              color: EzyColors.primary,
              onTap: onIncrement,
            ),
          ],
        ),
      ),
    );
  }
}

/// Extremo del contador: 30 px de lado, icono de 16 y tono mínimo si la acción
/// está desactivada (así el control no cambia de tamaño entre estados).
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 30,
          height: 30,
          child: Icon(
            icon,
            size: 16,
            color: onTap == null ? context.surfaces.textMuted : color,
          ),
        ),
      ),
    );
  }
}


/// Precio de venta y, si hay promoción, el de lista tachado al lado.
class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // Flexible: con la letra agrandada (hasta 1.3x) el monto y el precio de
        // lista tachado no caben en la columna de 174 px y la fila desbordaba
        // (`RenderFlex overflowed by 0.95 pixels on the right`, visto en la
        // prueba de la tarjeta con escala de texto 1.3).
        Flexible(
          child: Text(
            Money.format(product.price),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.moneyList.copyWith(
              fontSize: 16,
              // El precio en promoción se pinta con el naranja de la marca.
              color: product.hasPromotion
                  ? EzyColors.primary
                  : surfaces.textPrimary,
            ),
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

/// Stock de la sucursal: verde con existencias, rojo agotado.
///
/// El color del stock es el semáforo de la tarjeta (el resto del texto ya es
/// alto/medio/bajo) y la unidad sale del catálogo (`pz`, `kg`).
class _StockLine extends StatelessWidget {
  const _StockLine({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final severity = product.isOutOfStock
        ? EzySeverity.danger
        : EzySeverity.success;
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
            style: EzyTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Pastilla de estado sobre la foto (promoción, agotado).
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

