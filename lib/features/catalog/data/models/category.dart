import '../../../../core/utils/json_reader.dart';

/// Categoría del catálogo (`GET /catalog/categories`).
class Category {
  const Category({required this.id, required this.name, this.productsCount});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: JsonReader.integerOr(json['id'], 0),
    name: JsonReader.stringOr(json['name'], ''),
    productsCount: JsonReader.integer(json['products_count']),
  );

  final int id;
  final String name;

  /// Número de productos de la categoría (si el servidor lo envía).
  final int? productsCount;

  String get label => name.isEmpty ? 'Categoría $id' : name;
}
