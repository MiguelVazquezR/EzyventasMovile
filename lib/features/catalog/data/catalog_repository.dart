import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/paginated.dart';
import 'models/catalog_service.dart';
import 'models/category.dart';
import 'models/product.dart';

/// Tipo de categoría que acepta `GET /catalog/categories?type=`.
enum CatalogCategoryType {
  product('product'),
  service('service');

  const CatalogCategoryType(this.value);

  final String value;
}

/// Lecturas del catálogo (productos, categorías y servicios).
///
/// Todo lo entrega el servidor filtrado por la sucursal del token: la app no
/// envía `branch_id` ni calcula precios o stock.
class CatalogRepository {
  CatalogRepository({required this.api});

  final ApiClient api;

  /// `GET /catalog/products` con búsqueda y paginación.
  Future<Paginated<Product>> fetchProducts({
    String? search,
    int? categoryId,
    int page = 1,
    int perPage = 20,
    String? updatedSince,
  }) async {
    final data = await api.getJson(
      ApiEndpoints.products,
      query: <String, dynamic>{
        'search': search,
        'category_id': categoryId,
        'page': page,
        'per_page': perPage,
        'updated_since': updatedSince,
      },
    );

    return Paginated<Product>.fromJson(data, Product.fromJson);
  }

  /// `GET /catalog/products/{id}` (404 si es de otra sucursal).
  Future<Product> fetchProduct(int id) async {
    final data = await api.getJson(ApiEndpoints.product(id));

    return Product.fromJson(data);
  }

  /// `GET /catalog/categories` — devuelve **todas** las categorías de la
  /// suscripción del tipo pedido (no es paginado).
  Future<List<Category>> fetchCategories({
    CatalogCategoryType type = CatalogCategoryType.product,
  }) async {
    final data = await api.getJsonList(
      ApiEndpoints.categories,
      query: <String, dynamic>{'type': type.value},
    );

    return data.map(Category.fromJson).toList(growable: false);
  }

  /// `GET /catalog/services` — servicios disponibles en la sucursal.
  Future<Paginated<CatalogService>> fetchServices({
    String? search,
    int? categoryId,
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await api.getJson(
      ApiEndpoints.services,
      query: <String, dynamic>{
        'search': search,
        'category_id': categoryId,
        'page': page,
        'per_page': perPage,
      },
    );

    return Paginated<CatalogService>.fromJson(data, CatalogService.fromJson);
  }
}
