import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../pos/application/cart_controller.dart';
import '../../application/catalog_providers.dart';
import 'catalog_controls.dart';
import 'product_card.dart';
import 'product_detail_sheet.dart';

/// Catálogo del POS: buscador, chips de categoría, grid con paginación infinita
/// y detalle en bottom sheet.
///
/// Precio, stock y promociones son los que calculó el servidor para la sucursal
/// del usuario.
class ProductCatalogView extends ConsumerStatefulWidget {
  const ProductCatalogView({super.key});

  /// Cuántos productos está mostrando el catálogo (§9).
  ///
  /// Lo usan el pie de la reja y el subtítulo de la cabecera del POS, para que
  /// los dos digan exactamente lo mismo.
  static String countLabel(ProductsState state) {
    if (state.hasMore) {
      return 'Mostrando ${state.items.length} de ${state.total} productos';
    }

    final unit = state.total == 1 ? 'producto' : 'productos';

    return '${state.total} $unit en esta sucursal';
  }

  /// Subtítulo de la cabecera del POS (§9). Mientras no haya nada que contar
  /// (carga inicial o error) devuelve `null`: de eso ya avisan el esqueleto y el
  /// aviso de error, y un `0 productos` ahí sería mentira.
  static String? subtitle(ProductsState state) =>
      state.items.isEmpty ? null : countLabel(state);

  @override
  ConsumerState<ProductCatalogView> createState() => _ProductCatalogViewState();
}

class _ProductCatalogViewState extends ConsumerState<ProductCatalogView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(productsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productsControllerProvider);
    final controller = ref.read(productsControllerProvider.notifier);
    final canSell = ref.watch(permissionsProvider).can('pos.create_sale');

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              // El buscador del design system trae su propio retardo: no se pide
              // una página por tecla (§9, §12).
              child: EzySearchField(
                hint: 'Buscar por nombre o SKU…',
                onChanged: controller.setSearch,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: CatalogCategoryChips()),
          if (state.errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: ErrorNotice(
                  message: state.errorMessage!,
                  onRetry: controller.refresh,
                ),
              ),
            ),
          if (state.isLoading)
            const SliverToBoxAdapter(child: CatalogSkeleton())
          else if (state.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                icon: Icons.search_off,
                title: state.search.isEmpty
                    ? 'No hay productos disponibles en esta sucursal.'
                    : 'Sin resultados para “${state.search}”.',
                message: state.search.isEmpty
                    ? 'Agrega productos al catálogo desde la versión web.'
                    : 'Prueba con otro nombre o código SKU.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.68,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = state.items[index];

                  return ProductCard(
                    product: product,
                    onTap: () => showProductDetail(context, product),
                    onAdd: canSell && !product.hasVariants
                        ? () => ref
                              .read(cartControllerProvider.notifier)
                              .addProduct(product)
                        : null,
                  );
                }, childCount: state.items.length),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: state.isLoadingMore
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Text(
                      ProductCatalogView.countLabel(state),
                      textAlign: TextAlign.center,
                      style: EzyTextStyles.secondary.copyWith(
                        color: context.surfaces.textMuted,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
