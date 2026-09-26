import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_amount.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import 'cart_sheet.dart';
import 'cart_summary.dart';

/// Barra del carrito: card flotante oscura con el contador, la vista previa, el
/// total y el acceso al cobro (§8, §9.4).
///
/// Va separada de los bordes y **dentro** del `Column` del POS, debajo del
/// catálogo, así que nunca tapa una tarjeta. Es oscura en los dos temas
/// (`surfaceDark` con texto blanco) porque es la única pieza de la pantalla que
/// corta el fondo en lugar de apoyarse en él: el pulgar la encuentra siempre en el
/// mismo sitio y con el mismo aspecto.
///
/// **Un solo blanco táctil.** Toda la barra abre la hoja del carrito, que es
/// donde viven las acciones de cobro; el chevron de la derecha es la parte
/// visible de esa misma acción, no un segundo gesto (con el carrito vacío el
/// acceso sigue estando).
///
/// Solo aparece con el permiso `pos.create_sale`; sin sesión de caja abierta
/// avisa en la primera línea (el servidor respondería `session_required`).
class CartBar extends ConsumerWidget {
  const CartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);

    if (!permissions.can('pos.create_sale')) {
      return const SizedBox.shrink();
    }

    final hasSession = session != null;
    final isEmpty = cart.isEmpty;

    return Padding(
      // Mismo margen lateral que el resto de la pantalla y 12 px de respiro al
      // pie: la barra flota, pero no se despega del borde inferior.
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GestureDetector(
        onTap: () => showCartSheet(context),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: EzyColors.surfaceDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: EzyColors.borderDarkStrong),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: EzyColors.black2.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              _CartBadge(isEmpty: isEmpty),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      // Con turno abierto y el carrito vacío el resumen no dice
                      // nada (`0 productos · 0 artículos` y encima se corta): se
                      // resume el estado del turno.
                      hasSession
                          ? (isEmpty ? 'Turno abierto' : cartSummaryLabel(cart))
                          : 'Sin turno abierto',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.caption.copyWith(
                        color: hasSession
                            ? EzyColors.textMutedDark
                            : EzyColors.warning,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEmpty ? 'Carrito vacío' : cartPreviewLabel(cart),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        color: EzyColors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // `FittedBox` con `scaleDown`: el monto conserva su tamaño y, si
              // aún así no cabe (totales de siete cifras en un teléfono
              // estrecho), se encoge en lugar de partirse en dos renglones.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: EzyAmount(
                    value: cart.total,
                    size: EzyAmountSize.bar,
                    color: EzyColors.white,
                    alignment: CrossAxisAlignment.end,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const _CartChevron(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carrito en miniatura de la barra: se enciende cuando hay algo que cobrar.
class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.isEmpty});

  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isEmpty
            ? EzyColors.surfaceDarkInner
            : EzyColors.primary.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: isEmpty
              ? EzyColors.borderDark
              : EzyColors.primary.withValues(alpha: 0.6),
        ),
      ),
      child: Icon(
        Icons.shopping_bag_outlined,
        size: 18,
        color: isEmpty ? EzyColors.textMutedDark : EzyColors.primary,
      ),
    );
  }
}

/// Chevron del acceso al carrito: la parte visible del toque de la barra.
///
/// Sustituyó a la pastilla «Ver carrito», que robaba al total el ancho que
/// necesita para no partirse en dos renglones: hacia dónde se abre la hoja lo
/// dice la flecha, toda la barra sigue siendo el blanco táctil y el rótulo vive
/// en el `Tooltip` (y en el lector de pantalla).
///
/// No lleva gesto propio a propósito: quien lo toca toca la barra, y un
/// reconocedor dentro de otro abriría la hoja dos veces.
class _CartChevron extends StatelessWidget {
  const _CartChevron();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ver carrito',
      child: Icon(
        Icons.chevron_right,
        size: 26,
        color: EzyColors.textSecondaryDark,
        semanticLabel: 'Ver carrito',
      ),
    );
  }
}

