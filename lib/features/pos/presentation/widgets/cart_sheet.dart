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
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_dialog.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_list_tile.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/application/auth_controller.dart';
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
        EzySheetHeader(
          title: 'Carrito',
          subtitle: cartSummaryLabel(cart),
          trailing: EzyIconButton(
            icon: Icons.close,
            tooltip: 'Cerrar',
            onTap: () => Navigator.of(context).pop(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
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
              _TotalsCard(cart: cart),
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

/// Encabezado de la lista de líneas, con «Vaciar» a la derecha (§1 y §2).
///
/// El vaciado vive pegado a lo que vacía y no al final del scroll: es una acción
/// destructiva y tiene que verse **antes** de las líneas, no después. Va en el
/// tono de peligro del sistema, sin relleno, y confirma antes de limpiar (§2):
/// el carrito no se pierde por un toque de más.
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
            style: EzyTextStyles.cardTitle.copyWith(
              color: context.surfaces.textMuted,
            ),
          ),
        ),
        EzyButton(
          label: 'Vaciar',
          variant: EzyButtonVariant.text,
          icon: Icons.delete_outline,
          textColor: StatusPalette.text(context, EzySeverity.danger),
          expand: false,
          onPressed: cart.isEmpty
              ? null
              : () => _confirmClearCart(context, onClear),
        ),
      ],
    );
  }
}

/// Cliente de la venta (o público general con nombre opcional).
///
/// Es una **fila** del design system (`EzyListTile`) y no una card con título y
/// botón «Cambiar»: la fila entera abre el selector, que es una hoja inferior
/// que se arrastra hacia abajo para cerrarla —el gesto de las secciones de
/// Mercado Pago—, así que el chevron ya dice que se abre (§10).
class _CustomerRow extends ConsumerWidget {
  const _CustomerRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final customer = cart.customer;
    final guestName = cart.guestName.trim();

    final subtitle = customer != null
        ? <String>[
            'Saldo ${Money.format(customer.balance)}',
            if (customer.hasCredit)
              'Crédito ${Money.format(customer.availableCredit)}',
          ].join(' · ')
        : (guestName.isEmpty
              ? 'Toca para elegir un cliente.'
              : 'Público general · Toca para cambiar.');

    return DecoratedBox(
      // §1 del rediseño: la sección del cliente es una tarjeta blanca más —como
      // las de producto—, con la sombra de las tarjetas que flotan sobre el
      // lienzo. La fila sigue siendo la del design system.
      decoration: BoxDecoration(
        color: context.surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.surfaces.border),
        boxShadow: EzyColors.cardShadow,
      ),
      child: EzyListTile(
        icon: Icons.person_outline,
        title: 'Cliente: ${_customerLabel(customer?.displayName, guestName)}',
        subtitle: subtitle,
        showDivider: false,
        onTap: () => showCustomerPickerSheet(context),
      ),
    );
  }

  /// Nombre con el que se registra la venta, ya resuelto para la fila (§1).
  ///
  /// El prefijo «Cliente:» va en la fila —y no en el nombre— para que la venta
  /// sin cliente registrado se lea de un golpe: `Cliente: Público general`.
  static String _customerLabel(String? displayName, String guestName) {
    if (displayName != null) {
      return displayName;
    }

    return guestName.isEmpty ? 'Público general' : guestName;
  }
}

/// Resumen de venta del carrito (§4): subtotal, descuentos y total a pagar.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Resumen de venta',
      // §4: el resumen flota sobre el lienzo igual que las tarjetas de producto.
      boxShadow: EzyColors.cardShadow,
      child: Column(
        children: <Widget>[
          SectionRow(label: 'Subtotal', value: Money.format(cart.subtotal)),
          if (cart.totalDiscount != 0)
            SectionRow(
              label: 'Descuentos',
              value: '-${Money.format(cart.totalDiscount)}',
              valueStyle: EzyTextStyles.moneyList.copyWith(
                color: StatusPalette.text(context, EzySeverity.success),
              ),
            ),
          const Divider(height: 24),
          SectionRow(
            label: 'Total a pagar',
            value: Money.format(cart.total),
            emphasized: true,
          ),
        ],
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
        // El menú sale en el `Overlay` y no como otra hoja inferior: las opciones
        // tienen que quedar pegadas al botón que las abre.
        OverlayPortal(
          controller: _menu,
          overlayChildBuilder: _buildMenu,
          child: _CheckoutButton(
            anchorKey: _anchorKey,
            enabled: enabled,
            isLoading: cart.isSubmitting,
            onPressed: _toggleMenu,
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

          final double width = anchor != null
              ? anchor.width.clamp(0, size.width - 24)
              : size.width - 48;
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

/// Botón que cierra la venta: **Finalizar compra**, a 2/3 del ancho y centrado
/// (§5).
///
/// El ancho es una fracción de la barra y no un valor fijo: en un teléfono el
/// dedo llega sin estirar y en una tablet no se convierte en una franja enorme.
class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({
    required this.anchorKey,
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });

  final GlobalKey anchorKey;
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        key: anchorKey,
        widthFactor: 2 / 3,
        child: EzyButton(
          label: 'Finalizar compra',
          isLoading: isLoading,
          onPressed: enabled ? onPressed : null,
        ),
      ),
    );
  }
}

/// Menú del cierre de venta: las tres formas de cerrar la venta, apiladas (§5).
///
/// No son botones: son **opciones de lista** en el color de marca, apretadas en
/// el eje vertical, para que el menú se lea como un menú y no como tres botones
/// metidos en una caja. Es una card flotante, así que lleva la sombra suave que
/// el resto del design system no necesita: tiene que despegarse de lo que tapa.
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
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: surfaces.borderStrong),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: EzyColors.black2.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CheckoutMenuOption(
            icon: Icons.payments_outlined,
            label: 'Pago al contado',
            onTap: onCheckout,
          ),
          _CheckoutMenuOption(
            icon: Icons.bookmark_outline,
            label: 'Apartar',
            onTap: onLayaway,
          ),
          _CheckoutMenuOption(
            icon: Icons.receipt_long_outlined,
            label: 'Pedido',
            onTap: onStoreOrder,
          ),
        ],
      ),
    );
  }
}

/// Opción del menú de cierre de venta (§5).
///
/// Icono + texto en el naranja de marca, sin relleno ni contorno: el mismo
/// lenguaje de las filas del design system, con menos aire arriba y abajo.
class _CheckoutMenuOption extends StatelessWidget {
  const _CheckoutMenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: EzyColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: EzyColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
