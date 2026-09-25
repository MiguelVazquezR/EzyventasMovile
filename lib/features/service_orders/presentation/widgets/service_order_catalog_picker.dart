import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_list_tile.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../catalog/application/catalog_pickers.dart';
import '../../../catalog/application/catalog_providers.dart';
import '../../../catalog/data/models/catalog_service.dart';
import '../../../catalog/data/models/product.dart';
import '../../data/models/service_order_detail.dart';
import '../../data/models/service_order_item_draft.dart';
import 'service_order_form_controls.dart';
import 'service_order_variant_picker.dart';

/// Tipo de catálogo que ofrece el selector de conceptos.
enum ServiceOrderCatalogKind { service, product }

/// Selector de conceptos del catálogo (`GET /catalog/services` y
/// `GET /catalog/products`).
///
/// Devuelve el concepto elegido con su `itemable_type`/`itemable_id` y el
/// precio que ya calculó el servidor; las variantes se eligen antes de
/// regresar (una refacción con variantes descuenta el stock de la variante).
Future<ServiceOrderItemDraft?> showServiceOrderCatalogPicker(
  BuildContext context,
) {
  return showModalBottomSheet<ServiceOrderItemDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => const _CatalogPickerSheet(),
  );
}

class _CatalogPickerSheet extends ConsumerStatefulWidget {
  const _CatalogPickerSheet();

  @override
  ConsumerState<_CatalogPickerSheet> createState() =>
      _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends ConsumerState<_CatalogPickerSheet> {
  ServiceOrderCatalogKind _kind = ServiceOrderCatalogKind.service;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(
      servicesProvider(_search.isEmpty ? null : _search),
    );
    final products = ref.watch(productSearchProvider(_search));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          EzySheetHeader(
            title: 'Agregar concepto',
            subtitle: 'Elige del catálogo o captura un concepto libre.',
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          ServiceOrderSegmentedControl<ServiceOrderCatalogKind>(
            values: const <ServiceOrderCatalogKind>[
              ServiceOrderCatalogKind.service,
              ServiceOrderCatalogKind.product,
            ],
            selected: _kind,
            labelOf: (kind) => kind == ServiceOrderCatalogKind.service
                ? 'Mano de obra'
                : 'Refacciones',
            onSelected: (kind) => setState(() => _kind = kind),
          ),
          const SizedBox(height: 12),
          EzySearchField(
            hint: 'Buscar en el catálogo…',
            onChanged: (value) => setState(() => _search = value.trim()),
          ),
          const SizedBox(height: 16),
          if (_kind == ServiceOrderCatalogKind.service)
            _ServicesList(services: services, onSelected: _selectService)
          else
            _ProductsList(products: products, onSelected: _selectProduct),
        ],
      ),
    );
  }

  /// Servicio (o su variante) como concepto de la orden.
  Future<void> _selectService(CatalogService service) async {
    if (!service.hasVariants) {
      Navigator.of(context).pop(
        ServiceOrderItemDraft(
          description: service.name,
          quantity: 1,
          unitPrice: service.basePrice,
          itemableType: ServiceOrderItemType.service,
          itemableId: service.id,
        ),
      );

      return;
    }

    final variant = await showServiceOrderVariantPicker(
      context,
      title: service.name,
      options: <VariantOption>[
        for (final item in service.variants)
          VariantOption(
            id: item.id,
            label: item.name,
            price: item.price,
            itemableType: ServiceOrderItemType.serviceVariant,
          ),
      ],
    );

    if (variant == null || !mounted) {
      return;
    }

    Navigator.of(context).pop(
      ServiceOrderItemDraft(
        description: '${service.name} · ${variant.label}',
        quantity: 1,
        unitPrice: variant.price,
        itemableType: variant.itemableType,
        itemableId: variant.id,
      ),
    );
  }

  /// Producto (o su combinación de variantes) como refacción de la orden.
  Future<void> _selectProduct(Product product) async {
    if (product.variantCombinations.isEmpty) {
      Navigator.of(context).pop(
        ServiceOrderItemDraft(
          description: product.name,
          quantity: 1,
          unitPrice: product.price,
          itemableType: ServiceOrderItemType.product,
          itemableId: product.id,
        ),
      );

      return;
    }

    final variant = await showServiceOrderVariantPicker(
      context,
      title: product.name,
      options: <VariantOption>[
        for (final combination in product.variantCombinations)
          VariantOption(
            id: combination.id,
            label: combination.label,
            price: combination.price,
            itemableType: ServiceOrderItemType.productAttribute,
          ),
      ],
    );

    if (variant == null || !mounted) {
      return;
    }

    Navigator.of(context).pop(
      ServiceOrderItemDraft(
        description: '${product.name} · ${variant.label}',
        quantity: 1,
        unitPrice: variant.price,
        itemableType: variant.itemableType,
        itemableId: variant.id,
      ),
    );
  }
}

/// Lista de servicios del catálogo con su precio más bajo.
class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.services, required this.onSelected});

  final AsyncValue<Paginated<CatalogService>> services;
  final ValueChanged<CatalogService> onSelected;

  @override
  Widget build(BuildContext context) {
    return services.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => const NoticeBanner(
        message: 'No se pudo cargar el catálogo de servicios.',
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const NoticeBanner(
            message: 'No hay servicios que coincidan con la búsqueda.',
            tone: EzySeverity.info,
          );
        }

        return Column(
          children: <Widget>[
            for (final service in page.items)
              _CatalogTile(
                title: service.name,
                subtitle: <String>[
                  if (service.category != null) service.category!,
                  if (service.hasVariants)
                    '${service.variants.length} variantes'
                  else
                    'Precio de lista',
                ].join(' · '),
                price: Money.format(service.lowestPrice),
                onTap: () => onSelected(service),
              ),
          ],
        );
      },
    );
  }
}

/// Lista de productos (refacciones) del catálogo.
class _ProductsList extends StatelessWidget {
  const _ProductsList({required this.products, required this.onSelected});

  final AsyncValue<Paginated<Product>> products;
  final ValueChanged<Product> onSelected;

  @override
  Widget build(BuildContext context) {
    return products.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) => const NoticeBanner(
        message: 'No se pudo cargar el catálogo de productos.',
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const NoticeBanner(
            message: 'No hay productos que coincidan con la búsqueda.',
            tone: EzySeverity.info,
          );
        }

        return Column(
          children: <Widget>[
            for (final product in page.items)
              _CatalogTile(
                title: product.name,
                subtitle: <String>[
                  if (product.sku != null) 'SKU ${product.sku}',
                  'Stock ${Money.formatQuantity(product.stock)}',
                  if (product.variantCombinations.isNotEmpty)
                    '${product.variantCombinations.length} variantes',
                ].join(' · '),
                price: Money.format(product.price),
                onTap: () => onSelected(product),
              ),
          ],
        );
      },
    );
  }
}

/// Concepto del catálogo (servicio o refacción) como fila del design system.
class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return EzyListTile(
      title: title,
      subtitle: subtitle,
      value: price,
      onTap: onTap,
    );
  }
}
