import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/cart_controller.dart';
import '../../application/cart_state.dart';
import '../../data/models/store_order_draft.dart';

/// Datos del pedido o comanda (`POST /pos/store-order`).
///
/// Devuelve `true` cuando el pedido quedó registrado (el folio lo muestra la
/// hoja del carrito).
///
/// **Contrato que este rediseño no toca (§1):**
/// * El retorno sigue siendo `true` solo si el servidor aceptó la orden; la
///   cancelación y el cierre normal devuelven `false`.
/// * Los errores de campo se pintan en el borde/ayuda de su input con las claves
///   `contact_info.name`, `contact_info.phone`, `delivery_date` y
///   `shipping_address`; el global va al banner superior.
/// * Sin sesión de caja activa no se envía nada ([_canSubmit] exige datos y el
///   envío relee la sesión antes de llamar al controlador).
Future<bool> showStoreOrderSheet(BuildContext context) async {
  final result = await EzyBottomSheet.show<bool>(
    context,
    maxHeightFactor: 0.96,
    // Mismo lienzo gris del POS que el carrito, el cliente y el cobro. El asa de
    // arrastre la dibuja la propia hoja para poder pintar la cabecera fija justo
    // debajo, sin la banda del tema en medio.
    backgroundColor: context.surfaces.background,
    showDragHandle: false,
    builder: (sheetContext) => const _StoreOrderSheet(),
  );

  return result ?? false;
}

class _StoreOrderSheet extends ConsumerStatefulWidget {
  const _StoreOrderSheet();

  @override
  ConsumerState<_StoreOrderSheet> createState() => _StoreOrderSheetState();
}

class _StoreOrderSheetState extends ConsumerState<_StoreOrderSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _shippingController = TextEditingController(
    // El costo de envío se captura como decimal (`0.00`), no como entero.
    text: Money.formatPlain(0),
  );
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _deliveryController = TextEditingController();

  String _type = StoreOrderDraft.pedido;
  DateTime? _deliveryDate;
  double _shippingCost = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _shippingController.dispose();
    _notesController.dispose();
    _deliveryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final isComanda = _type == StoreOrderDraft.comanda;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _SheetDragHandle(),
        _OrderHeader(isComanda: isComanda),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: <Widget>[
              // §3: el error global del servidor vive arriba, pegado a la
              // cabecera, para que no dependa de haber bajado con el scroll.
              if (cart.errorMessage != null) ...<Widget>[
                _ServerErrorBanner(
                  message: cart.errorMessage!,
                  onDismiss: ref
                      .read(cartControllerProvider.notifier)
                      .consumeError,
                ),
                const SizedBox(height: 12),
              ],
              _ContactCard(
                type: _type,
                onTypeChanged: (value) => setState(() => _type = value),
                nameController: _nameController,
                phoneController: _phoneController,
                nameError: _nameError(cart),
                phoneError: cart.errorFor('contact_info.phone'),
                onNameChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _DeliveryCard(
                cart: cart,
                deliveryController: _deliveryController,
                addressController: _addressController,
                shippingController: _shippingController,
                notesController: _notesController,
                onPickDate: _pickDeliveryDate,
                onShippingChanged: (value) =>
                    setState(() => _shippingCost = value),
                onAddressChanged: () => setState(() {}),
                onNotesChanged: () => setState(() {}),
              ),
              const SizedBox(height: 12),
              _TotalsCard(cart: cart, shippingCost: _shippingCost),
            ],
          ),
        ),
        // §7: el CTA no viaja con el scroll — vive en el pie, siempre a la vista.
        _OrderFooter(
          isComanda: isComanda,
          isSubmitting: cart.isSubmitting,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
    );
  }

  /// El servidor exige el nombre (mín. 2 caracteres) y la fecha de entrega.
  String? _nameError(CartState cart) {
    final name = _nameController.text.trim();

    // El botón ya está deshabilitado sin nombre: solo se marca el error cuando
    // el usuario escribió algo inválido o el servidor lo rechazó.
    if (name.isNotEmpty && name.length < 2) {
      return 'El nombre debe tener al menos 2 caracteres.';
    }

    return cart.errorFor('contact_info.name');
  }

  bool get _canSubmit =>
      _nameController.text.trim().length >= 2 && _deliveryDate != null;

  Future<void> _submit() async {
    final sessionId = ref.read(activeCashSessionProvider)?.id;
    if (sessionId == null) {
      return;
    }

    final result = await ref
        .read(cartControllerProvider.notifier)
        .submitOrder(
          sessionId: sessionId,
          order: StoreOrderDraft(
            contactName: _nameController.text,
            contactPhone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text,
            type: _type,
            deliveryDate: _deliveryDate!,
            shippingAddress: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text,
            shippingCost: _shippingCost,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
        );

    if (result != null && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Fecha y hora de entrega (obligatoria para el servidor).
  ///
  /// Secuencial a propósito (§5): primero la fecha y después la hora, para que
  /// el cajero confirme la jornada antes de afinar la hora. Los dos diálogos
  /// heredan el tema de la app (`colorScheme.primary` = naranja de marca,
  /// superficies del panel); el rango es de hoy a un año.
  Future<void> _pickDeliveryDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Fecha de entrega',
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_deliveryDate ?? now),
      helpText: 'Hora de entrega',
    );

    if (time == null) {
      return;
    }

    final delivery = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      _deliveryDate = delivery;
      _deliveryController.text = AppFormatters.dateTime(delivery);
    });
  }
}

