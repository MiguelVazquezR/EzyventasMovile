import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../data/models/service_order_status.dart';
import 'service_order_labels.dart';

/// Stepper de estatus de la orden (§8.2 y §7 del design system).
///
/// Cinco pasos con círculos de 46 px: los cumplidos llevan el check en verde, el
/// actual es una esfera de marca con halo, y los que faltan se quedan en el tono
/// apagado de la superficie. El conector se pinta del color del paso alcanzado,
/// así el avance se lee de un vistazo. Una orden cancelada se pinta como banda
/// roja (bloquea los cambios de estatus).
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
              isFirst: index == 0,
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
    required this.isFirst,
    required this.isLast,
  });

  final ServiceOrderStatus status;
  final bool isCurrent;
  final bool isDone;
  final bool isFirst;
  final bool isLast;

  /// Lado del círculo del paso (§7).
  static const double _size = 46;

  /// Lado del halo del paso actual: 16 px más que el círculo.
  static const double _halo = _size + 16;

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
    // Cumplido = verde del sistema; actual = naranja de marca; pendiente = tono
    // apagado, para que el ojo caiga primero en el paso en curso.
    final color = isDone
        ? EzyColors.success
        : (isCurrent ? EzyColors.primary : surfaces.textMuted);
    final label = ServiceOrderLabels.status(status.value).toUpperCase();

    return Column(
      children: <Widget>[
        SizedBox(
          height: _halo,
          child: Row(
            children: <Widget>[
              // El primer paso no tiene conector a la izquierda y el último no lo
              // tiene a la derecha: la línea no puede salirse del riel.
              Expanded(
                child: _Connector(
                  color: isFirst
                      ? Colors.transparent
                      : (isDone || isCurrent
                            ? color.withValues(alpha: 0.45)
                            : surfaces.border),
                ),
              ),
              _Circle(
                size: _size,
                halo: _halo,
                isCurrent: isCurrent,
                isDone: isDone,
                color: color,
                icon: isDone ? Icons.check : _iconFor(status),
                surfaces: surfaces,
              ),
              Expanded(
                child: _Connector(
                  color: isLast
                      ? Colors.transparent
                      : (isDone
                            ? color.withValues(alpha: 0.45)
                            : surfaces.border),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: EzyTextStyles.badge.copyWith(
            color: isDone || isCurrent ? color : surfaces.textMuted,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

/// Riel entre dos pasos: 2 px del color del tramo recorrido.
class _Connector extends StatelessWidget {
  const _Connector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(height: 2, color: color);
  }
}

/// Círculo del paso: esfera de marca con halo si es el actual, relleno verde con
/// el check si está cumplido y aro del sistema si todavía no llega.
class _Circle extends StatelessWidget {
  const _Circle({
    required this.size,
    required this.halo,
    required this.isCurrent,
    required this.isDone,
    required this.color,
    required this.icon,
    required this.surfaces,
  });

  final double size;
  final double halo;
  final bool isCurrent;
  final bool isDone;
  final Color color;
  final IconData icon;
  final EzySurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isCurrent || isDone ? null : surfaces.panelInner,
        gradient: isCurrent
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFFFB9E2E),
                  EzyColors.primary,
                  Color(0xFFE07804),
                ],
              )
            : (isDone
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0xFF34D07F),
                        EzyColors.success,
                        Color(0xFF16A34A),
                      ],
                    )
                  : null),
        shape: BoxShape.circle,
        border: isCurrent || isDone ? null : Border.all(color: surfaces.border),
      ),
      child: Icon(
        icon,
        size: 20,
        color: isCurrent || isDone ? EzyColors.white : surfaces.textMuted,
      ),
    );

    if (!isCurrent) {
      return Center(child: circle);
    }

    // Halo del paso actual: un aro translúcido de marca 16 px mayor que el
    // círculo. Sin sombra: el relieve lo sigue dando el botón 3D.
    return Center(
      child: Container(
        width: halo,
        height: halo,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Center(child: circle),
      ),
    );
  }
}

/// Banda roja de una orden cancelada (bloquea los cambios de estatus).
class _CancelledBand extends StatelessWidget {
  const _CancelledBand({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = StatusPalette.text(context, EzySeverity.danger);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.danger),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StatusPalette.border(EzySeverity.danger)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: StatusPalette.base(
                EzySeverity.danger,
              ).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cancel_outlined, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label.toUpperCase(),
                  style: EzyTextStyles.badge.copyWith(
                    color: color,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'El estatus de una orden cancelada no se puede cambiar.',
                  style: EzyTextStyles.caption.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

