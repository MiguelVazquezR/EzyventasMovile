import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../application/sales_controller.dart';
import '../../data/models/transaction_detail.dart';
import 'sales_labels.dart';
import 'transaction_actions.dart';
import 'transaction_payments_card.dart';
import 'transaction_print_bar.dart';

/// Familia monoespaciada para folios, fechas, SKU y montos de detalle: los
/// dígitos caen en columna y la hoja se lee como un estado de cuenta.
///
/// Es la misma que usa el ticket de WhatsApp (`whatsapp_ticket_sheet.dart`).
const String _monoFamily = 'monospace';

/// Detalle completo de una venta: folio, estatus, artículos, pagos, totales y
/// acciones.
///
/// Hoja de alta densidad (estilo Mercado Pago / DiDi): el encabezado concentra
/// folio, estatus y acciones; el cuerpo va en cards de 24 px con sub-paneles de
/// 16 px, y las acciones viven arriba (CTA 3D + outline) para que no haya que
/// bajar hasta el final para abonar o cancelar.
Future<void> showTransactionDetailSheet(
  BuildContext context, {
  required int transactionId,
}) {
  final surfaces = context.surfaces;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    // La superficie la pinta la hoja (no el `Material` del modal) para poder
    // redondear solo las esquinas de arriba, a 24 px.
    backgroundColor: surfaces.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) =>
        _TransactionDetailSheet(transactionId: transactionId),
  );
}

class _TransactionDetailSheet extends ConsumerStatefulWidget {
  const _TransactionDetailSheet({required this.transactionId});

  final int transactionId;

  @override
  ConsumerState<_TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<_TransactionDetailSheet> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(transactionDetailControllerProvider.notifier)
          .load(widget.transactionId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionDetailControllerProvider);
    final controller = ref.read(transactionDetailControllerProvider.notifier);
    final detail = state.belongsTo(widget.transactionId) ? state.detail : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.50,
      maxChildSize: 0.96,
      snap: true,
      snapSizes: const <double>[0.50, 0.94, 0.96],
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const _DragHandle(),
          if (detail == null)
            ..._loadingChildren(state.errorMessage, controller)
          else ...<Widget>[
            _DetailHeader(
              detail: detail,
              onRefresh: controller.refresh,
              onClose: () => Navigator.of(context).pop(),
            ),
            if (state.notice != null) ...<Widget>[
              const SizedBox(height: 14),
              NoticeBanner(
                message: state.notice!,
                tone: EzySeverity.success,
                icon: Icons.check_circle_outline,
                actionLabel: 'Ocultar',
                onAction: controller.consumeNotice,
              ),
            ],
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 14),
              NoticeBanner(
                message: state.errorMessage!,
                actionLabel: 'Ocultar',
                onAction: controller.consumeError,
              ),
            ],
            const SizedBox(height: 14),
            TransactionActionBar(detail: detail),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Ticket',
              child: TransactionPrintBar(detail: detail),
            ),
            const SizedBox(height: 12),
            _ClientCard(detail: detail),
            const SizedBox(height: 12),
            TransactionItemsCard(items: detail.items),
            const SizedBox(height: 12),
            TransactionAmountsCard(detail: detail),
            const SizedBox(height: 12),
            TransactionPaymentsCard(detail: detail),
            if (detail.invoice != null) ...<Widget>[
              const SizedBox(height: 12),
              _InvoiceCard(invoice: detail.invoice!),
            ],
            const SizedBox(height: 12),
            _InfoCard(detail: detail),
          ],
          const SizedBox(height: 20),
          EzyPrimary3dButton(
            label: 'Cerrar detalle',
            icon: Icons.close_rounded,
            height: 48,
            maxWidth: 320,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// Estado de carga: spinner y, si falló, el `message` del servidor.
  List<Widget> _loadingChildren(
    String? errorMessage,
    TransactionDetailController controller,
  ) {
    return <Widget>[
      const SizedBox(height: 48),
      const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      if (errorMessage != null) ...<Widget>[
        const SizedBox(height: 20),
        ErrorNotice(message: errorMessage, onRetry: controller.refresh),
      ],
    ];
  }
}

/// Asa de arrastre de la hoja: pastilla de 40 × 4 sobre la superficie.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: EzyColors.gray4A,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

