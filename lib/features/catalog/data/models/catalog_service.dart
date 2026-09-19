import '../../../../core/utils/json_reader.dart';
import '../../../../core/utils/money.dart';

/// Servicio disponible en la sucursal (`GET /catalog/services`).
///
/// `base_price` es **texto decimal** (`"850.00"`). Si el servicio tiene
/// variantes se vende la variante (`variants[].id`), no el servicio base.
class CatalogService {
  const CatalogService({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.basePrice,
    required this.durationEstimate,
    required this.showOnline,
    required this.variants,
  });

  factory CatalogService.fromJson(Map<String, dynamic> json) => CatalogService(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    description: JsonReader.string(json['description']),
    category: JsonReader.string(json['category']),
    basePrice: Money.toDouble(json['base_price']),
    durationEstimate: JsonReader.string(json['duration_estimate']),
    showOnline: JsonReader.boolean(json['show_online']),
    variants: JsonReader.toMapList(
      json['variants'],
    ).map(ServiceVariant.fromJson).toList(growable: false),
  );

  final int id;
  final String name;
  final String? description;
  final String? category;
  final double basePrice;
  final String? durationEstimate;
  final bool showOnline;
  final List<ServiceVariant> variants;

  bool get hasVariants => variants.isNotEmpty;

  /// Precio mínimo útil para ordenar y mostrar ("desde $850.00").
  double get lowestPrice {
    if (variants.isEmpty) {
      return basePrice;
    }

    return variants
        .map((variant) => variant.price)
        .reduce((current, next) => current < next ? current : next);
  }
}

/// Variante de un servicio (material original/compatible, etc.).
class ServiceVariant {
  const ServiceVariant({
    required this.id,
    required this.name,
    required this.price,
    required this.durationEstimate,
  });

  factory ServiceVariant.fromJson(Map<String, dynamic> json) => ServiceVariant(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    price: Money.toDouble(json['price']),
    durationEstimate: JsonReader.string(json['duration_estimate']),
  );

  final int id;
  final String name;
  final double price;
  final String? durationEstimate;
}
