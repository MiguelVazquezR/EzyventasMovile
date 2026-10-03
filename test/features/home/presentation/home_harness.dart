import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/home/application/dashboard_controller.dart';
import 'package:ezyventas_app/features/home/data/dashboard_repository.dart';
import 'package:ezyventas_app/features/home/data/models/expiring_layaway.dart';
import 'package:ezyventas_app/features/home/data/models/mobile_dashboard.dart';
import 'package:ezyventas_app/features/home/data/models/upcoming_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_harness.dart';
import '../data/dashboard_fixtures.dart';

/// Repositorio falso del inicio: sirve los JSON del contrato (§3b) o falla.
///
/// No toca la red: devuelve las mismas llaves que documenta el servidor y echa
/// de vuelta el `days` que le pidieron, como hace la API.
class FakeDashboardRepository extends DashboardRepository {
  FakeDashboardRepository({
    Map<String, dynamic>? dashboard,
    this.expiringRows,
    this.deliveryRows,
    this.failure,
  }) : dashboardJson = dashboard ?? ownerDashboardJson(),
       super(api: ApiClient());

  Map<String, dynamic> dashboardJson;

  /// Filas del listado de apartados; `null` = las dos de §3b.3.
  List<Map<String, dynamic>>? expiringRows;

  /// Filas del listado de entregas; `null` = las dos de §3b.4.
  List<Map<String, dynamic>>? deliveryRows;

  /// Error que deben lanzar las tres llamadas (p. ej. `ApiException.network()`).
  ApiException? failure;

  int dashboardCalls = 0;
  final List<int> requestedExpiringDays = <int>[];
  final List<int> requestedDeliveryDays = <int>[];

  static List<Map<String, dynamic>> _rowsOf(Map<String, dynamic> fixture) =>
      fixture['data']! as List<Map<String, dynamic>>;

  void _throwIfFailure() {
    final error = failure;
    if (error != null) {
      throw error;
    }
  }

  @override
  Future<MobileDashboard> fetchDashboard() async {
    dashboardCalls++;
    _throwIfFailure();

    return MobileDashboard.fromJson(dashboardJson);
  }

  @override
  Future<ExpiringLayawaysResult> fetchExpiringLayaways({
    int days = dashboardDefaultDays,
  }) async {
    requestedExpiringDays.add(days);
    _throwIfFailure();

    return ExpiringLayawaysResult.fromJson(<String, dynamic>{
      'days': days,
      'data': expiringRows ?? _rowsOf(expiringLayawaysJson()),
    });
  }

  @override
  Future<UpcomingDeliveriesResult> fetchUpcomingDeliveries({
    int days = dashboardDefaultDays,
  }) async {
    requestedDeliveryDays.add(days);
    _throwIfFailure();

    return UpcomingDeliveriesResult.fromJson(<String, dynamic>{
      'days': days,
      'data': deliveryRows ?? _rowsOf(upcomingDeliveriesJson()),
    });
  }
}

/// Avanza unos cuantos fotogramas.
///
/// La barra de caja lleva el punto pulsante del turno abierto (`repeat`): con
/// una animación infinita en pantalla `pumpAndSettle` nunca termina, así que las
/// pruebas del inicio avanzan a mano.
Future<void> pumpFrames(WidgetTester tester, {int frames = 4}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Monta una pantalla del inicio con la sesión y el repositorio falsos.
///
/// No se concede `transactions.access` a propósito: sin ese permiso la cabecera
/// no pinta la campana y la prueba no depende de `GET /notifications`.
Future<void> pumpDashboardScreen(
  WidgetTester tester, {
  required FakeDashboardRepository repository,
  Widget? screen,
  GoRouter? router,
  List<String> permissions = const <String>['pos.access'],
  List<String> modules = const <String>['module_pos'],
  Size surfaceSize = const Size(420, 2800),
  bool settle = true,
}) async {
  assert(
    screen != null || router != null,
    'pasa `screen` (pantalla suelta) o `router` (con navegación)',
  );

  // Lienzo alto: la pantalla de inicio es larga y el `ListView` solo construye
  // lo visible, así que las pruebas comprueban las tarjetas de una vez. Con
  // `surfaceSize` se puede pedir una pantalla de teléfono (para el gesto de
  // pull-to-refresh, que necesita una lista desplazable).
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            session: fakeSession(permissions: permissions, modules: modules),
          ),
        ),
        dashboardRepositoryProvider.overrideWithValue(repository),
      ],
      child: router == null
          ? MaterialApp(theme: EzyTheme.dark(), home: screen)
          : MaterialApp.router(
              theme: EzyTheme.dark(),
              routerConfig: router,
            ),
    ),
  );

  if (settle) {
    await pumpFrames(tester);
  }
}
