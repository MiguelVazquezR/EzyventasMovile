import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../application/catalog_providers.dart';

/// Buscador del catálogo: pastilla con el icono de la marca y botón para limpiar.
class CatalogSearchField extends StatelessWidget {
  const CatalogSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.hint = 'Buscar por nombre o SKU…',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: EzyColors.primary.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: EzyTextStyles.fieldValue.copyWith(color: surfaces.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          // La pastilla ya pinta su propio fondo y borde.
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(7),
            child: Container(
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: EzyColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, size: 18, color: EzyColors.black1),
            ),
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: onClear,
                    tooltip: 'Limpiar búsqueda',
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: surfaces.textSecondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Chips de categoría de producto ("Todas" + las de la suscripción).
class CatalogCategoryChips extends ConsumerWidget {
  const CatalogCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(productCategoriesProvider);
    final selected = ref.watch(
      productsControllerProvider.select((state) => state.categoryId),
    );
    final controller = ref.read(productsControllerProvider.notifier);

    return SizedBox(
      height: 48,
      child: categories.when(
        loading: () => const SizedBox.shrink(),
        error: (error, stackTrace) => const SizedBox.shrink(),
        data: (items) {
          if (items.isEmpty) {
            return const SizedBox.shrink();
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CategoryChip(
                  label: 'Todas',
                  icon: Icons.apps,
                  isSelected: selected == null,
                  onTap: () => controller.setCategory(null),
                );
              }

              final category = items[index - 1];

              return _CategoryChip(
                label: category.label,
                isSelected: selected == category.id,
                onTap: () => controller.setCategory(category.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          // El chip activo se rellena con el naranja de la marca: se ve de un
          // solo golpe cuál está aplicado.
          color: isSelected ? EzyColors.primary : surfaces.panelInner,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? EzyColors.primary : surfaces.borderStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 16,
                color: isSelected ? EzyColors.black1 : surfaces.textMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: EzyTextStyles.caption.copyWith(
                color: isSelected
                    ? EzyColors.black1
                    : surfaces.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
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
