import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../printing/data/models/print_document.dart';
import '../../../printing/presentation/widgets/print_actions_panel.dart';
import '../../data/models/checkout_result.dart';

/// Resultado del cobro: folio real, totales, saldo pendiente y cambio.
///
/// Se muestra dentro del carrito (los pagos y el apartado también terminan
/// aquí) y ofrece imprimir el ticket o enviarlo por WhatsApp.
///
/// **Contrato que este rediseño no toca:**
/// * El botón «Nueva venta» sigue llamando a `consumeResult()` y cerrando la
///   hoja: la vista no toca el carrito ni el flujo de cobro.
/// * Los montos, el folio y el cambio vienen del servidor (`CheckoutResult`).
/// * La impresión y el WhatsApp siguen viviendo en [PrintActionsPanel]: esta
///   vista solo los viste.
class SaleResultView extends StatelessWidget {
  const SaleResultView({super.key, required this.result, required this.onDone});

  final CheckoutResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: <Widget>[
              _ResultCard(result: result),
              const SizedBox(height: 12),
              _TicketActionsCard(result: result),
            ],
          ),
        ),
        // El pie queda fijo en la base de la hoja: el CTA no depende de haber
        // bajado hasta el final del ticket.
        DecoratedBox(
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
            backgroundColor: surfaces.panel,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                EzyPrimary3dButton(
                  label: 'Nueva venta',
                  icon: Icons.add_shopping_cart_outlined,
                  height: 56,
                  widthFactor: 0.92,
                  maxWidth: 340,
                  onPressed: onDone,
                ),
                const SizedBox(height: 8),
                Text(
                  'El catálogo y el turno ya se actualizaron con el stock y los '
                  'cobros de esta venta.',
                  textAlign: TextAlign.center,
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    color: surfaces.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Card 1: resultado financiero y folio real de la venta confirmada.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final CheckoutResult result;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final transaction = result.transaction;
    final success = StatusPalette.text(context, EzySeverity.success);
    final warn = StatusPalette.text(context, EzySeverity.warn);
    final isFullyPaid = transaction.isFullyPaid;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border, width: 1.5),
        boxShadow: EzyColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            isFullyPaid ? 'Venta cobrada' : 'Venta registrada',
                            style: EzyTextStyles.bodyStrong.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: surfaces.textPrimary,
                            ),
                          ),
                        ),
                        if (isFullyPaid) ...<Widget>[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle,
                            size: 18,
                            color: EzyColors.success,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Transacción registrada y confirmada',
                      style: EzyTextStyles.caption.copyWith(
                        fontSize: 11.5,
                        color: surfaces.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(status: transaction.status),
            ],
          ),
          const SizedBox(height: 12),
          _FolioBlock(
            folio: transaction.folio,
            createdAt: transaction.createdAt,
          ),
          const SizedBox(height: 12),
          _BreakdownRow(
            icon: Icons.person_outline,
            label: 'Cliente',
            value: transaction.customerName ?? 'Público general',
            valueBold: true,
          ),
          if (transaction.totalDiscount > 0)
            _BreakdownRow(
              icon: Icons.local_offer_outlined,
              iconColor: success,
              label: 'Descuento aplicado',
              value: '-${Money.format(transaction.totalDiscount)}',
              valueColor: success,
            ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 10),
            color: surfaces.borderStrong,
          ),
          _TotalRow(total: transaction.total),
          const SizedBox(height: 10),
          _BreakdownRow(
            label: 'Monto pagado / capturado',
            value: Money.format(transaction.totalPaid),
            valueBold: true,
          ),
          if (transaction.remainingDue > 0.01)
            _BreakdownRow(
              icon: Icons.warning_amber_rounded,
              iconColor: warn,
              label: 'Saldo pendiente',
              value: Money.format(transaction.remainingDue),
              valueColor: warn,
              valueBold: true,
            ),
          if (result.hasChange) ...<Widget>[
            const SizedBox(height: 12),
            _ChangeBlock(change: result.change),
          ],
        ],
      ),
    );
  }
}

