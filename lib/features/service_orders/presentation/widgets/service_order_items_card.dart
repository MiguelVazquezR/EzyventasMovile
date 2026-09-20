import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/section_card.dart';
import '../../data/models/service_order_detail.dart';
import 'service_order_labels.dart';

/// Conceptos de la orden: mano de obra y refacciones (§8.1).
class ServiceOrderItemsCard extends StatelessWidget {
  const ServiceOrderItemsCard({super.key, required this.items});

  final List<ServiceOrderItem> items;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: ServiceOrderLabels.items(items.length),
      child: items.isEmpty
          ? Text(
              'La orden no tiene conceptos capturados.',
              style: EzyTextStyles.body.copyWith(color: surfaces.textMuted),
            )
          : Column(
              children: <Widget>[
                for (var index = 0; index < items.length; index++) ...<Widget>[
                  if (index > 0) const Divider(height: 24),
                  _ItemRow(item: items[index]),
                ],
              ],
            ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final ServiceOrderItem item;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final tone = item.isPart ? EzySeverity.info : EzySeverity.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                item.description,
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ),
            Text(
              Money.format(item.lineTotal),
              style: EzyTextStyles.moneyList.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            _TypeTag(
              label: ServiceOrderLabels.itemType(item.itemableType),
              tone: tone,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${Money.formatQuantity(item.quantity)} × '
                '${Money.format(item.unitPrice)}',
                overflow: TextOverflow.ellipsis,
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeTag extends StatelessWidget {
  const _TypeTag({required this.label, required this.tone});

  final String label;
  final EzySeverity tone;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: StatusPalette.soft(tone),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(tone)),
      ),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.badge.copyWith(color: color, letterSpacing: 0.6),
      ),
    );
  }
}
