import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../data/models/service_order_status.dart';
import 'service_order_labels.dart';

/// Stepper de estatus de la orden (§8.2 y §7 del design system).
///
/// Cinco pasos con círculos de 46 px sobre un riel: los cumplidos llevan el
/// check en verde, el actual es una esfera de marca con halo y los que faltan se
/// quedan en el tono apagado de la superficie. Bajo el riel corre una barra de
/// progreso naranja que anima su ancho de forma proporcional al paso alcanzado,
/// así el avance se lee de un vistazo.
///
/// Con [onStatusSelected] el stepper es **interactivo**: cada paso se vuelve
/// táctil y aparece la cabecera con los botones «Atrás»/«Avanzar», de modo que el
/// detalle cambia el estatus sin abrir una segunda hoja. Sin el callback (la hoja
/// de estatus) queda de solo lectura, como hasta ahora. Una orden cancelada se
/// pinta como banda roja (bloquea los cambios).
class ServiceOrderStatusStepper extends StatelessWidget {
  const ServiceOrderStatusStepper({
    super.key,
    required this.status,
    this.onStatusSelected,
    this.isSubmitting = false,
  });

  /// Valor del servidor (`pendiente`, `en_progreso`, ...).
  final String status;

  /// Se dispara al tocar un paso o los botones de la cabecera.
  ///
  /// `null` = stepper de solo lectura (sin toques ni cabecera de controles).
  final ValueChanged<ServiceOrderStatus>? onStatusSelected;

  /// Mientras el `PATCH` está en vuelo el stepper no acepta toques.
  final bool isSubmitting;

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

    final flow = ServiceOrderStatus.flow;
    final index = current.flowIndex;
    final isInteractive = onStatusSelected != null;
    final canTap = isInteractive && !isSubmitting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (isInteractive) ...<Widget>[
          _StepperHeader(
            canGoBack: canTap && index > 0,
            canGoForward: canTap && index < flow.length - 1,
            isLoading: isSubmitting,
            onBack: () => onStatusSelected!(flow[index - 1]),
            onForward: () => onStatusSelected!(flow[index + 1]),
          ),
          const SizedBox(height: 14),
        ],
        // El riel y la barra se miden con el ancho real de la caja: la barra
        // cubre exactamente la distancia entre el centro del primer paso y el
        // del último, multiplicada por el avance.
        LayoutBuilder(
          builder: (context, constraints) {
            final count = flow.length;
            final cell = constraints.maxWidth / count;
            final railTop = _Step.halo / 2 - 1;
            final progress = count <= 1 ? 0.0 : index / (count - 1);

            return Stack(
              children: <Widget>[
                Positioned(
                  left: cell / 2,
                  right: cell / 2,
                  top: railTop,
                  child: Container(height: 2, color: context.surfaces.border),
                ),
                Positioned(
                  left: cell / 2,
                  top: railTop,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    height: 2,
                    width: (constraints.maxWidth - cell) * progress,
                    color: EzyColors.primary,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: _Step(
                          status: flow[i],
                          isCurrent: flow[i] == current,
                          isDone: i < index,
                          onTap: canTap ? () => onStatusSelected!(flow[i]) : null,
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Un paso del flujo: círculo (con halo si es el actual) y etiqueta.
class _Step extends StatelessWidget {
  const _Step({
    required this.status,
    required this.isCurrent,
    required this.isDone,
    this.onTap,
  });

  final ServiceOrderStatus status;
  final bool isCurrent;
  final bool isDone;

  /// `null` = paso de solo lectura.
  final VoidCallback? onTap;

  /// Lado del círculo del paso (§7).
  static const double size = 46;

  /// Lado del halo del paso actual: 16 px más que el círculo.
  static const double halo = size + 16;

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

    final content = Column(
      children: <Widget>[
        SizedBox(
          height: halo,
          child: _Circle(
            size: size,
            halo: halo,
            isCurrent: isCurrent,
            isDone: isDone,
            color: color,
            icon: isDone ? Icons.check : _iconFor(status),
            surfaces: surfaces,
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

    if (onTap == null) {
      return content;
    }

    // Área táctil = la celda completa del paso (círculo + etiqueta).
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: content,
    );
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
    // círculo. Sin sombra: el relieve lo sigue dando el gradiente.
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

/// Cabecera del stepper interactivo: micro-etiqueta y salto de un paso.
class _StepperHeader extends StatelessWidget {
  const _StepperHeader({
    required this.canGoBack,
    required this.canGoForward,
    required this.isLoading,
    required this.onBack,
    required this.onForward,
  });

  final bool canGoBack;
  final bool canGoForward;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Row(
      children: <Widget>[
        Icon(Icons.commit, size: 16, color: surfaces.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'LÍNEA DE ESTATUS · TOCA UN PASO PARA CAMBIAR',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.microLabel.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (isLoading)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...<Widget>[
          _StepControl(
            icon: Icons.chevron_left,
            tooltip: 'Atrás',
            onTap: canGoBack ? onBack : null,
          ),
          const SizedBox(width: 8),
          _StepControl(
            icon: Icons.chevron_right,
            tooltip: 'Avanzar',
            onTap: canGoForward ? onForward : null,
          ),
        ],
      ],
    );
  }
}

/// Botón redondo de 34 px para retroceder o avanzar un paso.
class _StepControl extends StatelessWidget {
  const _StepControl({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: surfaces.panelInner,
        shape: CircleBorder(side: BorderSide(color: surfaces.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 20,
              color: onTap == null
                  ? surfaces.textMuted.withValues(alpha: 0.5)
                  : surfaces.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