/// Bloque hero del folio real y su marca temporal.
class _FolioBlock extends StatelessWidget {
  const _FolioBlock({required this.folio, required this.createdAt});

  final String folio;
  final DateTime? createdAt;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaces.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'FOLIO DE VENTA',
                  style: EzyTextStyles.microLabel.copyWith(
                    color: surfaces.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  folio,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: surfaces.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'FECHA Y HORA',
                style: EzyTextStyles.microLabel.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                createdAt == null ? '—' : AppFormatters.dateTime(createdAt!),
                style: EzyTextStyles.secondary.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: surfaces.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fila etiqueta-valor del desglose financiero.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.valueColor,
    this.valueBold = false,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final Color? valueColor;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final rowIcon = icon;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (rowIcon != null) ...<Widget>[
            Icon(rowIcon, size: 15, color: iconColor ?? surfaces.textMuted),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              label,
              style: EzyTextStyles.caption.copyWith(
                fontSize: 12.5,
                color: surfaces.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: EzyTextStyles.moneyList.copyWith(
                fontSize: 13.5,
                fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? surfaces.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila hero del total de la venta, en el naranja de marca.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Text(
            'TOTAL DE LA VENTA',
            style: EzyTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: surfaces.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              Money.format(total),
              style: EzyTextStyles.moneyMedium.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: EzyColors.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bloque de «Cambio a entregar» (solo si el comprador recibe cambio).
class _ChangeBlock extends StatelessWidget {
  const _ChangeBlock({required this.change});

  final double change;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final success = StatusPalette.text(context, EzySeverity.success);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.success),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: StatusPalette.border(EzySeverity.success)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: EzyColors.success.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: EzyColors.success.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 18,
              color: EzyColors.success,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'CAMBIO A ENTREGAR',
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    color: success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Calculado y validado',
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 10.5,
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
                Money.format(change),
                style: EzyTextStyles.moneyLarge.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: success,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card 2: acciones de ticket (impresión y WhatsApp).
class _TicketActionsCard extends StatelessWidget {
  const _TicketActionsCard({required this.result});

  final CheckoutResult result;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final transaction = result.transaction;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border, width: 1.5),
        boxShadow: EzyColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'ACCIONES DE TICKET',
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: surfaces.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Documento generado',
                style: EzyTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  color: surfaces.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrintActionsPanel(
            document: PrintDocument.posCheckout(
              transactionId: result.printHint.dataSourceId > 0
                  ? result.printHint.dataSourceId
                  : transaction.id,
              templateIds: result.printHint.templateIds,
              subtitle: transaction.folio,
            ),
            // El ticket se imprime solo con la impresora lista: sin conexión el
            // botón se apaga visualmente.
            requirePrinterConnection: true,
          ),
        ],
      ),
    );
  }
}

/// Badge de estatus con punto pulsante: fondo al 12 %, borde al 30 % y color
/// pleno del estatus.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  /// Estatus del servidor (`completado`, `apartado`, `por_entregar`, ...).
  final String status;

  /// Etiqueta y severidad del estatus de la venta (§7 del design system).
  static (String, EzySeverity) _resolve(String status) => switch (status) {
    'completado' => ('Completado', EzySeverity.success),
    'pendiente' || 'apartado' => ('Apartado', EzySeverity.warn),
    'por_entregar' => ('Por entregar', EzySeverity.info),
    'cancelado' => ('Cancelado', EzySeverity.danger),
    _ => (status.isEmpty ? 'Registrado' : status, EzySeverity.neutral),
  };

  @override
  Widget build(BuildContext context) {
    final (label, severity) = _resolve(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: StatusPalette.soft(severity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(severity)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PulseDot(color: StatusPalette.base(severity)),
          const SizedBox(width: 6),
          Text(
            label,
            style: EzyTextStyles.badge.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: StatusPalette.text(context, severity),
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto de estatus de 7 px: opacidad 1.0 → 0.35 en 1.5 s, en bucle.
class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(_controller),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