/// Chip de dato de la cabecera (`2 líneas`, `Pedido`, `Facturada`).
///
/// Mismo lenguaje que los badges de estatus —pastilla de 999 px, borde de 1 px,
/// micro-etiqueta— pero sin semántica de color: aquí el color solo agrupa. Lo
/// que es estado de verdad lo dice `StatusBadge`, que vive al lado.
class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = surfaces.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: surfaces.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: EzyTextStyles.badge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Cabecera del detalle: folio, estatus, fecha y canal.
///
/// El folio va como título de hoja (mismo `EzySheetHeader` que las demás), el
/// estatus debajo y las dos acciones (`Actualizar` y `Cerrar`) a la derecha.
///
/// Bajo el estatus va la tira de datos de un vistazo —líneas, pedido,
/// factura—: es el patrón de Mercado Pago / DiDi, donde lo que identifica al
/// documento se resuelve en la cabecera y no bajando al cuerpo.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.detail,
    required this.onRefresh,
    required this.onClose,
  });

  final TransactionDetail detail;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        EzySheetHeader(
          title: detail.folio,
          subtitle:
              '${AppFormatters.dateTime(detail.createdAt)} · '
              '${SalesLabels.channel(detail.channel)}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              EzyIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar',
                onTap: onRefresh,
              ),
              const SizedBox(width: 8),
              EzyIconButton(
                icon: Icons.close,
                tooltip: 'Cerrar',
                onTap: onClose,
              ),
            ],
          ),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            StatusBadge.transaction(
              detail.status,
              showDot: !detail.isCancelled,
            ),
            _MetaPill(
              icon: Icons.inventory_2_outlined,
              label: SalesLabels.lines(detail.itemsCount),
            ),
            if (detail.isOrder)
              const _MetaPill(
                icon: Icons.local_shipping_outlined,
                label: 'Pedido',
              ),
            if (detail.hasInvoice)
              const _MetaPill(
                icon: Icons.receipt_long_outlined,
                label: 'Facturada',
              ),
          ],
        ),
      ],
    );
  }
}

/// Valor monoespaciado con cifras tabulares (folios, fechas, montos, ids).
///
/// Es la mitad del carácter del detalle: los dígitos caen en columna y la hoja
/// se lee como un estado de cuenta, no como una lista de frases.
TextStyle _monoStyle(double size, FontWeight weight, Color color) => TextStyle(
  fontFamily: _monoFamily,
  fontSize: size,
  fontWeight: weight,
  height: 1.25,
  color: color,
  fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
);

/// Fila etiqueta-valor del detalle.
///
/// Envuelve `SectionRow` —el mismo de los resúmenes y cortes de caja— pero deja
/// el valor en monoespaciada cuando es un dato duro (fecha, folio, teléfono,
/// monto) y en el cuerpo normal cuando es un nombre o una nota.
class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.emphasized = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool mono;
  final bool emphasized;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = valueColor ?? surfaces.textPrimary;

    return SectionRow(
      label: label,
      value: value,
      emphasized: emphasized,
      valueStyle: mono
          ? _monoStyle(
              emphasized ? 15 : 13.5,
              emphasized ? FontWeight.w800 : FontWeight.w600,
              color,
            )
          : EzyTextStyles.body.copyWith(
              fontSize: 13.5,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
              color: color,
            ),
    );
  }
}

/// Cliente de la venta con su saldo y límite de crédito.
class _ClientCard extends StatelessWidget {
  const _ClientCard({required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context) {
    final customer = detail.customer;
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Cliente',
      inner: true,
      trailing: _MetaPill(
        icon: customer == null
            ? Icons.person_outline
            : Icons.verified_user_outlined,
        label: customer == null ? 'Público general' : 'Registrado',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            detail.customerLabel,
            style: EzyTextStyles.bodyStrong.copyWith(
              fontSize: 15,
              color: surfaces.textPrimary,
            ),
          ),
          if (customer == null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Venta de público general.',
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ] else ...<Widget>[
            const SizedBox(height: 4),
            // El saldo es el dato que decide si se puede volver a fiar: va en
            // monoespaciada y con el tono de alerta cuando es deuda.
            _DataRow(
              label: customer.hasBalanceInFavor
                  ? 'Saldo a favor'
                  : (customer.hasDebt ? 'Deuda' : 'Saldo'),
              value: Money.format(customer.balance.abs()),
              mono: true,
              valueColor: customer.hasDebt
                  ? StatusPalette.text(context, EzySeverity.warn)
                  : surfaces.textPrimary,
            ),
            _DataRow(
              label: 'Límite de crédito',
              value: Money.format(customer.creditLimit),
              mono: true,
              valueColor: surfaces.textSecondary,
            ),
          ],
        ],
      ),
    );
  }
}

