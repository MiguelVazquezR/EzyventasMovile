import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../auth/application/auth_controller.dart';
import '../application/sales_controller.dart';
import '../data/models/transaction_summary.dart';
import 'widgets/transaction_detail_sheet.dart';
import 'widgets/transaction_filters_bar.dart';
import 'widgets/transaction_tile.dart';

/// Pestaña "Ventas": historial con filtros, detalle, abonos, cancelación y
/// edición de pagos.
///
/// Todo el filtrado y la paginación los resuelve el servidor (`GET
/// /transactions`); la app solo acumula las páginas y pinta lo que recibe.
class SalesScreen extends ConsumerStatefulWidget {
  const SalesScreen({super.key});

  @override
  ConsumerState<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends ConsumerState<SalesScreen> {
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
      ref.read(transactionsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionsControllerProvider);
    final controller = ref.read(transactionsControllerProvider.notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AppScreenHeader(title: 'Ventas', subtitle: _subtitle(state)),
            const TransactionFiltersBar(),
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

  String _subtitle(TransactionsState state) {
    if (state.isLoading) {
      return 'Cargando información…';
    }

    if (state.total == 0) {
      return state.filters.hasFilters
          ? 'Sin resultados con estos filtros'
          : 'Aún no hay ventas registradas';
    }

    final count = state.total == 1 ? '1 venta' : '${state.total} ventas';

    return state.filters.hasFilters
        ? '$count con estos filtros'
        : '$count en esta sucursal';
  }

  Widget _buildList(
    TransactionsState state,
    TransactionsController controller,
  ) {
    if (state.isLoading) {
      return const _SalesSkeleton();
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
            icon: state.filters.hasFilters
                ? Icons.search_off
                : Icons.receipt_long_outlined,
            title: state.filters.hasFilters
                ? 'No hay ventas que coincidan con los filtros.'
                : 'Aún no hay ventas registradas.',
            message: state.filters.hasFilters
                ? 'Prueba con otro folio, cliente o rango de fechas.'
                : 'Las ventas que cobres en la app aparecerán aquí.',
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
          child: TransactionTile(
            transaction: item,
            onTap: () => _openDetail(item),
          ),
        );
      },
    );
  }

  Widget _footer(TransactionsState state, TransactionsController controller) {
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
                  ? 'Mostrando ${state.items.length} de ${state.total} ventas'
                  : '${state.total} venta${state.total == 1 ? '' : 's'} en total',
              textAlign: TextAlign.center,
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textMuted,
              ),
            ),
        ],
      ),
    );
  }

  /// El detalle exige `transactions.see_details`: sin el permiso se avisa y no
  /// se pide nada al servidor (que respondería `403`).
  Future<void> _openDetail(TransactionSummary item) async {
    final canSeeDetails = ref
        .read(permissionsProvider)
        .can('transactions.see_details');

    if (!canSeeDetails) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tu usuario no tiene permiso para esta acción.'),
        ),
      );
      return;
    }

    await showTransactionDetailSheet(context, transactionId: item.id);
  }
}

/// Esqueleto de carga de la lista (sin spinner global, §12).
class _SalesSkeleton extends StatelessWidget {
  const _SalesSkeleton();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Container(
        height: 128,
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: surfaces.border),
        ),
      ),
    );
  }
}
