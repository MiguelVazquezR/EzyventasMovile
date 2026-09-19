import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/paginated.dart';
import '../../../core/utils/uuid_generator.dart';
import 'models/customer.dart';

/// Clientes de la sucursal del usuario.
class CustomersRepository {
  CustomersRepository({required this.api});

  final ApiClient api;

  /// `GET /customers` con búsqueda por nombre, razón social, correo o teléfono.
  Future<Paginated<Customer>> fetchCustomers({
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final data = await api.getJson(
      ApiEndpoints.customers,
      query: <String, dynamic>{
        'search': search,
        'page': page,
        'per_page': perPage,
      },
    );

    return Paginated<Customer>.fromJson(data, Customer.fromJson);
  }

  /// `GET /customers/{id}` con apartados activos y movimientos de saldo.
  Future<CustomerDetail> fetchCustomer(int id) async {
    final data = await api.getJson(ApiEndpoints.customer(id));

    return CustomerDetail.fromJson(data);
  }

  /// `POST /customers` (permiso `customers.create`).
  ///
  /// Solo se envían los campos capturados: el servidor pone `branch_id` y
  /// responde `201` con el cliente en formato de listado.
  Future<Customer> createCustomer({
    required String name,
    String? companyName,
    String? email,
    String? phone,
    String? taxId,
    Map<String, dynamic>? address,
    double? creditLimit,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'company_name': _blankToNull(companyName),
      'email': _blankToNull(email),
      'phone': _blankToNull(phone),
      'tax_id': _blankToNull(taxId),
      'address': address,
      'credit_limit': creditLimit,
      'client_uuid': UuidGenerator.v4(),
    }..removeWhere((key, value) => value == null);

    final data = await api.postJson(ApiEndpoints.customers, data: payload);

    return Customer.fromJson(data);
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();

    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
