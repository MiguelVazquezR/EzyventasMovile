import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Producto del catálogo (`GET /catalog/products`).
///
/// Tipos confirmados contra la API real:
/// - `selling_price`: **texto decimal** (`"3900.00"`)
/// - `price` / `original_price`: **número** (`3900`)
/// - `stock` / `reserved_stock`: número
/// - `variants`: objeto `{ "Talla": [{value, stock}] }`
///
/// El precio final y el stock los calcula el servidor para la sucursal del
/// usuario: la app nunca los recalcula.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.description,
    required this.category,
    required this.image,
    required this.generalImages,
    required this.sellingPrice,
    required this.price,
    required this.originalPrice,
    required this.priceTiers,
    required this.stock,
    required this.reservedStock,
    required this.showInPos,
    required this.isBulk,
    required this.measureUnit,
    required this.promotions,
    required this.variants,
    required this.variantCombinations,
    required this.components,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    sku: JsonReader.string(json['sku']),
    description: JsonReader.string(json['description']),
    category: JsonReader.string(json['category']),
    image: JsonReader.string(json['image']),
    generalImages: JsonReader.stringList(json['general_images']),
    sellingPrice: Money.toDouble(json['selling_price']),
    price: Money.toDouble(json['price']),
    originalPrice: Money.toDouble(json['original_price']),
    priceTiers: JsonReader.toMapList(
      json['price_tiers'],
    ).map(PriceTier.fromJson).toList(growable: false),
    stock: Money.toDouble(json['stock']),
    reservedStock: Money.toDouble(json['reserved_stock']),
    showInPos: JsonReader.boolean(json['show_in_pos']),
    isBulk: JsonReader.boolean(json['is_bulk']),
    measureUnit: JsonReader.stringOr(json['measure_unit'], ''),
    promotions: JsonReader.toMapList(
      json['promotions'],
    ).map(ProductPromotion.fromJson).toList(growable: false),
    variants: parseVariants(json['variants']),
    variantCombinations: JsonReader.toMapList(
      json['variant_combinations'],
    ).map(VariantCombination.fromJson).toList(growable: false),
    components: JsonReader.toMapList(
      json['components'],
    ).map(ProductComponent.fromJson).toList(growable: false),
  );

  /// `variants` es un mapa atributo → valores.
  static Map<String, List<VariantValue>> parseVariants(Object? raw) {
    final result = <String, List<VariantValue>>{};

    JsonReader.toMap(raw).forEach((attribute, values) {
      result[attribute] = JsonReader.toMapList(
        values,
      ).map(VariantValue.fromJson).toList(growable: false);
    });

    return result;
  }

  final int id;
  final String name;
  final String? sku;
  final String? description;

  /// Nombre de la categoría (el servidor envía el nombre, no el id).
  final String? category;
  final String? image;
  final List<String> generalImages;

  /// `products.selling_price` (precio de lista, texto decimal).
  final double sellingPrice;

  /// Precio final tras promociones de línea.
  final double price;
  final double originalPrice;
  final List<PriceTier> priceTiers;

  /// `current_stock - reserved_stock` de la sucursal.
  final double stock;
  final double reservedStock;
  final bool showInPos;
  final bool isBulk;
  final String measureUnit;
  final List<ProductPromotion> promotions;

  /// Atributos disponibles (informativo).
  final Map<String, List<VariantValue>> variants;

  /// Combinaciones vendibles (`product_attribute_id`).
  final List<VariantCombination> variantCombinations;

  /// Insumos de un kit.
  final List<ProductComponent> components;

  bool get hasVariants => variantCombinations.isNotEmpty;

  bool get hasPromotion => price < originalPrice;

  bool get hasPriceTiers => priceTiers.isNotEmpty;

  bool get isOutOfStock => stock <= 0 && !hasVariants;

  /// Precio por volumen: el tier con el mayor `min_quantity` que la cantidad
  /// alcanza (§7.2.4 del documento maestro).
  double priceForQuantity(double quantity) {
    var result = price;

    for (final tier in priceTiers) {
      if (quantity >= tier.minQuantity) {
        result = tier.price;
      }
    }

    return result;
  }

  /// Host del marcador que el servidor pone en `image` cuando el producto no
  /// tiene fotos propias (`ProductCatalogService::payload` → `placehold.co`).
  ///
  /// Se trata como «sin imagen»: así el producto que solo trae fotos por
  /// variante (`product-variant-images`) no pinta el cuadro gris del servicio y
  /// puede caer a la imagen de su variante (como hace la tarjeta de la web).
  static const String placeholderHost = 'placehold.co';

  /// URL utilizable de un medio (`null` si viene vacía o es el marcador del
  /// servidor).
  static String? cleanImage(String? url) {
    final value = url?.trim() ?? '';

    if (value.isEmpty || value.contains(placeholderHost)) {
      return null;
    }

    return value;
  }

  /// Imagen a mostrar: la del producto o la primera de la galería.
  String? get displayImage {
    final own = cleanImage(image);

    if (own != null) {
      return own;
    }

    for (final url in generalImages) {
      final value = cleanImage(url);

      if (value != null) {
        return value;
      }
    }

    return null;
  }

  /// Imágenes propias del producto para la galería del detalle, **sin repetir**:
  /// el servidor manda la portada también dentro de `general_images`, así que
  /// ese producto de dos fotos se recorre con dos páginas, no con tres.
  List<String> get galleryImages {
    final result = <String>[];

    for (final url in <String?>[image, ...generalImages]) {
      final value = cleanImage(url);

      if (value != null && !result.contains(value)) {
        result.add(value);
      }
    }

    return result;
  }

  /// Imagen de la tarjeta del catálogo: las fotos propias o, cuando el producto
  /// solo tiene imágenes por variante, la de la primera combinación con foto
  /// (la web hace lo mismo en su tarjeta).
  String? get cardImage {
    final own = displayImage;

    if (own != null) {
      return own;
    }

    for (final combination in variantCombinations) {
      final value = cleanImage(combination.imageUrl);

      if (value != null) {
        return value;
      }
    }

    return null;
  }
}

