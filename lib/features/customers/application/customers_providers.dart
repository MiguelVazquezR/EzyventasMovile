import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/paginated.dart';
import '../data/customers_repository.dart';
import '../data/models/customer.dart';

/// Repositorio de clientes (POS y ficha de cliente).
final customersRepositoryProvider = Provider<CustomersRepository>(
  (ref) => CustomersRepository(api: ref.watch(apiClientProvider)),
);

/// Búsqueda de clientes para el cobro (`GET /customers`).
///
/// La clave es el texto buscado: el carrito pide la lista una vez por término y
/// Flutter mantiene la caché del `FutureProvider`.
final customerSearchProvider = FutureProvider.family<Paginated<Customer>, String>(
  (ref, search) => ref
      .watch(customersRepositoryProvider)
      .fetchCustomers(search: search.isEmpty ? null : search, perPage: 20),
);
