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

/// Nombres de las líneas del carrito, para la vista previa de la barra (§9).
///
/// Se corta en [maxNames] para que la línea no crezca sin fin y el resto se
/// resume con `+N`. Cada línea se identifica con su `description` (producto y
/// variante): dos tallas del mismo artículo son dos líneas distintas.
String cartPreviewLabel(CartState cart, {int maxNames = 3}) {
  final names = cart.lines
      .take(maxNames)
      .map((line) => line.description)
      .toList(growable: true);
  final rest = cart.lines.length - names.length;

  if (rest > 0) {
    names.add('+$rest más');
  }

  return names.join(', ');
}

