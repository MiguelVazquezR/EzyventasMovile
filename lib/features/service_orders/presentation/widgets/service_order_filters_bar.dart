import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../application/service_orders_controller.dart';
import '../../data/models/service_order_filters.dart';
import 'service_order_labels.dart';

/// Filtros del listado: búsqueda, chips de estatus y orden.
///
/// Todo viaja al servidor (la app no filtra localmente) y cada cambio vuelve a
/// la primera página. La búsqueda la resuelve `EzySearchField`, que ya trae el
/// *debounce* y el botón de limpiar del design system.
class ServiceOrderFiltersBar extends ConsumerWidget {
  const ServiceOrderFiltersBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(
      serviceOrdersControllerProvider.select((state) => state.filters),
    );
    final controller = ref.read(serviceOrdersControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: EzySearchField(
            hint: 'Buscar por folio, cliente o equipo…',
            onChanged: controller.setSearch,
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: ServiceOrderLabels.statusFilters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final status = ServiceOrderLabels.statusFilters[index];
              final isSelected = filters.status == status;

              return EzyChip(
                label: ServiceOrderLabels.status(status),
                selected: isSelected,
                onTap: () => controller.setStatus(isSelected ? null : status),
              );
            },
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
            tooltip: 'Ordenar',
            onSelected: controller.setSort,
            color: context.surfaces.panel,
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
            child: EzyChip(label: filters.sort.label, icon: Icons.sort),
          ),
          const Spacer(),
          if (filters.hasFilters)
            EzyChip(
              label: 'Limpiar filtros',
              icon: Icons.filter_alt_off_outlined,
              onTap: () => controller.clearFilters(),
            ),
        ],
      ),
    );
  }
}
