import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../application/sales_controller.dart';
import '../../data/models/transaction_filters.dart';
import 'sales_labels.dart';

/// Controlador del texto del buscador, compartido con el escáner de la cabecera.
///
/// Vive en un proveedor y no dentro del widget porque el botón de escaneo de la
/// pantalla escribe aquí el código leído: así el campo y el filtro del servidor
/// nunca se separan.
final salesSearchControllerProvider = Provider.autoDispose<TextEditingController>(
  (ref) {
    final controller = TextEditingController();
    ref.onDispose(controller.dispose);

    return controller;
  },
);

/// Filtros del historial: búsqueda, orden, rango de fechas y estatus.
///
/// Todo viaja al servidor (la app no filtra localmente) y cada cambio vuelve a
/// la primera página. `EzySearchField` ya trae el *debounce* de 350 ms y el
/// botón de limpiar del design system; los estatus se pueden combinar y
/// «Limpiar filtros» solo aparece cuando hay algo que limpiar.
class TransactionFiltersBar extends ConsumerStatefulWidget {
  const TransactionFiltersBar({super.key});

  @override
  ConsumerState<TransactionFiltersBar> createState() =>
      _TransactionFiltersBarState();
}

class _TransactionFiltersBarState extends ConsumerState<TransactionFiltersBar> {
  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(
      transactionsControllerProvider.select((state) => state.filters),
    );
    final controller = ref.read(transactionsControllerProvider.notifier);
    final searchController = ref.watch(salesSearchControllerProvider);

    // El texto del campo es la fuente de la búsqueda: si «Limpiar filtros» o el
    // escáner lo cambian por código, el campo tiene que reflejarlo (el listener
    // de `EzySearchField` repinta la «x»).
    ref.listen(transactionsControllerProvider.select((s) => s.filters.search), (
      previous,
      next,
    ) {
      if (searchController.text != next) {
        searchController.text = next;
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: EzySearchField(
                  controller: searchController,
                  hint: 'Buscar por folio o cliente…',
                  height: 40,
                  radius: 12,
                  fillColor: context.surfaces.panel,
                  onChanged: controller.setSearch,
                ),
              ),
              const SizedBox(width: 8),
              _SortButton(sort: filters.sort, onSelected: controller.setSort),
            ],
          ),
          const SizedBox(height: 10),
          _FilterActions(filters: filters),
          const SizedBox(height: 8),
          _StatusChips(
            selected: filters.statuses,
            onSelected: controller.setStatuses,
          ),
        ],
      ),
    );
  }
}


/// Botón de orden: menú emergente con la etiqueta activa y un check.
class _SortButton extends StatelessWidget {
  const _SortButton({required this.sort, required this.onSelected});

  final TransactionSort sort;
  final ValueChanged<TransactionSort> onSelected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return PopupMenuButton<TransactionSort>(
      tooltip: 'Ordenar',
      onSelected: onSelected,
      color: surfaces.panel,
      itemBuilder: (context) => <PopupMenuEntry<TransactionSort>>[
        for (final option in TransactionSort.values)
          PopupMenuItem<TransactionSort>(
            value: option,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.check,
                  size: 16,
                  color: option == sort
                      ? EzyColors.primary
                      : Colors.transparent,
                ),
                const SizedBox(width: 10),
                Text(
                  option.label,
                  style: EzyTextStyles.body.copyWith(
                    color: surfaces.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surfaces.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.sort, size: 18, color: surfaces.textSecondary),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                sort.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fechas del rango y limpieza de filtros.
class _FilterActions extends ConsumerWidget {
  const _FilterActions({required this.filters});

  final TransactionFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(transactionsControllerProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          EzyChip(
            label: 'Desde: ${_dayLabel(filters.dateStart)}',
            icon: Icons.event_outlined,
            compact: true,
            selected: filters.dateStart != null,
            onTap: () => _pickDate(context, ref, isStart: true),
          ),
          const SizedBox(width: 8),
          EzyChip(
            label: 'Hasta: ${_dayLabel(filters.dateEnd)}',
            icon: Icons.event_available_outlined,
            compact: true,
            selected: filters.dateEnd != null,
            onTap: () => _pickDate(context, ref, isStart: false),
          ),
          if (filters.hasFilters) ...<Widget>[
            const SizedBox(width: 8),
            _ClearFiltersButton(onTap: controller.clearFilters),
          ],
        ],
      ),
    );
  }

  /// `DD/MM/AAAA`, con el marcador de posición cuando la fecha no está puesta.
  static String _dayLabel(DateTime? value) {
    if (value == null) {
      return 'DD/MM/AAAA';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
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

/// «Limpiar filtros»: solo aparece con filtros puestos y usa el rojo de peligro
/// de la paleta semántica (§7) para no confundirse con una acción de marca.
class _ClearFiltersButton extends StatelessWidget {
  const _ClearFiltersButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, EzySeverity.danger);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: StatusPalette.soft(EzySeverity.danger),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: StatusPalette.border(EzySeverity.danger)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.filter_alt_off_outlined, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              'Limpiar filtros',
              style: EzyTextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chips de estatus (`Todas` + los estatus del contrato).
///
/// Se pueden combinar varios a la vez: «Deudas por vencer» abre con `Apartado` y
/// `Pendiente` marcados a la vez (§8). El chip activo lleva el check y el
/// naranja de marca; con ninguno puesto manda «Todas».
class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.selected, required this.onSelected});

  final List<String> selected;
  final Future<void> Function(List<String>?) onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SalesLabels.statusFilters.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final all = selected.isEmpty;

            return EzyChip(
              label: 'Todas',
              selected: all,
              icon: all ? Icons.check : null,
              onTap: () => onSelected(null),
            );
          }

          final status = SalesLabels.statusFilters[index - 1];
          final isSelected = selected.contains(status);

          return EzyChip(
            label: SalesLabels.status(status),
            selected: isSelected,
            icon: isSelected ? Icons.check : null,
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
