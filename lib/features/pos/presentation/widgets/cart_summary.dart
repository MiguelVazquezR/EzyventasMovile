import '../../../../core/utils/money.dart';
import '../../application/cart_state.dart';

/// `2 productos · 3 artículos`: resumen humano del carrito (§9).
///
/// Lo comparten la barra del pie (`CartBar`) y la cabecera de la hoja del
/// carrito, para que el mismo carrito se cuente igual en los dos sitios y el
/// conteo no se quede a medias en una de las dos pantallas.
String cartSummaryLabel(CartState cart) {
  final productCount = cart.lines.length;
  final products = '$productCount producto${productCount == 1 ? '' : 's'}';
  final items = Money.formatQuantity(cart.itemCount);
  final unit = cart.itemCount == 1 ? 'artículo' : 'artículos';

  return '$products · $items $unit';
}
