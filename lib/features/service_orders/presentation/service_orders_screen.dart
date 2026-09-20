import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../application/service_orders_controller.dart';
import '../data/models/service_order_detail.dart';
import '../data/models/service_order_summary.dart';
import 'widgets/service_order_detail_sheet.dart';
import 'widgets/service_order_filters_bar.dart';
import 'widgets/service_order_tile.dart';

/// Pestaña "Órdenes": lista de trabajo con filtros y paginación infinita.
///
/// El servidor filtra, ordena y pagina (`GET /service-orders`): la app solo
/// acumula las páginas y pinta el `message` del servidor cuando algo falla.
class ServiceOrdersScreen extends ConsumerStatefulWidget {
  const ServiceOrdersScreen({super.key});

  @override
  ConsumerState<ServiceOrdersScreen> createState() =>
      _ServiceOrdersScreenState();
}

class _ServiceOrdersScreenState extends ConsumerState<ServiceOrdersScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(serviceOrdersControllerProvider.notifier).loadMore();
    }
  }

  /// Alta de la orden: al guardar se abre el detalle de la orden creada.
  Future<void> _createOrder() async {
    final created = await context.push<ServiceOrderDetail>(
      serviceOrderNewPath,
    );

    if (created == null || !mounted) {
      return;
    }

    await showServiceOrderDetailSheet(context, serviceOrderId: created.id);
  }

  /// El detalle exige `services.orders.see_details`.
  Future<void> _openDetail(ServiceOrderSummary item) async {
    if (!ref.read(permissionsProvider).can('services.orders.see_details')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu usuario no tiene permiso para esta acción.'),
        ),
      );

      return;
    }

    await showServiceOrderDetailSheet(context, serviceOrderId: item.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceOrdersControllerProvider);
    final controller = ref.read(serviceOrdersControllerProvider.notifier);
    final canCreate = ref.watch(
      permissionsProvider.select(
        (permissions) => permissions.can('services.orders.create'),
      ),
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AppScreenHeader(
              title: 'Órdenes de servicio',
              subtitle: _subtitle(state),
              actions: <Widget>[
                if (canCreate)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: EzyButton(
                      label: 'Nueva',
                      icon: Icons.add,
                      expand: false,
                      onPressed: _createOrder,
                    ),
                  ),
              ],
            ),
            const ServiceOrderFiltersBar(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: _buildList(state, controller),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(ServiceOrdersState state) {
    if (state.isLoading) {
      return 'Cargando información…';
    }

    if (state.total == 0) {
      return state.filters.hasFilters
          ? 'Sin resultados con estos filtros'
          : 'Aún no hay órdenes registradas';
    }

    final count = state.total == 1 ? '1 orden' : '${state.total} órdenes';

    return state.filters.hasFilters
        ? '$count con estos filtros'
        : '$count en esta sucursal';
  }

  Widget _buildList(
    ServiceOrdersState state,
    ServiceOrdersController controller,
  ) {
    if (state.isLoading) {
      return const _ServiceOrdersSkeleton();
    }

    if (state.items.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          if (state.errorMessage != null) ...<Widget>[
            ErrorNotice(
              message: state.errorMessage!,
              onRetry: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          EmptyState(
            icon: Icons.build_outlined,
            title: state.filters.hasFilters
                ? 'Sin resultados'
                : 'No hay órdenes de servicio',
            message: state.filters.hasFilters
                ? 'No hay órdenes de servicio que coincidan con la búsqueda.'
                : 'Cuando registres una orden aparecerá aquí con su estatus y '
                      'saldo pendiente.',
            actionLabel: state.filters.hasFilters ? 'Limpiar filtros' : null,
            onAction: state.filters.hasFilters ? controller.clearFilters : null,
          ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: state.items.length + 1,
      itemBuilder: (context, index) {
        if (index == state.items.length) {
          return _footer(state, controller);
        }

        final item = state.items[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ServiceOrderTile(
            serviceOrder: item,
            onTap: () => _openDetail(item),
          ),
        );
      },
    );
  }

  Widget _footer(
    ServiceOrdersState state,
    ServiceOrdersController controller,
  ) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        children: <Widget>[
          if (state.errorMessage != null) ...<Widget>[
            ErrorNotice(
              message: state.errorMessage!,
              onRetry: controller.refresh,
            ),
            const SizedBox(height: 12),
          ],
          if (state.isLoadingMore)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Text(
              state.hasMore
                  ? 'Mostrando ${state.items.length} de ${state.total} órdenes'
                  : '${state.total} orden${state.total == 1 ? '' : 'es'} en total',
              textAlign: TextAlign.center,
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// Esqueleto de carga de la lista (sin spinner global, §12).
class _ServiceOrdersSkeleton extends StatelessWidget {
  const _ServiceOrdersSkeleton();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Container(
        height: 168,
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: surfaces.border),
        ),
      ),
    );
  }
}
