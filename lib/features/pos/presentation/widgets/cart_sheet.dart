import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permissions_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_dialog.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../customers/data/models/customer.dart';
import '../../application/cart_controller.dart';
import '../../application/cart_state.dart';
import 'cart_line_tile.dart';
import 'cart_summary.dart';
import 'customer_picker_sheet.dart';
import 'payment_sheet.dart';
import 'sale_result_view.dart';
import 'store_order_sheet.dart';

/// Abre el carrito del POS (líneas, cliente, totales y acciones de cobro).
Future<void> showCartSheet(BuildContext context) {
  return EzyBottomSheet.show<void>(
    context,
    maxHeightFactor: 0.96,
    // §3 del rediseño: el carrito se apoya en el **mismo** lienzo del POS, de
    // modo que la hoja se lea como un paso de la pantalla y no como otra pantalla
    // encima. Las tarjetas blancas y su sombra son las que dan el relieve.
    backgroundColor: context.surfaces.background,
    // El asa la pinta la hoja (§1 del rediseño) con el borde fuerte del sistema:
    // por eso se apaga la del tema y se dibuja la propia.
    showDragHandle: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => const CartSheet(),
  );
}

/// Carrito dentro de la hoja estándar: cabecera con el conteo, líneas con scroll,
/// resumen de venta y el cierre de venta **fijo** al pie (§1, §4 y §5 del
/// rediseño del carrito).
///
/// La jerarquía sigue al diseño: cliente → lista de artículos → resumen → pie de
/// acciones. El monto ya no se repite en una franja arriba del todo: el total
/// vive una sola vez, en el resumen, y el conteo de la cabecera da la pista
/// rápida de lo que hay en el carrito.
class CartSheet extends ConsumerWidget {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final result = cart.result;

    if (result != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: <Widget>[
          SaleResultView(
            result: result,
            onDone: () {
              controller.consumeResult();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _DragHandle(),
        _CartHeader(cart: cart),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              const _CustomerRow(),
              const SizedBox(height: 16),
              _LinesHeader(cart: cart, onClear: controller.clear),
              const SizedBox(height: 12),
              for (final line in cart.lines) CartLineTile(line: line),
              if (cart.isEmpty)
                const EmptyState(
                  compact: true,
                  icon: Icons.shopping_cart_outlined,
                  title: 'El carrito está vacío',
                  message:
                      'Agrega productos desde el catálogo para empezar la '
                      'venta.',
                ),
              if (cart.notice != null) ...<Widget>[
                const SizedBox(height: 12),
                NoticeBanner(
                  message: cart.notice!,
                  tone: EzySeverity.warn,
                  actionLabel: 'Ocultar',
                  onAction: controller.consumeNotice,
                ),
              ],
              const SizedBox(height: 12),
              CartSummaryCard(cart: cart),
            ],
          ),
        ),
        // El cobro no se busca bajando: vive fijo al pie de la hoja (§5), sobre el
        // mismo lienzo del carrito para que el botón flote y no se lea como otro
        // panel encima del resumen.
        EzyActionBar(
          backgroundColor: context.surfaces.background,
          child: const _CheckoutSection(),
        ),
      ],
    );
  }
}

/// Pide confirmación antes de vaciar el carrito (§2 del rediseño).
///
/// Es la única acción del carrito que no se puede deshacer, así que pasa por el
/// diálogo del sistema y solo limpia el carrito si el cajero confirma. El botón
/// que la abre y el que la confirma se llaman igual (`Vaciar`) para que la
/// acción no cambie de palabra entre paso y paso.
Future<void> _confirmClearCart(
  BuildContext context,
  VoidCallback onClear,
) async {
  final confirmed = await showEzyConfirmDialog(
    context,
    title: 'Vaciar carrito',
    message:
        'Se quitarán todos los artículos del carrito. '
        'Esta acción no se puede deshacer.',
    confirmLabel: 'Vaciar',
    isDestructive: true,
  );

  if (confirmed) {
    onClear();
  }
}

/// Encabezado de la lista de líneas, con «Vaciar» a la derecha (§1 y §3).
///
/// El vaciado vive pegado a lo que vacía y no al final del scroll: es una acción
/// destructiva y tiene que verse **antes** de las líneas, no después. Va en el
/// tono de peligro del sistema —texto y papelera a 14 px— y confirma antes de
/// limpiar (§3): el carrito no se pierde por un toque de más.
class _LinesHeader extends StatelessWidget {
  const _LinesHeader({required this.cart, required this.onClear});

