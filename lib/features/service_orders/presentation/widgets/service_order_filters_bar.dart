import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/scanner/scanner_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../application/service_orders_controller.dart';
import '../../data/models/service_order_filters.dart';
import 'service_order_labels.dart';

/// Filtros del listado: búsqueda con escáner, chips de estatus y orden.
///
/// Todo viaja al servidor (la app no filtra localmente) y cada cambio vuelve a
/// la primera página. La búsqueda la resuelve `EzySearchField`, que ya trae el
/// *debounce* y el botón de limpiar del design system; el hueco de la derecha
/// (`trailing`) es el escáner de códigos, que escribe lo leído en el buscador:
/// así el folio de la etiqueta de la orden encuentra la orden sin teclear. El
/// orden del listado vive en la misma fila, como acción de 40 px a la
/// derecha del campo.
class ServiceOrderFiltersBar extends ConsumerStatefulWidget {
  const ServiceOrderFiltersBar({super.key});

  @override
  ConsumerState<ServiceOrderFiltersBar> createState() =>
      _ServiceOrderFiltersBarState();
}

class _ServiceOrderFiltersBarState
    extends ConsumerState<ServiceOrderFiltersBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Abre el escáner y, si devuelve un código, lo busca en el servidor.
  ///
  /// El texto se escribe en el campo para que el usuario vea qué se buscó y
  /// pueda corregirlo o limpiarlo con la «x» del design system.
  Future<void> _scan() async {
    final code = await ref.read(scannerLauncherProvider)(context);

    if (!mounted || code == null || code.trim().isEmpty) {
      return;
    }

    final value = code.trim();
    _searchController.text = value;
    await ref.read(serviceOrdersControllerProvider.notifier).setSearch(value);
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(serviceOrdersControllerProvider.notifier).clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(
      serviceOrdersControllerProvider.select((state) => state.filters),
    );
    final controller = ref.read(serviceOrdersControllerProvider.notifier);

    // El buscador puede vaciarse desde fuera («Limpiar filtros» del estado
    // vacío, en la pantalla): el campo sigue al estado real de los filtros.
    ref.listen(
      serviceOrdersControllerProvider.select((state) => state.filters.search),
      (previous, next) {
        if (next != _searchController.text) {
          _searchController.text = next;
        }
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: EzySearchField(
                  controller: _searchController,
                  hint: 'Buscar por folio, cliente o equipo…',
                  height: 44,
                  trailing: EzyIconButton(
                    icon: Icons.qr_code_scanner,
                    size: 40,
                    iconSize: 20,
                    tooltip: 'Escanear código',
                    onTap: _scan,
                  ),
                  onChanged: controller.setSearch,
                ),
              ),
              const SizedBox(width: 8),
              _SortButton(filters: filters),
            ],
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
        // El acceso a limpiar solo existe cuando hay algo que limpiar: con los
        // seis estatus a la vista, un chip muerto solo ocuparía una fila.
        if (filters.hasFilters) ...<Widget>[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EzyChip(
              label: 'Limpiar filtros',
              icon: Icons.filter_alt_off_outlined,
              onTap: _clearFilters,
            ),
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Orden del listado: menú emergente de 200 px con la opción vigente marcada.
class _SortButton extends ConsumerWidget {
  const _SortButton({required this.filters});

  final ServiceOrderFilters filters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(serviceOrdersControllerProvider.notifier);

    return PopupMenuButton<ServiceOrderSort>(
      initialValue: filters.sort,
      tooltip: 'Ordenar',
      onSelected: controller.setSort,
      color: context.surfaces.panel,
      elevation: 8,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 200),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => <PopupMenuEntry<ServiceOrderSort>>[
        for (final sort in ServiceOrderSort.values)
          PopupMenuItem<ServiceOrderSort>(
            value: sort,
            height: 48,
            child: Row(
              children: <Widget>[
                if (sort == filters.sort)
                  const Icon(Icons.check, size: 14, color: EzyColors.primary)
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    sort.label,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.body.copyWith(
                      color: sort == filters.sort
                          ? EzyColors.primary
                          : context.surfaces.textPrimary,
                      fontWeight: sort == filters.sort
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: EzyChip(label: filters.sort.label, icon: Icons.sort),
    );
  }
}
