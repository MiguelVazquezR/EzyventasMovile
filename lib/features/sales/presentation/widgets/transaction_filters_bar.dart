import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../application/sales_controller.dart';
import '../../data/models/transaction_filters.dart';
import 'sales_labels.dart';

/// Filtros del historial: búsqueda, estatus, rango de fechas y orden.
///
/// Todo viaja al servidor (la app no filtra localmente) y cada cambio vuelve a
/// la primera página. La búsqueda la resuelve `EzySearchField`, que ya trae el
/// *debounce* y el botón de limpiar del design system.
class TransactionFiltersBar extends ConsumerWidget {
  const TransactionFiltersBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(
      transactionsControllerProvider.select((state) => state.filters),
    );
    final controller = ref.read(transactionsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: EzySearchField(
            hint: 'Buscar por folio o cliente…',
            onChanged: controller.setSearch,
          ),
        ),
        _StatusChips(
          selected: filters.statuses,
          onSelected: controller.setStatuses,
        ),
        const SizedBox(height: 4),
        _FilterActions(filters: filters),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Chips de estatus (`Todas` + los estatus del contrato).
///
/// Se pueden combinar varios a la vez: «Deudas por vencer» abre con `Apartado` y
/// `Pendiente` marcados a la vez (§8).
class _StatusChips extends ConsumerWidget {
  const _StatusChips({required this.selected, required this.onSelected});

  final List<String> selected;
  final Future<void> Function(List<String>?) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: SalesLabels.statusFilters.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return EzyChip(
              label: 'Todas',
              selected: selected.isEmpty,
              onTap: () => onSelected(null),
            );
          }

          final status = SalesLabels.statusFilters[index - 1];
          final isSelected = selected.contains(status);

          return EzyChip(
            label: SalesLabels.status(status),
            selected: isSelected,
            onTap: () => onSelected(
              isSelected
                  ? selected.where((item) => item != status).toList()
                  : <String>[...selected, status],
            ),
          );
        },
      ),
    );
  }
}

/// Fecha de inicio, fecha final, orden y limpieza de filtros.
class _FilterActions extends ConsumerWidget {
  const _FilterActions({required this.filters});

  final TransactionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(transactionsControllerProvider.notifier);
    final hasFilters = filters.hasFilters;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          EzyChip(
            label: filters.dateStart == null
                ? 'Desde'
                : AppFormatters.date(filters.dateStart),
            icon: Icons.event_outlined,
            selected: filters.dateStart != null,
            onTap: () => _pickDate(context, ref, isStart: true),
          ),
          const SizedBox(width: 8),
          EzyChip(
            label: filters.dateEnd == null
                ? 'Hasta'
                : AppFormatters.date(filters.dateEnd),
            icon: Icons.event_available_outlined,
            selected: filters.dateEnd != null,
            onTap: () => _pickDate(context, ref, isStart: false),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<TransactionSort>(
            tooltip: 'Ordenar',
            onSelected: controller.setSort,
            color: context.surfaces.panel,
            itemBuilder: (context) => <PopupMenuEntry<TransactionSort>>[
              for (final sort in TransactionSort.values)
                PopupMenuItem<TransactionSort>(
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
          if (hasFilters) ...<Widget>[
            const SizedBox(width: 8),
            EzyChip(
              label: 'Limpiar filtros',
              icon: Icons.filter_alt_off_outlined,
              onTap: () => controller.clearFilters(),
            ),
          ],
        ],
      ),
    );
  }

  /// Rango de fechas en formato `d MMM y`; se envía como `YYYY-MM-DD`.
  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final controller = ref.read(transactionsControllerProvider.notifier);

    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? filters.dateStart : filters.dateEnd) ?? today,
      firstDate: DateTime(today.year - 5),
      lastDate: isStart ? (filters.dateEnd ?? today) : today,
      helpText: isStart ? 'Fecha inicial' : 'Fecha final',
    );

    if (picked == null) {
      return;
    }

    if (isStart) {
      return controller.setDateRange(start: picked, end: filters.dateEnd);
    }

    return controller.setDateRange(start: filters.dateStart, end: picked);
  }
}
