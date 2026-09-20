import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/search_debouncer.dart';
import '../../application/service_orders_controller.dart';
import '../../data/models/service_order_filters.dart';
import 'service_order_labels.dart';

/// Filtros del listado: búsqueda, chips de estatus y orden.
///
/// Todo viaja al servidor (la app no filtra localmente) y cada cambio vuelve a
/// la primera página.
class ServiceOrderFiltersBar extends ConsumerStatefulWidget {
  const ServiceOrderFiltersBar({super.key});

  @override
  ConsumerState<ServiceOrderFiltersBar> createState() =>
      _ServiceOrderFiltersBarState();
}

class _ServiceOrderFiltersBarState extends ConsumerState<ServiceOrderFiltersBar> {
  final TextEditingController _searchController = TextEditingController();
  final SearchDebouncer _debouncer = SearchDebouncer();

  @override
  void dispose() {
    _debouncer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final filters = ref.watch(
      serviceOrdersControllerProvider.select((state) => state.filters),
    );
    final controller = ref.read(serviceOrdersControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onChanged: (value) =>
                _debouncer.run(() => controller.setSearch(value)),
            style: EzyTextStyles.fieldValue.copyWith(
              color: surfaces.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Buscar por folio, cliente o equipo…',
              prefixIcon: Icon(
                Icons.search,
                size: 20,
                color: surfaces.textMuted,
              ),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: 'Limpiar búsqueda',
                        onPressed: () {
                          _searchController.clear();
                          controller.setSearch('');
                        },
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: surfaces.textMuted,
                        ),
                      ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: <Widget>[
              for (final status in ServiceOrderLabels.statusFilters) ...<Widget>[
                ServiceOrderFilterChip(
                  label: ServiceOrderLabels.status(status),
                  isSelected: filters.status == status,
                  onTap: () => controller.setStatus(
                    filters.status == status ? null : status,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SortRow(filters: filters),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Orden del listado y acción para limpiar los filtros.
class _SortRow extends ConsumerWidget {
  const _SortRow({required this.filters});

  final ServiceOrderFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(serviceOrdersControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          PopupMenuButton<ServiceOrderSort>(
            initialValue: filters.sort,
            onSelected: controller.setSort,
            itemBuilder: (context) => <PopupMenuEntry<ServiceOrderSort>>[
              for (final sort in ServiceOrderSort.values)
                PopupMenuItem<ServiceOrderSort>(
                  value: sort,
                  child: Row(
                    children: <Widget>[
                      if (sort == filters.sort)
                        const Icon(Icons.check, size: 16)
                      else
                        const SizedBox(width: 16),
                      const SizedBox(width: 10),
                      Text(sort.label),
                    ],
                  ),
                ),
            ],
            child: ServiceOrderFilterChip(
              label: filters.sort.label,
              icon: Icons.sort,
              isSelected: false,
            ),
          ),
          const Spacer(),
          if (filters.hasFilters)
            ServiceOrderFilterChip(
              label: 'Limpiar filtros',
              icon: Icons.filter_alt_off_outlined,
              isSelected: false,
              onTap: controller.clearFilters,
            ),
        ],
      ),
    );
  }
}

/// Chip pill de filtro.
class ServiceOrderFilterChip extends StatelessWidget {
  const ServiceOrderFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = isSelected ? EzyColors.primary : surfaces.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? EzyColors.primary.withValues(alpha: 0.16)
              : surfaces.panel,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? EzyColors.primary.withValues(alpha: 0.5)
                : surfaces.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: EzyTextStyles.caption.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
