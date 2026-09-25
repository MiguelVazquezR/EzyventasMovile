import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Estado de un paso dentro del recorrido.
enum EzyStepState { done, current, pending }

/// Stepper vertical del design system (§15).
///
/// Recibe etiquetas ya traducidas y la posición actual, así el componente no
/// conoce ningún estatus del contrato: quien lo usa pasa el flujo y el índice
/// reales del servidor. Con [cancelled] se antepone la fila roja del corte.
class EzyStepper extends StatelessWidget {
  const EzyStepper({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.cancelled = false,
    this.cancelledLabel = 'Cancelada',
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  /// Etiquetas del recorrido, en orden.
  final List<String> steps;

  /// Posición actual (`-1` si ningún paso está alcanzado).
  final int currentIndex;

  /// El recorrido se cortó: se pinta la fila roja en primer lugar.
  final bool cancelled;
  final String cancelledLabel;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final rows = <Widget>[];

    if (cancelled) {
      rows.add(
        _StepRow(
          label: cancelledLabel,
          state: EzyStepState.current,
          color: EzyColors.danger,
          showConnector: steps.isNotEmpty,
          surfaces: surfaces,
        ),
      );
    }

    for (int i = 0; i < steps.length; i++) {
      final state = cancelled || currentIndex < 0
          ? EzyStepState.pending
          : i < currentIndex
          ? EzyStepState.done
          : i == currentIndex
          ? EzyStepState.current
          : EzyStepState.pending;

      rows.add(
        _StepRow(
          label: steps[i],
          state: state,
          color: switch (state) {
            EzyStepState.done => EzyColors.success,
            EzyStepState.current => EzyColors.primary,
            EzyStepState.pending => surfaces.textMuted,
          },
          showConnector: i < steps.length - 1,
          surfaces: surfaces,
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.label,
    required this.state,
    required this.color,
    required this.showConnector,
    required this.surfaces,
  });

  final String label;
  final EzyStepState state;
  final Color color;
  final bool showConnector;
  final EzySurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    final isPending = state == EzyStepState.pending;
    final isDone = state == EzyStepState.done;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isPending ? Colors.transparent : color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isPending ? surfaces.borderStrong : color,
                ),
              ),
              child: isDone
                  ? Icon(Icons.check, size: 12, color: surfaces.onPrimary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  label,
                  style:
                      (state == EzyStepState.current
                              ? EzyTextStyles.bodyStrong
                              : EzyTextStyles.body)
                          .copyWith(
                            color: switch (state) {
                              EzyStepState.current => surfaces.textPrimary,
                              EzyStepState.done => surfaces.textSecondary,
                              EzyStepState.pending => surfaces.textMuted,
                            },
                          ),
                ),
              ),
            ),
          ],
        ),
        if (showConnector)
          Padding(
            padding: const EdgeInsets.only(left: 9.5, top: 4, bottom: 4),
            child: Container(width: 1, height: 18, color: surfaces.border),
          ),
      ],
    );
  }
}