/// Asa de arrastre de la hoja (§1): 40 × 5 px en el lienzo, no dentro de la
/// cabecera, para que la banda blanca empiece a ras de ella.
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 12),
      decoration: BoxDecoration(
        color: context.surfaces.borderStrong,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Cabecera fija de la hoja (§2): título, badge de estatus, subtítulo y cierre.
///
/// Vive **fuera** del scroll: el tipo de orden y el estatus siguen a la vista
/// aunque el formulario sea largo.
class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.isComanda});

  final bool isComanda;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: surfaces.panel,
        border: Border(bottom: BorderSide(color: surfaces.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  isComanda ? 'Comanda' : 'Pedido',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.screenTitle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: surfaces.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SheetChip(
                label: 'Por entregar',
                fontSize: 11,
                letterSpacing: 0.2,
                color: StatusPalette.text(context, EzySeverity.info),
                background: StatusPalette.soft(EzySeverity.info),
                borderColor: StatusPalette.border(EzySeverity.info),
              ),
              const Spacer(),
              const SizedBox(width: 8),
              EzyIconButton(
                icon: Icons.close,
                tooltip: 'Cerrar',
                size: 32,
                iconSize: 16,
                color: surfaces.textSecondary,
                background: surfaces.panelInner,
                borderColor: surfaces.border,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'El stock queda reservado; se cobra al entregar.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.secondary.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: surfaces.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta flotante de la hoja (§1): panel, radio 16, borde y sombra de card.
///
/// Sustituye a `SectionCard` porque estas cards separan su encabezado interno
/// (micro-etiqueta + chip) del contenido, con el espaciado de 14 px del rediseño.
class _SheetCard extends StatelessWidget {
  const _SheetCard({required this.child, this.borderWidth = 1});

  final Widget child;

  /// Grosor del borde; la card de contacto lo sube a 1.5 px (§4).
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border, width: borderWidth),
        boxShadow: EzyColors.cardShadow,
      ),
      child: child,
    );
  }
}

/// Encabezado interno de una card: micro-etiqueta a la izquierda y a la derecha
/// el chip de estado o una nota corta (§1).
class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.trailing});

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.microLabel.copyWith(
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
              color: context.surfaces.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

/// Píldora de estatus de la hoja (§2 y §4): fondo translúcido, borde de la misma
/// severidad y micro-texto en MAYÚSCULAS.
class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.color,
    required this.background,
    this.borderColor = Colors.transparent,
    this.fontSize = 10,
    this.letterSpacing = 0.4,
  });

  final String label;
  final Color color;
  final Color background;
  final Color borderColor;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.badge.copyWith(
          fontSize: fontSize,
          letterSpacing: letterSpacing,
          color: color,
        ),
      ),
    );
  }
}

/// Nota de la fila de la micro-etiqueta: el contador `0/255` o el tope de
/// captura (`MÁX. 20`), en el tono apagado de la etiqueta (§4).
class _LabelNote extends StatelessWidget {
  const _LabelNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: EzyTextStyles.microLabel.copyWith(
        letterSpacing: 0.4,
        fontWeight: FontWeight.w600,
        color: context.surfaces.textMuted,
      ),
    );
  }
}

