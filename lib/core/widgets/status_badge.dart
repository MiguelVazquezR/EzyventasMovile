import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../theme/status_palette.dart';
import '../utils/status_catalog.dart';

/// Badge de estatus: fondo del color al 12 %, texto del color pleno en
/// MAYÚSCULAS de 10 px y borde al 30 % (§7).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.severity,
    this.showDot = false,
  });

  /// Badge de una venta o pedido (`completado`, `apartado`, ...).
  factory StatusBadge.transaction(String status, {bool showDot = false}) =>
      StatusBadge(
        label: StatusCatalog.transactionLabel(status),
        severity: StatusCatalog.transactionSeverity(status),
        showDot: showDot,
      );

  /// Badge de una orden de servicio.
  factory StatusBadge.serviceOrder(String status, {bool showDot = false}) =>
      StatusBadge(
        label: StatusCatalog.serviceOrderLabel(status),
        severity: StatusCatalog.serviceOrderSeverity(status),
        showDot: showDot,
      );

  final String label;
  final EzySeverity severity;

  /// Punto pulsante para indicar "en curso" (§7).
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, severity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: StatusPalette.soft(severity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(severity)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (showDot) ...<Widget>[
            _PulsingDot(color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: EzyTextStyles.badge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Punto de actividad de 8 px con `animate-pulse` (opacidad 1 → 0.4 → 1).
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
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
      opacity: Tween<double>(begin: 1, end: 0.4).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}