/// Líneas de la venta con su precio, descuento e importe.
class TransactionItemsCard extends StatelessWidget {
  const TransactionItemsCard({super.key, required this.items});

  final List<TransactionItem> items;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Artículos',
      trailing: _MetaPill(
        icon: Icons.inventory_2_outlined,
        label: items.isEmpty ? 'Sin líneas' : SalesLabels.lines(items.length),
      ),
      child: items.isEmpty
          ? Text(
              'Esta venta no tiene artículos registrados.',
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            )
          : Column(
              children: <Widget>[
                // El separador va entre líneas, nunca antes de la primera ni
                // después de la última: la card ya tiene su propio borde.
                for (var index = 0; index < items.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: 22),
                  _ItemRow(position: index + 1, item: items[index]),
                ],
              ],
            ),
    );
  }
}

/// Línea de la venta: ordinal, descripción, cantidad × precio e importe.
///
/// El ordinal va en su recuadro a la izquierda y el importe en monoespaciada a
/// la derecha, para que todos los montos de la lista caigan en la misma
/// columna: es lo que hace legible una lista densa de líneas.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.position, required this.item});

  /// Número de la línea dentro de la venta (1…n).
  final int position;

  final TransactionItem item;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: surfaces.panelInner,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: surfaces.border),
          ),
          child: Text(
            '$position',
            style: _monoStyle(11.5, FontWeight.w700, surfaces.textMuted),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.description,
                style: EzyTextStyles.body.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: surfaces.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.itemableId == null ? '' : '#${item.itemableId} · '}'
                '${Money.formatQuantity(item.quantity)} × '
                '${Money.format(item.unitPrice)}',
                style: _monoStyle(
                  11.5,
                  FontWeight.w500,
                  surfaces.textSecondary,
                ),
              ),
              if (item.hasDiscount)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.isIncrease
                        ? 'Aumento ${Money.format(item.discountAmount)} · '
                              '${item.discountReason ?? ''}'
                        : 'Descuento ${Money.format(item.discountAmount)} · '
                              '${item.discountReason ?? ''}',
                    style: EzyTextStyles.caption.copyWith(
                      fontSize: 11.5,
                      color: item.isIncrease
                          ? surfaces.textSecondary
                          : StatusPalette.text(context, EzySeverity.warn),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          Money.format(item.lineTotal),
          style: _monoStyle(13.5, FontWeight.w800, surfaces.textPrimary),
        ),
      ],
    );
  }
}

