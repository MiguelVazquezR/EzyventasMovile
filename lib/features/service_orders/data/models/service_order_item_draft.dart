import '../../../../core/utils/money.dart';
import 'service_order_detail.dart';

/// Concepto que el formulario manda en `items[]`.
///
/// `line_total` se calcula con [Money.round2] para que el total que se envía al
/// servidor no arrastre errores de coma flotante; el servidor vuelve a validar
/// cada línea.
class ServiceOrderItemDraft {
  const ServiceOrderItemDraft({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.itemableType,
    this.itemableId,
  });

  /// Precarga un concepto de una orden existente (formulario de edición).
  factory ServiceOrderItemDraft.fromItem(ServiceOrderItem item) =>
      ServiceOrderItemDraft(
        description: item.description,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        itemableType: item.itemableType,
        itemableId: item.itemableId,
      );

  /// `null` = concepto libre (no está en el catálogo).
  final String? itemableType;
  final int? itemableId;
  final String description;
  final double quantity;

  /// Precio unitario capturado por el usuario.
  final double unitPrice;

  /// `quantity × unit_price`.
  double get lineTotal => Money.round2(quantity * unitPrice);

  /// Viene del catálogo (`App\Models\Service`, `...\Product`, ...).
  bool get isFromCatalog => (itemableId ?? 0) > 0 && (itemableType ?? '').isNotEmpty;

  /// Refacción del inventario: descuenta stock al guardar la orden.
  bool get isPart =>
      itemableType == ServiceOrderItemType.product ||
      itemableType == ServiceOrderItemType.productAttribute;

  String get typeLabel => isFromCatalog
      ? ServiceOrderItemType.labelOf(itemableType)
      : 'Concepto libre';

  ServiceOrderItemDraft copyWith({
    String? description,
    double? quantity,
    double? unitPrice,
  }) => ServiceOrderItemDraft(
    description: description ?? this.description,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    itemableType: itemableType,
    itemableId: itemableId,
  );

  /// Objeto anidado (`items[]` cuando el cuerpo viaja como JSON).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemable_type': itemableType,
    'itemable_id': itemableId,
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice,
    'line_total': lineTotal,
  };

  /// Claves planas de `multipart/form-data` (`items[0][quantity]=1`).
  Map<String, dynamic> toMultipartFields(int index) => <String, dynamic>{
    'items[$index][itemable_type]': itemableType,
    'items[$index][itemable_id]': itemableId,
    'items[$index][description]': description,
    'items[$index][quantity]': quantity,
    'items[$index][unit_price]': unitPrice,
    'items[$index][line_total]': lineTotal,
  };
}
