import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/paginated.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
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
    backgroundColor: SoColors.canvas(context),
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
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
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: <Widget>[
          const SizedBox(height: 8),
          SoSheetHeader(
            title: 'Agregar concepto',
            subtitle: 'Elige un servicio o refacción del catálogo.',
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 16),
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
            fillColor: SoColors.card(context),
            borderColor: SoColors.structuralBorder(context),
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
      loading: () => const _PickerLoading(),
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

        return _CatalogList(
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
      loading: () => const _PickerLoading(),
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

        return _CatalogList(
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

/// Lista de conceptos con separación uniforme de 8 px.
class _CatalogList extends StatelessWidget {
  const _CatalogList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < children.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 8),
          children[index],
        ],
      ],
    );
  }
}

/// Espera del catálogo: spinner naranja centrado con aire arriba y abajo.
class _PickerLoading extends StatelessWidget {
  const _PickerLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: SoColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Concepto del catálogo (servicio o refacción) como fila del design system.
class _CatalogTile extends StatefulWidget {
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
  State<_CatalogTile> createState() => _CatalogTileState();
}

class _CatalogTileState extends State<_CatalogTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: SoColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pressed
                ? SoColors.primary
                : SoColors.structuralBorder(context),
          ),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: SoColors.textPrimary(context),
                    ),
                  ),
                  if (widget.subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.caption.copyWith(
                        color: SoColors.textMuted(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.price,
              style: EzyTextStyles.moneyList.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: SoColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: SoColors.textMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}