/// Precio por volumen.
class PriceTier {
  const PriceTier({required this.minQuantity, required this.price});

  factory PriceTier.fromJson(Map<String, dynamic> json) => PriceTier(
    minQuantity: Money.toDouble(json['min_quantity']),
    price: Money.toDouble(json['price']),
  );

  final double minQuantity;
  final double price;
}

/// Valor de un atributo (`{"value": "M", "stock": 3}`).
class VariantValue {
  const VariantValue({required this.value, required this.stock});

  factory VariantValue.fromJson(Map<String, dynamic> json) => VariantValue(
    value: JsonReader.stringOr(json['value'], ''),
    stock: Money.toDouble(json['stock']),
  );

  final String value;
  final double stock;
}

/// Combinación vendible de atributos (`variant_combinations[]`).
///
/// `price` ya viene calculado por el servidor (`selling_price + price_modifier`
/// y luego promociones): la app no vuelve a sumar nada.
class VariantCombination {
  const VariantCombination({
    required this.id,
    required this.attributes,
    required this.priceModifier,
    required this.price,
    required this.skuSuffix,
    required this.stock,
    required this.reservedStock,
    required this.imageUrl,
  });

  factory VariantCombination.fromJson(Map<String, dynamic> json) {
    final attributes = <String, String>{};
    JsonReader.toMap(json['attributes']).forEach((key, value) {
      attributes[key] = '${value ?? ''}';
    });

    return VariantCombination(
      id: JsonReader.integerOr(json['id'], 0),
      attributes: attributes,
      priceModifier: Money.toDouble(json['price_modifier']),
      price: Money.toDouble(json['price']),
      skuSuffix: JsonReader.string(json['sku_suffix']),
      stock: Money.toDouble(json['stock']),
      reservedStock: Money.toDouble(json['reserved_stock']),
      imageUrl: JsonReader.string(json['image_url']),
    );
  }

  final int id;
  final Map<String, String> attributes;
  final double priceModifier;
  final double price;
  final String? skuSuffix;
  final double stock;
  final double reservedStock;
  final String? imageUrl;

  /// `Talla M · Color Azul`
  String get label => attributes.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join(' · ');

  bool get isOutOfStock => stock <= 0;
}

/// Promoción aplicada a la línea (informativa).
class ProductPromotion {
  const ProductPromotion({
    required this.name,
    required this.type,
    required this.description,
  });

  factory ProductPromotion.fromJson(Map<String, dynamic> json) =>
      ProductPromotion(
        name: JsonReader.stringOr(json['name'], ''),
        type: JsonReader.string(json['type']),
        description: JsonReader.string(json['description']),
      );

  final String name;
  final String? type;
  final String? description;

  /// Texto corto para el badge de la tarjeta.
  String get label => (description != null && description!.isNotEmpty)
      ? description!
      : name;
}

/// Insumo de un kit (`components[]`).
class ProductComponent {
  const ProductComponent({
    required this.id,
    required this.componentId,
    required this.componentType,
    required this.name,
    required this.quantity,
  });

  factory ProductComponent.fromJson(Map<String, dynamic> json) =>
      ProductComponent(
        id: JsonReader.integerOr(json['id'], 0),
        componentId: JsonReader.integer(json['component_id']),
        componentType: JsonReader.string(json['component_type']),
        name: JsonReader.stringOr(json['name'], ''),
        quantity: Money.toDouble(json['quantity']),
      );

  final int id;
  final int? componentId;
  final String? componentType;
  final String name;
  final double quantity;
}
