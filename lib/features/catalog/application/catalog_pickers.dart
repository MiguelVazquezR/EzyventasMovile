import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../data/models/product.dart';
import 'catalog_providers.dart';

/// Búsqueda de productos para los formularios que agregan refacciones
/// (órdenes de servicio). El POS usa su propio controlador paginado.
final productSearchProvider = FutureProvider.family<Paginated<Product>, String>(
  (ref, search) => ref
      .watch(catalogRepositoryProvider)
      .fetchProducts(search: search.isEmpty ? null : search, perPage: 30),
);
