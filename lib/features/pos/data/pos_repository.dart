import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import 'models/checkout_result.dart';

/// Escrituras del POS: venta de contado/crédito, apartado y pedido.
///
/// El payload lo arma `CartState` (mismos cálculos que el POS web) y aquí solo
/// viaja al servidor, que recalcula stock, folio, deuda y cambio. Los tres
/// endpoints exigen una sesión de caja abierta y el permiso `pos.create_sale`.
class PosRepository {
  PosRepository({required this.api});

  final ApiClient api;

  /// `POST /pos/checkout` — venta pagada (total o parcial = crédito).
  Future<CheckoutResult> checkout(Map<String, dynamic> payload) =>
      _sale(ApiEndpoints.checkout, payload);

  /// `POST /pos/layaway` — apartado con `layaway_expiration_date`.
  Future<CheckoutResult> layaway(Map<String, dynamic> payload) =>
      _sale(ApiEndpoints.layaway, payload);

  /// `POST /pos/store-order` — pedido o comanda (stock reservado, sin pagos).
  Future<CheckoutResult> storeOrder(Map<String, dynamic> payload) =>
      _sale(ApiEndpoints.storeOrder, payload);

  Future<CheckoutResult> _sale(String path, Map<String, dynamic> payload) async {
    final data = await api.postJson(path, data: payload);

    return CheckoutResult.fromJson(data);
  }
}
