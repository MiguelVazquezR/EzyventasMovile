import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
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


/// `2 prod. · 3 arts.`: conteo corto para el badge y la primera línea de la barra
/// flotante del catálogo (§8 del rediseño).
String cartCompactLabel(CartState cart) {
  final products = cart.lines.length;
  final items = Money.formatQuantity(cart.itemCount);

  return '$products prod. · $items arts.';
}

/// Card del desglose financiero de la venta (§4 del rediseño del carrito).
///
/// Subtotal, ahorro —solo cuando existe— y el total a pagar con el monto grande
/// en el naranja de marca. Es la **única** pieza del carrito que resume dinero:
/// el pie solo lleva la acción de cobro.
class CartSummaryCard extends StatelessWidget {
  const CartSummaryCard({super.key, required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final success = StatusPalette.text(context, EzySeverity.success);
    final hasDiscount = cart.totalDiscount != 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
        boxShadow: EzyColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SummaryRow(label: 'Subtotal', value: Money.format(cart.subtotal)),
          if (hasDiscount) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                const _SavingsBadge(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Descuentos',
                    style: EzyTextStyles.body.copyWith(color: success),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '-${Money.format(cart.totalDiscount)}',
                  style: EzyTextStyles.moneyList.copyWith(color: success),
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(height: 1, color: surfaces.borderStrong),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'TOTAL A PAGAR',
                      style: EzyTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: surfaces.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Impuestos incluidos',
                      style: EzyTextStyles.microLabel.copyWith(
                        letterSpacing: 0,
                        fontWeight: FontWeight.w500,
                        color: surfaces.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    Money.format(cart.total),
                    style: const TextStyle(
                      fontFamily: EzyTextStyles.fontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.1,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ).copyWith(color: EzyColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila etiqueta-valor del desglose (subtotal y descuentos).
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: EzyTextStyles.moneyList.copyWith(color: surfaces.textPrimary),
        ),
      ],
    );
  }
}

/// Pastilla «AHORRO» del renglón de descuentos: verde de éxito en su tinte suave.
class _SavingsBadge extends StatelessWidget {
  const _SavingsBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.success),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(EzySeverity.success)),
      ),
      child: Text(
        'AHORRO',
        style: EzyTextStyles.badge.copyWith(
          letterSpacing: 0.6,
          color: StatusPalette.text(context, EzySeverity.success),
        ),
      ),
    );
  }
}

