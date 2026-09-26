import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../pos/application/cart_controller.dart';
import '../../application/catalog_providers.dart';
import '../../data/models/product.dart';
import 'catalog_controls.dart';
import 'product_card.dart';
import 'product_detail_sheet.dart';

/// Catálogo del POS: carrusel de categorías, reja de dos columnas con paginación
/// infinita y detalle en hoja.
///
/// El buscador no vive aquí: está fijo en la cabecera del POS, con el botón del
/// escáner de códigos.
///
/// Precio, stock y promociones son los que calculó el servidor para la sucursal
/// del usuario. Cada celda escucha **solo** la cantidad de su producto en el
/// carrito, así que agregar unidades en una tarjeta no repinta la reja entera.
class ProductCatalogView extends ConsumerStatefulWidget {
  const ProductCatalogView({super.key, required this.searchController});

  /// Buscador del catálogo.
  ///
  /// El campo vive en la cabecera del POS (fijo, con su botón de escáner), así
  /// que la vista no lo pinta: lo recibe solo para poder vaciarlo desde «Limpiar
  /// filtros» (§10).
  final TextEditingController searchController;

  /// Subtítulo del pie de la reja: cuántos productos se están mostrando.
  static String countLabel(ProductsState state) {
    if (state.hasMore) {
      return 'Mostrando ${state.items.length} de ${state.total} productos';
    }

    final unit = state.total == 1 ? 'producto' : 'productos';

    return '${state.total} $unit en esta sucursal';
  }

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

  /// Deja el catálogo sin filtros: buscador, categoría y estado del servidor.
  void _clearFilters() {
    widget.searchController.clear();
    final controller = ref.read(productsControllerProvider.notifier);
    controller.setSearch('');
    controller.setCategory(null);
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
          // El buscador vive en la banda de la cabecera del POS (fijo, con su
          // botón de escáner): aquí solo queda el scroll del catálogo.
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 4),
              child: CatalogCategoryChips(),
            ),
          ),
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
                // Vacío tras filtrar: siempre se ofrece la salida (§10).
                actionLabel: state.hasFilters ? 'Limpiar filtros' : null,
                onAction: state.hasFilters ? _clearFilters : null,
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

                  return _CatalogTile(product: product, canSell: canSell);
                }, childCount: state.items.length),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              // §1.7: el scroll nunca queda bajo la barra ni bajo el FAB.
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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

/// Celda de la reja del catálogo.
///
/// Escucha **solo** la cantidad de su producto en el carrito (`select`), así que
/// agregar una unidad en una tarjeta no repinta las demás. El `ProductCard` sigue
/// siendo presentacional: aquí se decide si el producto se agrega de un toque
/// (sin variantes) o si hay que abrir el detalle para elegir la combinación.
class _CatalogTile extends ConsumerWidget {
  const _CatalogTile({required this.product, required this.canSell});

  final Product product;
  final bool canSell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartControllerProvider.notifier);
    final quantity = ref.watch(
      cartControllerProvider.select((state) => state.quantityOf(product.id)),
    );
    // Los productos con variantes se agregan desde el detalle: son varias líneas
    // posibles y la tarjeta no puede elegir por el usuario.
    final canAddQuickly = canSell && !product.hasVariants;

    return ProductCard(
      product: product,
      quantity: quantity,
      onTap: () => showProductDetail(context, product),
      onAdd: canAddQuickly ? () => cart.incrementProduct(product) : null,
      onIncrement: canAddQuickly
          ? () => cart.incrementProduct(product)
          : null,
      onDecrement: canAddQuickly
          ? () => cart.decrementProduct(product.id)
          : null,
    );
  }
}