/// Totales y saldo pendiente de la venta.
///
/// El total va como cifra grande de la casa (`moneyLarge`, `w300` tabular): es
/// **el** número que el usuario viene a leer. Debajo, la barra de cobro dice de
/// un vistazo cuánto del total ya entró, que es la pregunta que sigue.
class TransactionAmountsCard extends StatelessWidget {
  const TransactionAmountsCard({super.key, required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isPaid = detail.isPaid;
    final severity = isPaid ? EzySeverity.success : EzySeverity.warn;
    // Cuánto del total ya entró (0…1). Sin total no hay proporción que pintar.
    final collected = detail.total <= 0
        ? 1.0
        : (detail.paidAmount / detail.total).clamp(0.0, 1.0);

    return SectionCard(
      title: 'Totales',
      trailing: StatusBadge(
        label: isPaid ? 'Pagada' : 'Con saldo',
        severity: severity,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DataRow(
            label: 'Subtotal',
            value: Money.format(detail.subtotal),
            mono: true,
          ),
          if (detail.totalDiscount != 0)
            _DataRow(
              label: 'Descuento',
              value: '-${Money.format(detail.totalDiscount)}',
              mono: true,
              valueColor: StatusPalette.text(context, EzySeverity.warn),
            ),
          if (detail.shippingCost != 0)
            _DataRow(
              label: 'Envío',
              value: Money.format(detail.shippingCost),
              mono: true,
            ),
          if (detail.totalTax != 0)
            _DataRow(
              label: 'Impuesto',
              value: Money.format(detail.totalTax),
              mono: true,
            ),
          const Divider(height: 20),
          Text(
            'Total',
            style: EzyTextStyles.bodyStrong.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            Money.format(detail.total),
            style: EzyTextStyles.moneyLarge.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Text(
                'COBRADO',
                style: EzyTextStyles.microLabel.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
              const Spacer(),
              Text(
                '${(collected * 100).round()} %',
                style: _monoStyle(
                  11.5,
                  FontWeight.w700,
                  surfaces.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: collected,
              minHeight: 6,
              backgroundColor: surfaces.panelInner,
              valueColor: AlwaysStoppedAnimation<Color>(
                StatusPalette.text(context, severity),
              ),
            ),
          ),
          const Divider(height: 20),
          _DataRow(
            label: 'Pagado',
            value: Money.format(detail.paidAmount),
            mono: true,
            valueColor: StatusPalette.text(context, EzySeverity.success),
          ),
          if (!isPaid)
            _DataRow(
              label: 'Saldo pendiente',
              value: Money.format(detail.pendingBalance),
              mono: true,
              emphasized: true,
              valueColor: StatusPalette.text(context, EzySeverity.warn),
            ),
        ],
      ),
    );
  }
}

/// Factura de la venta: folio y estatus del comprobante fiscal.
class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});

  final TransactionInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Factura',
      child: Column(
        children: <Widget>[
          _DataRow(label: 'Folio', value: invoice.folio, mono: true),
          _DataRow(
            label: 'Estatus',
            value: invoice.status.isEmpty ? '—' : invoice.status,
          ),
        ],
      ),
    );
  }
}

/// Información operativa de la venta (sucursal, cajero, fechas, notas).
///
/// Los datos duros —sesión de caja, teléfono, fechas— van en monoespaciada; lo
/// que es texto humano (sucursal, cajero, dirección, notas) va en el cuerpo
/// normal: la vista se lee por columnas sin perder la jerarquía.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = detail.summary;

    return SectionCard(
      title: 'Información de la venta',
      child: Column(
        children: <Widget>[
          if (detail.branch != null)
            _DataRow(label: 'Sucursal', value: detail.branch!.name),
          if (summary.user != null)
            _DataRow(label: 'Registró', value: summary.user!.name),
          _DataRow(label: 'Canal', value: SalesLabels.channel(detail.channel)),
          if (detail.cashRegisterSessionId != null)
            _DataRow(
              label: 'Sesión de caja',
              value: '#${detail.cashRegisterSessionId}',
              mono: true,
            ),
          if (summary.contactName != null)
            _DataRow(label: 'Contacto', value: summary.contactName!),
          if (summary.contactPhone != null)
            _DataRow(
              label: 'Teléfono',
              value: summary.contactPhone!,
              mono: true,
            ),
          if (detail.deliveryDate != null)
            _DataRow(
              label: 'Fecha de entrega',
              value: AppFormatters.dateTime(detail.deliveryDate),
              mono: true,
            ),
          if (detail.layawayExpirationDate != null) ...<Widget>[
            _DataRow(
              label: 'Vence el apartado',
              value: AppFormatters.date(detail.layawayExpirationDate),
              mono: true,
            ),
            // Un apartado vencido se marca en el tono de alerta: es la única
            // fila de la tarjeta que pide una acción.
            if ((detail.layawayDaysLeft ?? 0) < 0)
              _DataRow(
                label: 'Días restantes',
                value: 'Vencido (${detail.layawayDaysLeft} días)',
                mono: true,
                valueColor: StatusPalette.text(context, EzySeverity.warn),
              )
            else
              _DataRow(
                label: 'Días restantes',
                value: '${detail.layawayDaysLeft ?? 0}',
                mono: true,
              ),
          ],
          if (detail.shippingAddress != null)
            _DataRow(
              label: 'Dirección de entrega',
              value: detail.shippingAddress!,
            ),
          if (detail.notes != null)
            _DataRow(label: 'Notas', value: detail.notes!),
          _DataRow(label: 'Facturada', value: summary.invoiced ? 'Sí' : 'No'),
        ],
      ),
    );
  }
}
