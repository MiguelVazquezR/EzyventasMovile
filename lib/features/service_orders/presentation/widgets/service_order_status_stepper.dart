import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../data/models/service_order_status.dart';
import 'service_order_labels.dart';

/// Stepper de estatus de la orden (§8.2 y §7 del design system).
///
/// Cinco pasos con círculos de 48 px; el paso actual va lleno con halo y los
/// cumplidos llevan check. Una orden cancelada se pinta como banda roja.
class ServiceOrderStatusStepper extends StatelessWidget {
  const ServiceOrderStatusStepper({super.key, required this.status});

  /// Valor del servidor (`pendiente`, `en_progreso`, ...).
  final String status;

  @override
  Widget build(BuildContext context) {
    final current = ServiceOrderStatus.fromValue(status);

    if (current == null || current.isCancelled) {
      return _CancelledBand(
        label: current == null
            ? status
            : ServiceOrderLabels.status(current.value),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < ServiceOrderStatus.flow.length; index++)
          Expanded(
            child: _Step(
              status: ServiceOrderStatus.flow[index],
              isCurrent: ServiceOrderStatus.flow[index] == current,
              isDone: index < current.flowIndex,
              isLast: index == ServiceOrderStatus.flow.length - 1,
            ),
          ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.status,
    required this.isCurrent,
    required this.isDone,
    required this.isLast,
  });

  final ServiceOrderStatus status;
  final bool isCurrent;
  final bool isDone;
  final bool isLast;

  /// Icono del paso (§7 del design system).
  static IconData _iconFor(ServiceOrderStatus status) => switch (status) {
    ServiceOrderStatus.pending => Icons.inbox_outlined,
    ServiceOrderStatus.inProgress => Icons.build_outlined,
    ServiceOrderStatus.waitingParts => Icons.hourglass_empty,
    ServiceOrderStatus.finished => Icons.handyman_outlined,
    ServiceOrderStatus.delivered => Icons.check_circle_outline,
    ServiceOrderStatus.cancelled => Icons.cancel_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = isCurrent || isDone
        ? StatusPalette.base(status.severity)
        : surfaces.textMuted;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Container(
                height: 2,
                color: isDone || isCurrent
                    ? StatusPalette.base(status.severity).withValues(alpha: 0.5)
                    : surfaces.border,
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isCurrent
                    ? color.withValues(alpha: 0.16)
                    : surfaces.panelInner,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent
                      ? color
                      : (isDone ? color.withValues(alpha: 0.5) : surfaces.border),
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Icon(
                isDone ? Icons.check : _iconFor(status),
                size: 20,
                color: color,
              ),
            ),
            Expanded(
              child: Container(
                height: 2,
                color: isLast
                    ? Colors.transparent
                    : (isDone
                          ? color.withValues(alpha: 0.5)
                          : surfaces.border),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          ServiceOrderLabels.status(status.value).toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: EzyTextStyles.badge.copyWith(
            color: isCurrent || isDone ? color : surfaces.textMuted,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

/// Banda roja de una orden cancelada (bloquea los cambios de estatus).
class _CancelledBand extends StatelessWidget {
  const _CancelledBand({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, EzySeverity.danger);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.danger),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StatusPalette.border(EzySeverity.danger)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.cancel_outlined, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: EzyTextStyles.badge.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
