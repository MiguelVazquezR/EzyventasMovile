import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/catalog_providers.dart';

/// Carrusel de categorías de producto ("Todas" + las de la suscripción) (§9).
///
/// Cada categoría es una teja con el icono dentro y la etiqueta debajo: la activa
/// se rellena con el naranja de marca (etiqueta del mismo color y sombra suave) y
/// las demás van sobre `panel` con borde. La API no manda imágenes por categoría,
/// así que el icono se elige por palabra clave del nombre y, cuando no hay pista,
/// cae al icono genérico de categoría.
///
/// El buscador no vive aquí: es `EzySearchField`, el que está fijo en la cabecera
/// del POS.
class CatalogCategoryChips extends ConsumerWidget {
  const CatalogCategoryChips({super.key});

  /// Lado de la teja del icono.
  static const double tileSize = 54;

  /// Alto del carrusel: teja + etiqueta (hasta 1.3x de escala) + respiro.
  static const double height = 92;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(productCategoriesProvider);
    final selected = ref.watch(
      productsControllerProvider.select((state) => state.categoryId),
    );

    return categories.maybeWhen(
      data: (items) {
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        final controller = ref.read(productsControllerProvider.notifier);

        return SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: items.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CategoryTile(
                  label: 'Todas',
                  icon: Icons.apps,
                  selected: selected == null,
                  onTap: () => controller.setCategory(null),
                );
              }

              final category = items[index - 1];

              return _CategoryTile(
                label: category.label,
                icon: _iconFor(category.label),
                selected: selected == category.id,
                onTap: () => controller.setCategory(category.id),
              );
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Icono de la categoría a partir de su nombre.
///
/// El contrato de `GET /catalog/categories` solo trae `name` y `products_count`:
/// no hay imagen ni icono, así que se busca una pista en el nombre y, si no hay
/// ninguna, se pinta el icono genérico de categoría.
IconData _iconFor(String label) {
  final name = label.toLowerCase();

  if (name.contains('aceite') || name.contains('lubricante')) {
    return Icons.oil_barrel_outlined;
  }
  if (name.contains('filtro')) {
    return Icons.filter_alt_outlined;
  }
  if (name.contains('llanta') || name.contains('rin')) {
    return Icons.tire_repair_outlined;
  }
  if (name.contains('herramienta')) {
    return Icons.handyman_outlined;
  }
  if (name.contains('eléctric') || name.contains('electric')) {
    return Icons.electrical_services_outlined;
  }
  if (name.contains('electrón') || name.contains('electron')) {
    return Icons.devices_other_outlined;
  }
  if (name.contains('refacc') || name.contains('refac')) {
    return Icons.settings_outlined;
  }
  if (name.contains('accesor')) {
    return Icons.extension_outlined;
  }
  if (name.contains('limpieza')) {
    return Icons.cleaning_services_outlined;
  }
  if (name.contains('bebida')) {
    return Icons.local_drink_outlined;
  }
  if (name.contains('aliment') ||
      name.contains('comida') ||
      name.contains('abarrote')) {
    return Icons.local_grocery_store_outlined;
  }
  if (name.contains('ropa') || name.contains('playera')) {
    return Icons.checkroom_outlined;
  }
  if (name.contains('pintura')) {
    return Icons.format_paint_outlined;
  }
  if (name.contains('servicio')) {
    return Icons.build_circle_outlined;
  }

  return Icons.category_outlined;
}

/// Esqueleto de carga del grid (sin spinner global, §12).
class CatalogSkeleton extends StatelessWidget {
  const CatalogSkeleton({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: surfaces.panel,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: surfaces.border),
          ),
        ),
      ),
    );
  }
}

/// Teja del carrusel: icono en un cuadro de [CatalogCategoryChips.tileSize] y la
/// etiqueta de una línea debajo.
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: CatalogCategoryChips.tileSize,
              height: CatalogCategoryChips.tileSize,
              decoration: BoxDecoration(
                color: selected ? EzyColors.primary : surfaces.panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected
                      ? EzyColors.primary.withValues(alpha: 0.6)
                      : surfaces.border,
                ),
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: EzyColors.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? EzyColors.white : surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: EzyTextStyles.badge.copyWith(
                fontSize: 11,
                letterSpacing: 0.2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? EzyColors.primary : surfaces.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

