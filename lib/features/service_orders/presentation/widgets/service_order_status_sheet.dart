import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../data/models/service_order_detail.dart';
import '../../data/models/service_order_status.dart';
import '../../application/service_orders_controller.dart';
import 'service_order_labels.dart';
import 'service_order_status_stepper.dart';

/// Cambio de estatus de la orden (`PATCH /service-orders/{id}/status`).
///
/// Devuelve `true` cuando la orden quedó en `entregado` con saldo pendiente:
/// el llamador abre entonces el cobro (§8.2 del documento maestro). Los `422`
/// (estatus repetido o inválido) se muestran con el texto de `errors.status[0]`.
Future<bool> showServiceOrderStatusSheet(
  BuildContext context, {
  required ServiceOrderDetail detail,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ServiceOrderStatusSheet(detail: detail),
  );

  return result ?? false;
}

class _ServiceOrderStatusSheet extends ConsumerStatefulWidget {
  const _ServiceOrderStatusSheet({required this.detail});

  final ServiceOrderDetail detail;

  @override
  ConsumerState<_ServiceOrderStatusSheet> createState() =>
      _ServiceOrderStatusSheetState();
}

class _ServiceOrderStatusSheetState
    extends ConsumerState<_ServiceOrderStatusSheet> {
  String get _status => widget.detail.status;

  @override
  void initState() {
    super.initState();

    // Un aviso de una operación anterior no debe confundirse con esta.
    Future<void>.microtask(
      () => ref
          .read(serviceOrderDetailControllerProvider.notifier)
          .consumeStatusMessage(),
    );
  }

  ServiceOrderStatus? get _current => ServiceOrderStatus.fromValue(_status);

  /// Avanzar un paso pide permiso al servidor; regresar exige confirmación
  /// explícita (§8.2).
  Future<void> _select(ServiceOrderStatus next) async {
    final current = _current;

    if (current == null || next.flowIndex < current.flowIndex) {
      final confirmed = await _confirmRevert(next);

      if (confirmed != true || !mounted) {
        return;
      }
    }

    await _apply(next);
  }

  Future<bool?> _confirmRevert(ServiceOrderStatus next) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Regresar estatus'),
        content: Text(
          '${ServiceOrderLabels.revertWarning}\n\n'
          'Nuevo estatus: ${ServiceOrderLabels.status(next.value)}.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Regresar estatus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceOrderDetailControllerProvider);
    final current = _current;
    final stepsAhead = current?.stepsAhead ?? const <ServiceOrderStatus>[];
    final stepsBehind = current?.stepsBehind ?? const <ServiceOrderStatus>[];
    final controller = ref.read(serviceOrderDetailControllerProvider.notifier);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          EzySheetHeader(
            title: 'Estatus de la orden',
            subtitle: 'Folio ${widget.detail.folio}',
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          if (state.statusMessage != null) ...<Widget>[
            NoticeBanner(
              message: state.statusMessage!,
              tone: EzySeverity.warn,
              actionLabel: 'Ocultar',
              onAction: controller.consumeStatusMessage,
            ),
            const SizedBox(height: 12),
          ],
          if (state.errorMessage != null) ...<Widget>[
            NoticeBanner(
              message: state.errorMessage!,
              actionLabel: 'Ocultar',
              onAction: controller.consumeError,
            ),
            const SizedBox(height: 12),
          ],
          ServiceOrderStatusStepper(status: _status),
          const SizedBox(height: 16),
          _StepsSection(
            current: current,
            stepsAhead: stepsAhead,
            stepsBehind: stepsBehind,
            isSubmitting: state.isSubmitting,
            onSelect: _select,
            onCancel: _confirmCancel,
          ),
        ],
      ),
    );
  }

  /// Aplica el nuevo estatus y, si el servidor lo confirma, cierra la hoja.
  Future<void> _apply(ServiceOrderStatus next) async {
    final applied = await ref
        .read(serviceOrderDetailControllerProvider.notifier)
        .changeStatus(next.value);

    if (!mounted || !applied) {
      return;
    }

    final detail = ref.read(serviceOrderDetailControllerProvider).detail;
    final shouldCollect =
        next == ServiceOrderStatus.delivered &&
        (detail?.pendingAmount ?? 0) > 0.01;

    Navigator.of(context).pop(shouldCollect);
  }

  /// Cancelar libera stock y ajusta la venta vinculada: se confirma antes.
  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar orden'),
        content: const Text(
          '¿Seguro que quieres cancelar esta orden? El inventario de las '
          'refacciones se devolverá al stock y la venta vinculada se ajustará.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Regresar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Cancelar orden',
              style: EzyTextStyles.button.copyWith(color: EzyColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _apply(ServiceOrderStatus.cancelled);
  }
}

/// Pasos disponibles: avanzar (permiso `change_status`) y regresar (permiso
/// `edit` + confirmación), más la cancelación.
class _StepsSection extends StatelessWidget {
  const _StepsSection({
    required this.current,
    required this.stepsAhead,
    required this.stepsBehind,
    required this.isSubmitting,
    required this.onSelect,
    required this.onCancel,
  });

  final ServiceOrderStatus? current;
  final List<ServiceOrderStatus> stepsAhead;
  final List<ServiceOrderStatus> stepsBehind;
  final bool isSubmitting;
  final ValueChanged<ServiceOrderStatus> onSelect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    if (current?.isCancelled ?? true) {
      return const NoticeBanner(
        message: 'La orden está cancelada: su estatus ya no se puede cambiar.',
        tone: EzySeverity.danger,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: 'Avanzar',
          child: stepsAhead.isEmpty
              ? Text(
                  'La orden ya está entregada.',
                  style: EzyTextStyles.body.copyWith(color: surfaces.textMuted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final step in stepsAhead) ...<Widget>[
                      EzyButton(
                        label: ServiceOrderLabels.status(step.value),
                        variant: EzyButtonVariant.outline,
                        isLoading: isSubmitting,
                        onPressed: () => onSelect(step),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
        if (stepsBehind.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Regresar',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Regresar el estatus requiere confirmación.',
                  style: EzyTextStyles.caption.copyWith(
                    color: surfaces.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                for (final step in stepsBehind)
                  EzyButton(
                    label: ServiceOrderLabels.status(step.value),
                    variant: EzyButtonVariant.text,
                    isLoading: isSubmitting,
                    onPressed: () => onSelect(step),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        EzyButton(
          label: 'Cancelar orden',
          icon: Icons.cancel_outlined,
          variant: EzyButtonVariant.danger,
          isLoading: isSubmitting,
          onPressed: onCancel,
        ),
      ],
    );
  }
}