/// Banner del error global de la petición (§3): peligro al 12 % de fondo, borde
/// al 30 %, icono, título, mensaje del servidor y cierre propio.
class _ServerErrorBanner extends StatelessWidget {
  const _ServerErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, EzySeverity.danger);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.danger),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StatusPalette.border(EzySeverity.danger)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Error al registrar',
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: EzyTextStyles.secondary.copyWith(
                    fontSize: 11.5,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 16, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón grande del selector de tipo (§4): relleno de marca cuando está activo,
/// contorno naranja cuando no; ambos repartidos 1:1 en la fila.
class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? EzyColors.white : EzyColors.primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? EzyColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: EzyColors.primary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Text(
              label,
              style: EzyTextStyles.bodyStrong.copyWith(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tipo de orden: retail/entrega (`pedido`) o cocina/mesa (`comanda`).
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.type, required this.onChanged});

  final String type;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _TypeOption(
            icon: Icons.inventory_2_outlined,
            label: 'Pedido',
            selected: type == StoreOrderDraft.pedido,
            onTap: () => onChanged(StoreOrderDraft.pedido),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TypeOption(
            icon: Icons.restaurant_outlined,
            label: 'Comanda',
            selected: type == StoreOrderDraft.comanda,
            onTap: () => onChanged(StoreOrderDraft.comanda),
          ),
        ),
      ],
    );
  }
}

/// Card 1 — contacto y tipo de orden (§4): selector 1:1, leyenda, nombre y
/// teléfono, cada uno con el error de su campo (`contact_info.*`) en el input.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.type,
    required this.onTypeChanged,
    required this.nameController,
    required this.phoneController,
    required this.nameError,
    required this.phoneError,
    required this.onNameChanged,
  });

  final String type;
  final ValueChanged<String> onTypeChanged;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final String? nameError;
  final String? phoneError;
  final VoidCallback onNameChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isComanda = type == StoreOrderDraft.comanda;

    return _SheetCard(
      borderWidth: 1.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(
            title: 'Datos de contacto',
            trailing: _SheetChip(
              label: 'Reserva de stock',
              color: EzyColors.primary,
              background: EzyColors.primary.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 14),
          _TypeSelector(type: type, onChanged: onTypeChanged),
          const SizedBox(height: 10),
          Text(
            isComanda
                ? 'Uso para cocina, restaurante y consumo en mesa.'
                : 'Uso para retail y entregas programadas a domicilio.',
            style: EzyTextStyles.caption.copyWith(
              fontSize: 11,
              color: surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          EzyTextField(
            label: 'Nombre de quien recibe',
            isRequired: true,
            requiredMarkColor: EzyColors.danger,
            labelTrailing: _LabelNote('${nameController.text.length}/255'),
            controller: nameController,
            fillColor: surfaces.panelInner,
            fieldHeight: 46,
            borderRadius: 12,
            borderColor: surfaces.borderStrong,
            errorText: nameError,
            maxLength: 255,
            onChanged: (_) => onNameChanged(),
          ),
          const SizedBox(height: 14),
          EzyTextField(
            label: 'Teléfono (opcional)',
            labelTrailing: const _LabelNote('Máx. 20'),
            keyboardType: TextInputType.phone,
            prefixIcon: Icons.phone_outlined,
            prefixIconSize: 16,
            controller: phoneController,
            fillColor: surfaces.panelInner,
            fieldHeight: 46,
            borderRadius: 12,
            borderColor: surfaces.borderStrong,
            errorText: phoneError,
            maxLength: 20,
          ),
        ],
      ),
    );
  }
}

