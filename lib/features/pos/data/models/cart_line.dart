import '../../../../core/utils/money.dart';
import '../../../catalog/data/models/product.dart';

/// Línea del carrito del POS.
///
/// Reglas del contrato §7.2:
/// - `listPrice` es el precio de lista por unidad (`original_price`), el que se
///   tacha cuando hay promoción o descuento.
/// - `unitPrice` es el precio final por unidad (promoción, mayoreo o captura
///   manual con `pos.edit_prices`).
/// - `discount` se envía **por unidad**: `listPrice - unitPrice` (nunca
///   negativo; si el precio subió se manda `0` y el motivo "Aumento manual").
/// - `subtotal = Σ(listPrice × quantity)`,
///   `total_discount = Σ(discount × quantity)`, `total = subtotal - total_discount`
///   (idéntico a `ShoppingCart.vue`).
class CartLine {
  const CartLine({
    required this.productId,
    required this.productName,
    required this.listPrice,
    required this.unitPrice,
    required this.quantity,
    this.basePrice,
    this.priceTiers = const <PriceTier>[],
    this.variantId,
    this.variantLabel,
    this.discountReason,
    this.isManualPrice = false,
    this.isTierPrice = false,
    this.stockLimit = 0,
    this.measureUnit = '',
    this.isBulk = false,
  });

  final int productId;
  final String productName;

  /// `variant_combinations[].id` (`product_attribute_id`), o `null`.
  final int? variantId;

  /// `Talla M · Color Azul`, solo para mostrar y para la descripción enviada.
  final String? variantLabel;

  /// Precio de lista por unidad (sin promoción ni descuento).
  final double listPrice;

  /// Precio final por unidad que se cobra.
  final double unitPrice;

  final double quantity;

  /// Precio sin mayoreo: `products.price` o `variant_combinations[].price`.
  /// Es el que se usa al recalcular cuando cambia la cantidad.
  final double? basePrice;

  /// Escalones de precio del producto (`price_tiers`), evaluados por cantidad.
  final List<PriceTier> priceTiers;

  /// `Promoción de producto` | `Precio de mayoreo` | `Descuento manual` |
  /// `Aumento manual` | `null`.
  final String? discountReason;

  /// Precio capturado por el cajero (`pos.edit_prices`).
  final bool isManualPrice;

  /// El precio de la línea salió de `price_tiers` con la cantidad actual.
  final bool isTierPrice;

  /// Stock disponible de la sucursal (tope de cantidad).
  final double stockLimit;

  final String measureUnit;

  /// Producto a granel: la cantidad admite decimales.
  final bool isBulk;

  /// Motivo del descuento según la regla del POS web.
  static String? reasonFor({
    required double listPrice,
    required double unitPrice,
    required bool isTierPrice,
    required bool isManualPrice,
  }) {
    if (isManualPrice) {
      if (unitPrice < listPrice) {
        return 'Descuento manual';
      }

      return unitPrice > listPrice ? 'Aumento manual' : null;
    }

    if (unitPrice >= listPrice) {
      return null;
    }

    return isTierPrice ? 'Precio de mayoreo' : 'Promoción de producto';
  }

  /// Precio por unidad que corresponde a [quantity], con mayoreo incluido.
  ///
  /// Con precio manual o sin escalones, devuelve el precio vigente.
  double unitPriceFor(double quantity) {
    if (isManualPrice || priceTiers.isEmpty) {
      return unitPrice;
    }

    return tierFor(quantity) ?? basePrice ?? unitPrice;
  }

  /// `true` si [quantity] cae en un escalón de mayoreo más barato.
  bool isTierFor(double quantity) {
    final tier = tierFor(quantity);
    final base = basePrice ?? unitPrice;

    return tier != null && tier < base;
  }

  /// Precio del escalón con el `min_quantity` más alto que cumpla la cantidad.
  double? tierFor(double quantity) {
    PriceTier? best;

    for (final tier in priceTiers) {
      if (quantity >= tier.minQuantity &&
          (best == null || tier.minQuantity > best.minQuantity)) {
        best = tier;
      }
    }

    return best?.price;
  }

  /// `listPrice - unitPrice` por unidad, nunca negativo.
  double get discountPerUnit => Money.round2(
    listPrice > unitPrice ? listPrice - unitPrice : 0,
  );

  /// Subtotal de la línea con precio de lista (base del descuento).
  double get lineSubtotal => Money.round2(listPrice * quantity);

  /// Descuento total de la línea.
  double get lineDiscount => Money.round2(discountPerUnit * quantity);

  /// Lo que se cobra por la línea.
  double get lineTotal => Money.round2(unitPrice * quantity);

  bool get hasDiscount => discountPerUnit > 0;

  /// Descripción que viaja al servidor (el servidor la reescribe con el nombre
  /// real del producto o de su variante).
  String get description {
    final label = variantLabel;
    return (label == null || label.isEmpty)
        ? productName
        : '$productName ($label)';
  }

  bool get isOutOfStock => stockLimit <= 0;

  /// La cantidad pedida rebasa el stock de la sucursal.
  bool exceedsStock(double quantity) => stockLimit > 0 && quantity > stockLimit;

  /// Misma variante del mismo producto: la línea se acumula en lugar de
  /// duplicarse dentro del carrito.
  bool matches(CartLine other) =>
      productId == other.productId &&
      variantId == other.variantId &&
      !other.isManualPrice;

  /// Línea del carrito tal como la espera el servidor.
  Map<String, dynamic> toCartItemJson() => <String, dynamic>{
    'id': productId,
    'product_attribute_id': variantId,
    'quantity': Money.round2(quantity),
    'unit_price': Money.round2(unitPrice),
    'description': description,
    'discount': discountPerUnit,
    'discount_reason': discountPerUnit > 0 ? discountReason : null,
  };

  CartLine copyWith({
    double? listPrice,
    double? unitPrice,
    double? quantity,
    String? discountReason,
    bool? isManualPrice,
    bool? isTierPrice,
    bool clearDiscountReason = false,
  }) {
    return CartLine(
      productId: productId,
      productName: productName,
      variantId: variantId,
      variantLabel: variantLabel,
      listPrice: listPrice ?? this.listPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      basePrice: basePrice,
      priceTiers: priceTiers,
      discountReason: clearDiscountReason
          ? null
          : (discountReason ?? this.discountReason),
      isManualPrice: isManualPrice ?? this.isManualPrice,
      isTierPrice: isTierPrice ?? this.isTierPrice,
      stockLimit: stockLimit,
      measureUnit: measureUnit,
      isBulk: isBulk,
    );
  }
}
