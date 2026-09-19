/// Datos del pedido / comanda (`POST /pos/store-order`).
///
/// El pedido **no** lleva pagos: el stock queda reservado y se cobra después
/// (desde el historial o la web).
class StoreOrderDraft {
  const StoreOrderDraft({
    required this.contactName,
    required this.deliveryDate,
    this.contactPhone,
    this.type = pedido,
    this.shippingAddress,
    this.shippingCost = 0,
    this.notes,
  });

  /// Retail.
  static const String pedido = 'pedido';

  /// Modo comandas / restaurante.
  static const String comanda = 'comanda';

  /// Nombre de quien recibe el pedido (obligatorio, mín. 2 caracteres).
  final String contactName;
  final String? contactPhone;

  /// `pedido` | `comanda`.
  final String type;

  /// Fecha y hora de entrega (obligatoria).
  final DateTime deliveryDate;
  final String? shippingAddress;
  final double shippingCost;
  final String? notes;

  bool get isComanda => type == comanda;
  bool get hasShippingAddress =>
      shippingAddress != null && shippingAddress!.trim().isNotEmpty;

  Map<String, dynamic> toContactInfoJson() => <String, dynamic>{
    'name': contactName.trim(),
    'phone': contactPhone?.trim(),
    'type': type,
  };
}
