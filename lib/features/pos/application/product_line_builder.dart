import '../../../../core/utils/money.dart';
import '../../catalog/data/models/product.dart';
import '../data/models/cart_line.dart';

/// Convierte un producto del catálogo en una línea del carrito aplicando la
/// regla exacta del contrato §7.2 (variante, mayoreo y promoción de línea).
///
/// Ni el precio ni el stock se recalculan: se eligen entre los valores que ya
/// calculó el servidor para la sucursal del usuario.
class ProductLineBuilder {
  const ProductLineBuilder._();

  /// Línea nueva de [product] con la [variant] elegida (o sin variante).
  static CartLine build(
    Product product, {
    VariantCombination? variant,
    double quantity = 1,
  }) {
    // Variante: precio de lista = selling_price + price_modifier; el precio
    // final (`price`) ya trae el modificador y las promociones aplicadas.
    final listPrice = variant == null
        ? product.sellingPrice
        : Money.round2(product.sellingPrice + variant.priceModifier);
    final basePrice = variant?.price ?? product.price;

    return applyQuantity(
      CartLine(
        productId: product.id,
        productName: product.name,
        variantId: variant?.id,
        variantLabel: variant?.label,
        listPrice: listPrice,
        unitPrice: basePrice,
        quantity: quantity,
        basePrice: basePrice,
        priceTiers: product.priceTiers,
        stockLimit: variant?.stock ?? product.stock,
        measureUnit: product.measureUnit,
        isBulk: product.isBulk,
      ),
      quantity,
    );
  }

  /// Recalcula el precio unitario al cambiar la cantidad (mayoreo).
  static CartLine applyQuantity(CartLine line, double quantity) {
    final unitPrice = Money.round2(line.unitPriceFor(quantity));
    final isTierPrice = line.isTierFor(quantity);
    final reason = CartLine.reasonFor(
      listPrice: line.listPrice,
      unitPrice: unitPrice,
      isTierPrice: isTierPrice,
      isManualPrice: false,
    );

    return line.copyWith(
      quantity: quantity,
      unitPrice: unitPrice,
      isTierPrice: isTierPrice,
      discountReason: reason,
      clearDiscountReason: reason == null,
    );
  }

  /// Línea con precio capturado por el cajero (`pos.edit_prices`).
  static CartLine withManualPrice(CartLine line, double unitPrice) {
    final price = Money.round2(unitPrice < 0 ? 0 : unitPrice);
    final reason = CartLine.reasonFor(
      listPrice: line.listPrice,
      unitPrice: price,
      isTierPrice: false,
      isManualPrice: true,
    );

    return line.copyWith(
      unitPrice: price,
      isManualPrice: true,
      isTierPrice: false,
      discountReason: reason,
      clearDiscountReason: reason == null,
    );
  }
}
