import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../data/catalog_repository.dart';
import '../data/models/catalog_service.dart';
import '../data/models/category.dart';
import '../data/models/product.dart';

/// Repositorio del catálogo (productos, categorías y servicios).
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(api: ref.watch(apiClientProvider)),
);

/// Categorías de producto de la suscripción (no paginado).
final productCategoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(catalogRepositoryProvider).fetchCategories(),
);

/// Ficha de un producto (`GET /catalog/products/{id}`).
final productDetailProvider = FutureProvider.family<Product, int>(
  (ref, id) => ref.watch(catalogRepositoryProvider).fetchProduct(id),
);

/// Servicios de la sucursal (los usa el formulario de órdenes de servicio).
final servicesProvider = FutureProvider.family<Paginated<CatalogService>, String?>((
  ref,
  search,
) => ref
    .watch(catalogRepositoryProvider)
    .fetchServices(search: search, perPage: 50));

/// Estado del catálogo del POS: lista + filtros + paginación.
class ProductsState {
  const ProductsState({
    this.items = const <Product>[],
    this.search = '',
    this.categoryId,
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final List<Product> items;
  final String search;
  final int? categoryId;
  final int page;
  final bool hasMore;
  final int total;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isEmpty => items.isEmpty && !isLoading && errorMessage == null;

  ProductsState copyWith({
    List<Product>? items,
    String? search,
    int? categoryId,
    int? page,
    bool? hasMore,
    int? total,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool clearError = false,
    bool clearCategory = false,
  }) {
    return ProductsState(
      items: items ?? this.items,
      search: search ?? this.search,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Carga el catálogo con búsqueda, filtro por categoría y páginas sucesivas.
///
/// El servidor decide el precio, el stock y las promociones de la sucursal: aquí
/// solo se pagina y se acumula.
class ProductsController extends Notifier<ProductsState> {
  static const int pageSize = 20;

  @override
  ProductsState build() {
    Future<void>.microtask(() => loadFirstPage());

    return const ProductsState(isLoading: true);
  }

  Future<void> loadFirstPage() => _load(page: 1, reset: true);

  Future<void> loadMore() {
    final current = state;
    if (current.isLoading || current.isLoadingMore || !current.hasMore) {
      return Future<void>.value();
    }

    return _load(page: current.page + 1);
  }

  /// Aplica la búsqueda y recarga desde la primera página.
  Future<void> setSearch(String search) {
    final trimmed = search.trim();
    if (trimmed == state.search) {
      return Future<void>.value();
    }

    state = state.copyWith(search: trimmed);

    return loadFirstPage();
  }

  /// Filtra por categoría (`null` = todas).
  Future<void> setCategory(int? categoryId) {
    if (categoryId == state.categoryId) {
      return Future<void>.value();
    }

    state = categoryId == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(categoryId: categoryId);

    return loadFirstPage();
  }

  Future<void> refresh() => loadFirstPage();

  Future<void> _load({required int page, bool reset = false}) async {
    state = reset
        ? state.copyWith(isLoading: true, clearError: true)
        : state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final result = await ref
          .read(catalogRepositoryProvider)
          .fetchProducts(
            search: state.search.isEmpty ? null : state.search,
            categoryId: state.categoryId,
            page: page,
            perPage: pageSize,
          );

      state = state.copyWith(
        items: reset ? result.items : <Product>[...state.items, ...result.items],
        page: result.currentPage,
        hasMore: result.hasMore,
        total: result.total,
        isLoading: false,
        isLoadingMore: false,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        errorMessage: error.message,
      );
    }
  }
}

final productsControllerProvider =
    NotifierProvider<ProductsController, ProductsState>(
      ProductsController.new,
    );
