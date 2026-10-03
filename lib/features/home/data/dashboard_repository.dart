import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import 'models/expiring_layaway.dart';
import 'models/mobile_dashboard.dart';
import 'models/upcoming_delivery.dart';

/// Ventana por defecto de los listados de alertas (§3b.3 y §3b.4).
///
/// La tarjeta del inicio usa la **misma** ventana que el listado, así el
/// contador del payload siempre coincide con el largo de la lista.
const int dashboardDefaultDays = 3;

/// Límites documentados del parámetro `days`.
const int dashboardMinDays = 1;
const int dashboardMaxDays = 30;

/// Inicio de la app: los 3 endpoints del contrato §3b.
///
/// El servidor calcula contadores, días restantes y saldos; aquí solo se arma la
/// petición y se tipa la respuesta. La pantalla se pide **sin caché**: al entrar
/// y con pull-to-refresh.
class DashboardRepository {
  DashboardRepository({required this.api});

  final ApiClient api;

  /// `GET /dashboard` — una sola llamada arma toda la pantalla.
  Future<MobileDashboard> fetchDashboard() async {
    final data = await api.getJson(ApiEndpoints.dashboard);

    return MobileDashboard.fromJson(data);
  }

  /// `GET /dashboard/expiring-layaways?days=` — apartados y créditos por vencer.
  Future<ExpiringLayawaysResult> fetchExpiringLayaways({
    int days = dashboardDefaultDays,
  }) async {
    final data = await api.getJson(
      ApiEndpoints.dashboardExpiringLayaways,
      query: <String, dynamic>{'days': days},
    );

    return ExpiringLayawaysResult.fromJson(data);
  }

  /// `GET /dashboard/upcoming-deliveries?days=` — pedidos por entregar.
  Future<UpcomingDeliveriesResult> fetchUpcomingDeliveries({
    int days = dashboardDefaultDays,
  }) async {
    final data = await api.getJson(
      ApiEndpoints.dashboardUpcomingDeliveries,
      query: <String, dynamic>{'days': days},
    );

    return UpcomingDeliveriesResult.fromJson(data);
  }
}
