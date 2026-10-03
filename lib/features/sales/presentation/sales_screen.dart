import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/scanner/scanner_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/ezy_primary_3d_button.dart';
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
/// /transactions`); la app solo acumula las páginas y pinta lo que recibe. El
/// scroll infinito pide la siguiente página 400 px antes del final y el
/// *pull-to-refresh* reinicia la lista desde la página 1.
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
            AppScreenHeader(
              title: 'Ventas',
              subtitle: _subtitle(state),
              actions: <Widget>[_ScanButton(onTap: _scan)],
            ),
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

  /// El botón de la cabecera lee un código y lo deja como búsqueda: el campo de
  /// filtros y la consulta al servidor van siempre juntos.
  Future<void> _scan() async {
    final code = await ref.read(scannerLauncherProvider)(context);

    if (code == null || code.trim().isEmpty || !mounted) {
      return;
    }

    final value = code.trim();
    ref.read(salesSearchControllerProvider).text = value;

    await ref.read(transactionsControllerProvider.notifier).setSearch(value);
  }

  String _subtitle(TransactionsState state) {
    if (state.isLoading && state.items.isEmpty) {
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
    // Con la lista vacía y la primera carga en curso manda el esqueleto; durante
    // un refresco con datos ya pintados no se tapa la lista.
    if (state.isLoading && state.items.isEmpty) {
      return const _SalesSkeleton();
    }

    if (state.items.isEmpty) {
      if (state.errorMessage != null) {
        return _scrollable(
          <Widget>[
            _SalesErrorState(
              message: state.errorMessage!,
              onRetry: controller.refresh,
            ),
          ],
        );
      }

      final hasFilters = state.filters.hasFilters;

      return _scrollable(
        <Widget>[
          _SalesEmptyState(
            title: hasFilters
                ? 'Sin resultados con estos filtros'
                : 'Aún no hay ventas registradas',
            message: hasFilters
                ? 'Prueba con otro folio, cliente o rango de fechas.'
                : 'Las ventas que cobres en la app aparecerán aquí.',
            onClear: hasFilters ? controller.clearFilters : null,
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

  /// Lista de un solo hijo que se puede arrastrar para refrescar (los estados
  /// vacío y de error tienen que dejar el gesto activo).
  Widget _scrollable(List<Widget> children) {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: children,
    );
  }

  Widget _footer(TransactionsState state, TransactionsController controller) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: EzyColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Mostrando ${state.items.length} de ${state.total} ventas',
                  style: EzyTextStyles.secondary.copyWith(
                    color: surfaces.textMuted,
                  ),
                ),
              ],
            )
          else
            Text(
              state.hasMore
                  ? 'Mostrando ${state.items.length} de ${state.total} ventas'
                  : '${state.total} venta${state.total == 1 ? '' : 's'} en total',
              textAlign: TextAlign.center,
              style: EzyTextStyles.secondary.copyWith(
                fontSize: 11,
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
        SnackBar(
          content: const Row(
            children: <Widget>[
              Icon(Icons.lock_outline, size: 16, color: Color(0xFFFCD34D)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sin permiso requerido: transactions.see_details',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF232323),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    await showTransactionDetailSheet(context, transactionId: item.id);
  }
}


/// Acción de la cabecera: escanear el ticket y buscarlo por su código.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surfaces.border),
        ),
        child: Icon(
          Icons.qr_code_scanner,
          size: 18,
          color: surfaces.textSecondary,
        ),
      ),
    );
  }
}

/// Esqueleto de carga de la lista (sin spinner global, §12): tres tarjetas del
/// mismo alto que una venta con un brillo que barre de izquierda a derecha.
class _SalesSkeleton extends StatefulWidget {
  const _SalesSkeleton();

  @override
  State<_SalesSkeleton> createState() => _SalesSkeletonState();
}

class _SalesSkeletonState extends State<_SalesSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _Shimmer(height: 128, animation: _controller),
    );
  }
}

/// Barra de brillo del esqueleto: el fondo es la superficie de la tarjeta y el
/// destello sube un escalón sobre el tema activo.
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.height, required this.animation});

  final double height;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F3F6);

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final progress = animation.value;

        return Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TransactionTile.radius),
            border: Border.all(color: surfaces.border),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + progress * 3, 0),
              end: Alignment(-0.5 + progress * 3, 0),
              colors: <Color>[surfaces.panel, highlight, surfaces.panel],
              stops: const <double>[0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}


/// Estado vacío del historial: icono en una caja de 64, mensaje corto y, si hay
/// filtros puestos, el CTA 3D que los limpia.
class _SalesEmptyState extends StatelessWidget {
  const _SalesEmptyState({
    required this.title,
    required this.message,
    this.onClear,
  });

  final String title;
  final String message;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final clear = onClear;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: surfaces.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: surfaces.border),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 30,
                color: surfaces.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: EzyTextStyles.bodyStrong.copyWith(
                fontSize: 16,
                color: surfaces.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            if (clear != null) ...<Widget>[
              const SizedBox(height: 20),
              EzyPrimary3dButton(
                label: 'Limpiar filtros',
                icon: Icons.filter_alt_off_outlined,
                height: 48,
                maxWidth: 260,
                onPressed: clear,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error de la primera página: caja en peligro, mensaje del servidor tal cual y
/// CTA 3D de reintento.
class _SalesErrorState extends StatelessWidget {
  const _SalesErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final danger = StatusPalette.text(context, EzySeverity.danger);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: StatusPalette.soft(EzySeverity.danger),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: StatusPalette.border(EzySeverity.danger),
                ),
              ),
              child: Icon(Icons.warning_amber_rounded, size: 30, color: danger),
            ),
            const SizedBox(height: 16),
            Text(
              'No pudimos cargar las ventas',
              textAlign: TextAlign.center,
              style: EzyTextStyles.bodyStrong.copyWith(
                fontSize: 16,
                color: surfaces.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            EzyPrimary3dButton(
              label: 'Reintentar',
              icon: Icons.refresh,
              height: 48,
              maxWidth: 260,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
