import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../data/models/checkout_result.dart';

/// Resultado del cobro: folio real, totales, saldo pendiente y cambio.
///
/// Se muestra dentro del carrito (los pagos y el apartado también terminan
/// aquí) y su única acción es preparar la siguiente venta.
class SaleResultView extends StatelessWidget {
  const SaleResultView({super.key, required this.result, required this.onDone});

  final CheckoutResult result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final transaction = result.transaction;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: transaction.isFullyPaid ? 'Venta cobrada' : 'Venta registrada',
          trailing: StatusBadge.transaction(transaction.status, showDot: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                transaction.folio,
                style: EzyTextStyles.moneyLarge.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppFormatters.dateTime(transaction.createdAt),
                style: EzyTextStyles.secondary.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SectionRow(
                label: 'Cliente',
                value: transaction.customerName ?? 'Público general',
              ),
              if (transaction.totalDiscount != 0)
                SectionRow(
                  label: 'Descuento',
                  value: '-${Money.format(transaction.totalDiscount)}',
                ),
              SectionRow(
                label: 'Total',
                value: Money.format(transaction.total),
                emphasized: true,
              ),
              SectionRow(
                label: 'Pagado',
                value: Money.format(transaction.totalPaid),
              ),
              if (transaction.remainingDue > 0.01)
                SectionRow(
                  label: 'Saldo pendiente',
                  value: Money.format(transaction.remainingDue),
                  valueStyle: EzyTextStyles.moneyList.copyWith(
                    color: StatusPalette.text(context, EzySeverity.warn),
                  ),
                ),
              if (result.hasChange) ...<Widget>[
                const Divider(height: 24),
                SectionRow(
                  label: 'Cambio a entregar',
                  value: Money.format(result.change),
                  emphasized: true,
                  valueStyle: EzyTextStyles.moneyMedium.copyWith(
                    color: StatusPalette.text(context, EzySeverity.success),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const NoticeBanner(
          message:
              'La impresión del ticket y el envío por WhatsApp se habilitan en '
              'la siguiente entrega de la app.',
          tone: EzySeverity.info,
        ),
        const SizedBox(height: 16),
        EzyButton(
          label: 'Nueva venta',
          icon: Icons.add_shopping_cart_outlined,
          onPressed: onDone,
        ),
        const SizedBox(height: 8),
        Text(
          'El catálogo y el turno ya se actualizaron con el stock y los cobros '
          'de esta venta.',
          textAlign: TextAlign.center,
          style: EzyTextStyles.caption.copyWith(color: EzyColors.gray66),
        ),
      ],
    );
  }
}
