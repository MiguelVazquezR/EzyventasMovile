import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../../application/catalog_providers.dart';

/// Chips de categoría de producto ("Todas" + las de la suscripción) y esqueleto
/// de la reja del catálogo (§9).
///
/// El buscador no vive aquí: es `EzySearchField`, el mismo de toda la app.
class CatalogCategoryChips extends ConsumerWidget {
  const CatalogCategoryChips({super.key});

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

        // 36 px de chip dentro de los 44 px de la fila: el chip más alto (el del
        // design system) es el que manda, sin pastillas estiradas.
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: items.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return EzyChip(
                  label: 'Todas',
                  icon: Icons.apps,
                  selected: selected == null,
                  onTap: () => controller.setCategory(null),
                );
              }

              final category = items[index - 1];

              return EzyChip(
                label: category.label,
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