/// Card 2 — entrega y logística (§5): fecha/hora secuencial, dirección, costo de
/// envío en `$ / MXN` y notas.
class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.cart,
    required this.deliveryController,
    required this.addressController,
    required this.shippingController,
    required this.notesController,
    required this.onPickDate,
    required this.onShippingChanged,
    required this.onAddressChanged,
    required this.onNotesChanged,
  });

  final CartState cart;
  final TextEditingController deliveryController;
  final TextEditingController addressController;
  final TextEditingController shippingController;
  final TextEditingController notesController;
  final VoidCallback onPickDate;
  final ValueChanged<double> onShippingChanged;
  final VoidCallback onAddressChanged;
  final VoidCallback onNotesChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return _SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(
            title: 'Entrega y logística',
            trailing: _SheetChip(
              label: 'Programada',
              color: StatusPalette.text(context, EzySeverity.warn),
              background: StatusPalette.soft(EzySeverity.warn),
              borderColor: StatusPalette.border(EzySeverity.warn),
            ),
          ),
          const SizedBox(height: 14),
          EzyTextField(
            label: 'Fecha y hora de entrega',
            isRequired: true,
            requiredMarkColor: EzyColors.danger,
            readOnly: true,
            controller: deliveryController,
            fillColor: surfaces.panelInner,
            fieldHeight: 46,
            borderRadius: 12,
            borderColor: surfaces.borderStrong,
            hint: 'Seleccionar fecha…',
            errorText: cart.errorFor('delivery_date'),
            prefixIcon: Icons.event_outlined,
            prefixIconSize: 18,
            prefixIconColor: EzyColors.primary,
            textStyle: EzyTextStyles.bodyStrong.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: surfaces.textPrimary,
            ),
            suffix: GestureDetector(
              onTap: onPickDate,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  'Cambiar',
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: EzyColors.primary,
                  ),
                ),
              ),
            ),
            onTap: onPickDate,
          ),
          const SizedBox(height: 14),
          EzyTextField(
            label: 'Dirección de entrega (opcional)',
            labelTrailing: _LabelNote('${addressController.text.length}/255'),
            hint: 'Calle, número exterior/interior, colonia y referencias…',
            controller: addressController,
            fillColor: surfaces.panelInner,
            borderRadius: 12,
            borderColor: surfaces.borderStrong,
            errorText: cart.errorFor('shipping_address'),
            maxLines: 2,
            maxLength: 255,
            onChanged: (_) => onAddressChanged(),
          ),
          const SizedBox(height: 14),
          MoneyField(
            label: 'Costo de envío',
            controller: shippingController,
            fillColor: surfaces.panelInner,
            fieldHeight: 46,
            borderRadius: 12,
            borderColor: surfaces.borderStrong,
            prefixColor: EzyColors.primary,
            prefixIconSize: 14,
            suffixText: 'MXN',
            onChanged: onShippingChanged,
          ),
          const SizedBox(height: 14),
          EzyTextField(
            label: 'Notas especiales (opcional)',
            labelTrailing: _LabelNote('${notesController.text.length}/1000'),
            hint: 'Instrucciones para cocina, entrega o empaque…',
            controller: notesController,
            fillColor: surfaces.panelInner,
            borderRadius: 12,
            borderColor: surfaces.borderStrong,
            maxLines: 3,
            maxLength: 1000,
            onChanged: (_) => onNotesChanged(),
          ),
        ],
      ),
    );
  }
}

/// Card 3 — totales (§6): productos, envío, separador y el total protagonista.
class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.cart, required this.shippingCost});

  final CartState cart;
  final double shippingCost;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final total = cart.total + shippingCost;

    return _SheetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _CardHeader(
            title: 'Resumen de la orden',
            trailing: Text(
              'Cobro contra entrega',
              style: EzyTextStyles.caption.copyWith(
                fontSize: 10,
                color: surfaces.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _TotalRow(
            label: 'Productos (Carrito)',
            value: Money.format(cart.total),
          ),
          const SizedBox(height: 10),
          _TotalRow(label: 'Costo de envío', value: Money.format(shippingCost)),
          const SizedBox(height: 12),
          Container(height: 1, color: surfaces.borderStrong),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'TOTAL DEL PEDIDO',
                      style: EzyTextStyles.microLabel.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w900,
                        color: surfaces.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '(Productos + Envío)',
                      style: EzyTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: surfaces.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                // Un total largo se encoge en vez de partir el renglón.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    Money.format(total),
                    style: EzyTextStyles.moneyLarge.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: EzyColors.primary,
                    ),
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

/// Fila de concepto del resumen: etiqueta a la izquierda y monto en cifras
/// tabulares a la derecha (§6).
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});

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
            style: EzyTextStyles.caption.copyWith(
              fontSize: 12.5,
              color: surfaces.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: EzyTextStyles.moneyList.copyWith(
            fontSize: 12.5,
            color: surfaces.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Pie fijo de la hoja (§7): CTA 3D de 56 px y la leyenda del requisito de caja.
class _OrderFooter extends StatelessWidget {
  const _OrderFooter({
    required this.isComanda,
    required this.isSubmitting,
    required this.onPressed,
  });

  final bool isComanda;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // Sombra hacia arriba: el pie flota sobre el formulario que hace scroll.
      decoration: const BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, -6),
            blurRadius: 20,
          ),
        ],
      ),
      child: EzyActionBar(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            EzyPrimary3dButton(
              label: isComanda ? 'Registrar comanda' : 'Registrar pedido',
              icon: Icons.check_outlined,
              height: 56,
              widthFactor: 0.92,
              maxWidth: 340,
              isLoading: isSubmitting,
              onPressed: onPressed,
            ),
            const SizedBox(height: 8),
            Text(
              'Se requiere una sesión de caja activa',
              textAlign: TextAlign.center,
              style: EzyTextStyles.caption.copyWith(
                fontSize: 10.5,
                color: context.surfaces.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}