  final CartState cart;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'ARTÍCULOS EN ORDEN',
            style: EzyTextStyles.microLabel.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.surfaces.textMuted,
            ),
          ),
        ),
        _ClearCartButton(
          onPressed: cart.isEmpty
              ? null
              : () => _confirmClearCart(context, onClear),
        ),
      ],
    );
  }
}

/// «Vaciar» en el tono de peligro: icono de 14 px y texto sin relleno.
class _ClearCartButton extends StatelessWidget {
  const _ClearCartButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled
        ? StatusPalette.text(context, EzySeverity.danger)
        : context.surfaces.textMuted;

    return Tooltip(
      message: 'Quitar todos los artículos del carrito',
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.delete_outline, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                'Vaciar',
                style: EzyTextStyles.bodyStrong.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cliente de la venta (o público general con nombre opcional) (§2).
///
/// Es una **tarjeta táctil**: el cuadro del icono a la izquierda, la etiqueta y
/// el nombre con sus chips de saldo y crédito en el centro, y el chevron en su
/// círculo a la derecha. La tarjeta entera abre el selector de clientes, que es
/// la única interacción de la fila.
class _CustomerRow extends ConsumerWidget {
  const _CustomerRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final cart = ref.watch(cartControllerProvider);
    final customer = cart.customer;
    final guestName = cart.guestName.trim();

    return GestureDetector(
      onTap: () => showCustomerPickerSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaces.border, width: 1.5),
          boxShadow: EzyColors.cardShadow,
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: EzyColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: EzyColors.primary.withValues(alpha: 0.20),
                ),
              ),
              child: const Icon(
                Icons.person_outline,
                size: 20,
                color: EzyColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'CLIENTE',
                    style: EzyTextStyles.microLabel.copyWith(
                      fontSize: 10.5,
                      color: surfaces.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    customer?.displayName ??
                        (guestName.isEmpty ? 'Público general' : guestName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: surfaces.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _CustomerBalances(customer: customer),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: surfaces.panelInner,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: surfaces.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renglón de datos del cliente (§2): chips de saldo y crédito, o la pista de
/// que la tarjeta abre el selector.
class _CustomerBalances extends StatelessWidget {
  const _CustomerBalances({required this.customer});

  /// Cliente de la venta; `null` = público general.
  final Customer? customer;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final current = customer;
    final balance = current?.balance ?? 0;

    if (current == null) {
      return Text(
        'Toca para elegir o cambiar el cliente.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: EzyTextStyles.caption.copyWith(
          fontSize: 11,
          color: surfaces.textMuted,
        ),
      );
    }

    if (balance == 0 && !current.hasCredit) {
      return Text(
        'Sin saldo pendiente.',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: EzyTextStyles.caption.copyWith(
          fontSize: 11,
          color: surfaces.textMuted,
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        if (balance != 0)
          _CustomerChip(
            icon: Icons.savings_outlined,
            label: 'Saldo: ${Money.format(balance)}',
            severity: EzySeverity.success,
          ),
        if (current.hasCredit)
          _CustomerChip(
            icon: Icons.credit_score_outlined,
            label: 'Crédito: ${Money.format(current.availableCredit)}',
          ),
      ],
    );
  }
}

/// Chip de dato del cliente (§2): saldo a favor en verde, crédito en neutro.
class _CustomerChip extends StatelessWidget {
  const _CustomerChip({
    required this.icon,
    required this.label,
    this.severity,
  });

  final IconData icon;
  final String label;

  /// Severidad del chip; `null` = tono neutro del sistema.
  final EzySeverity? severity;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final tint = severity;
    final color = tint == null
        ? surfaces.textMuted
        : StatusPalette.text(context, tint);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tint == null ? surfaces.panelInner : StatusPalette.soft(tint),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: tint == null ? surfaces.border : StatusPalette.border(tint),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: EzyTextStyles.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}



/// Cabecera de la hoja del carrito (§1).
///
/// Título a 20 px en negrita fuerte, el conteo en el tono apagado y la X de
/// cierre en su círculo de 32 px sobre el panel: es la salida de la hoja y el
/// único control de la cabecera.
class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Carrito',
                  style: EzyTextStyles.screenTitle.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: surfaces.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  cartSummaryLabel(cart),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: surfaces.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          EzyIconButton(
            icon: Icons.close,
            tooltip: 'Cerrar',
            size: 32,
            iconSize: 16,
            background: surfaces.panel,
            borderColor: surfaces.border,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Asa de la hoja (§1): 40 × 5 px, totalmente redondeada, en el borde fuerte.
///
/// Se dibuja aquí en lugar de usar la del tema porque el carrito la quiere en su
/// propio tono; el resto de hojas sigue con la suya.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 5,
        margin: const EdgeInsets.only(top: 10, bottom: 12),
        decoration: BoxDecoration(
          color: context.surfaces.borderStrong,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// Cierre de la venta (§5): un solo **Finalizar compra** con su menú.
///
/// El pie tenía tres botones en fila y en un teléfono cada uno quedaba en un
/// tercio del ancho, con las tres etiquetas apretadas. Ahora la acción principal
/// va a 2/3 del ancho, centrada, y las tres formas de cerrar la venta salen
/// apiladas en un menú emergente hacia arriba: **Pago al contado**, **Apartar**
/// y **Pedido**.
///
/// Sin sesión de caja abierta el servidor responde `session_required`, así que
/// la app bloquea el botón y lleva al flujo de apertura.
class _CheckoutSection extends ConsumerStatefulWidget {
  const _CheckoutSection();

  @override
  ConsumerState<_CheckoutSection> createState() => _CheckoutSectionState();
}

class _CheckoutSectionState extends ConsumerState<_CheckoutSection> {
  /// Menú de cierre de venta: el popover que sale arriba del botón.
  final OverlayPortalController _menu = OverlayPortalController();

  /// Botón primario del pie: con él se mide y se centra el menú.
  final GlobalKey _anchorKey = GlobalKey();

  /// Rectángulo del botón **en coordenadas de la pantalla**, medido al abrirlo.
  ///
  /// Se mide en el toque y no al pintar el menú: dentro del `build` el árbol aún
  /// no tiene tamaño, y el popover tiene que salir pegado al botón que lo abre.
  Rect? _anchor;

  /// Abre o cierra el menú midiendo antes el botón para anclarlo.
  void _toggleMenu() {
    if (_menu.isShowing) {
      _menu.hide();
      return;
    }

    final anchor = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    _anchor = anchor != null && anchor.hasSize
        ? anchor.localToGlobal(Offset.zero) & anchor.size
        : null;

    _menu.show();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);
    final canSell = permissions.can('pos.create_sale');

    if (!canSell) {
      return const NoticeBanner(
        message: 'Tu usuario no tiene permiso para esta acción.',
        tone: EzySeverity.info,
      );
    }

    // Sin caja abierta, con el carrito vacío o con la venta en curso no hay nada
    // que cerrar: el botón se apaga y el aviso de arriba dice por qué.
    final enabled = session != null && !cart.isEmpty && !cart.isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (session == null) ...<Widget>[
          NoticeBanner(
            message:
                'Necesitas una sesión de caja abierta para registrar ventas.',
            tone: EzySeverity.warn,
            actionLabel: 'Ir a Caja',
            onAction: () {
              Navigator.of(context).pop();
              context.go(AppTab.cashRegister.path);
            },
          ),
          const SizedBox(height: 12),
        ],
        OverlayPortal(
          controller: _menu,
          overlayChildBuilder: _buildMenu,
          child: EzyPrimary3dButton(
            anchorKey: _anchorKey,
            label: 'Finalizar compra',
            trailingIcon: Icons.keyboard_arrow_up_rounded,
            height: _checkoutButtonHeight,
            widthFactor: 0.75,
            maxWidth: _checkoutButtonMaxWidth,
            isLoading: cart.isSubmitting,
            onPressed: enabled ? _toggleMenu : null,
          ),
        ),
      ],
    );
  }

  /// Cierra el menú y ejecuta la opción elegida **después** de repintar: la hoja
  /// que abre (cobro, apartado o pedido) no puede quedar debajo del popover.
  void _run(void Function(BuildContext context) action) {
    _menu.hide();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        action(context);
      }
    });
  }

  /// Opciones apiladas arriba del botón primario (§5).
  ///
  /// La posición sale del ancho real del botón y del alto real de la pantalla, no
  /// de constantes: en un teléfono el menú queda a lo ancho del botón y en una
  /// tablet no se estira de más. El tamaño de la pantalla lo da el `LayoutBuilder`
  /// —el `Overlay` no se puede medir desde el `build`—.
  Widget _buildMenu(BuildContext overlayContext) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (layoutContext, constraints) {
          final size = constraints.biggest;
          final anchor = _anchor;

          // El menú hereda el ancho del botón que lo abre, con dos límites: nunca
          // menos de 288 px —los subtítulos se leen de una línea— ni más que la
          // pantalla.
          final double byAnchor = anchor?.width ?? size.width - 48;
          final double preferred = byAnchor > 288 ? byAnchor : 288.0;
          final double width = preferred > size.width - 24
              ? size.width - 24
              : preferred;
          final double left = anchor != null
              ? (anchor.left + (anchor.width - width) / 2).clamp(
                  12,
                  size.width - width - 12,
                )
              : (size.width - width) / 2;

          // Pegado al borde de arriba del botón, con 8 px de aire.
          final double bottom = anchor != null
              ? size.height - anchor.top + 8
              : 12;

          return Stack(
            children: <Widget>[
              // Barrera: un toque fuera del menú lo cierra, como a cualquier
              // popover.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _menu.hide,
                ),
              ),
              Positioned(
                left: left,
                bottom: bottom,
                width: width,
                child: _CheckoutMenu(
                  onCheckout: () => _run(
                    (menuContext) => showPaymentSheet(
                      menuContext,
                      mode: PaymentMode.checkout,
                    ),
                  ),
                  onLayaway: () => _run(
                    (menuContext) => showPaymentSheet(
                      menuContext,
                      mode: PaymentMode.layaway,
                    ),
                  ),
                  onStoreOrder: () => _run(showStoreOrderSheet),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Alto del botón que cierra la venta (52 px) y ancho máximo en tablet.
///
/// El botón en sí es el CTA 3D compartido (`EzyPrimary3dButton`, §6 del
/// rediseño): aquí solo viven las medidas que el carrito le pasa y con las que
/// `_buildMenu` lo mide para colgarle el menú arriba.
const double _checkoutButtonHeight = 52;
const double _checkoutButtonMaxWidth = 280;





/// Menú del cierre de venta: las tres formas de cerrar la venta (§5).
///
/// No son botones: son **opciones de lista** con el icono en su recuadro, el
/// título y una línea que explica qué pasa, separadas por un filo. Es una card
/// flotante, así que lleva la sombra profunda que el resto del design system no
/// necesita: tiene que despegarse del carrito que tapa.
class _CheckoutMenu extends StatelessWidget {
  const _CheckoutMenu({
    required this.onCheckout,
    required this.onLayaway,
    required this.onStoreOrder,
  });

  final VoidCallback onCheckout;
  final VoidCallback onLayaway;
  final VoidCallback onStoreOrder;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaces.borderStrong),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: EzyColors.black2.withValues(alpha: 0.45),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CheckoutMenuOption(
            icon: Icons.payments_outlined,
            title: 'Pago al contado',
            subtitle: 'Cobrar ahora en efectivo, tarjeta o transferencia',
            severity: EzySeverity.success,
            onTap: onCheckout,
          ),
          const _MenuSeparator(),
          _CheckoutMenuOption(
            icon: Icons.bookmark_outline,
            title: 'Apartar',
            subtitle: 'Pedir enganche y reservar las piezas del carrito',
            severity: EzySeverity.warn,
            onTap: onLayaway,
          ),
          const _MenuSeparator(),
          _CheckoutMenuOption(
            icon: Icons.receipt_long_outlined,
            title: 'Pedido',
            subtitle: 'Guardar la orden abierta para entregarla después',
            severity: EzySeverity.info,
            onTap: onStoreOrder,
          ),
        ],
      ),
    );
  }
}

/// Opción del menú de cierre de venta (§5).
///
/// Icono en su recuadro con el color semántico de la acción, el título en el
/// color del texto principal y una línea de apoyo: así se entiende qué hace cada
/// forma de cerrar la venta sin abrirla.
class _CheckoutMenuOption extends StatelessWidget {
  const _CheckoutMenuOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.severity,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Color semántico de la acción: verde cobrar, ámbar apartar, azul pedido.
  final EzySeverity severity;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = StatusPalette.text(context, severity);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: StatusPalette.soft(severity),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: StatusPalette.border(severity)),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      fontWeight: FontWeight.w700,
                      color: surfaces.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: EzyTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: surfaces.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, size: 18, color: surfaces.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Filo entre dos opciones del menú: separa sin cortar la card.
class _MenuSeparator extends StatelessWidget {
  const _MenuSeparator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(height: 1, color: context.surfaces.border),
    );
  }
}
