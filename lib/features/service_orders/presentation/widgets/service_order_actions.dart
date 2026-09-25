import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permissions_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_dialog.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/service_orders_controller.dart';
import '../../data/models/service_order_detail.dart';
import 'service_order_diagnosis_sheet.dart';
import 'service_order_labels.dart';
import 'service_order_payment_sheet.dart';
import 'service_order_status_sheet.dart';

/// Acciones del detalle de la orden según permisos y estatus.
///
/// La app oculta lo que el usuario no puede hacer; el servidor siempre
/// revalida (`403`).
class ServiceOrderActionBar extends ConsumerWidget {
  const ServiceOrderActionBar({super.key, required this.detail});

  final ServiceOrderDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);
    final isSubmitting = ref.watch(
      serviceOrderDetailControllerProvider.select(
        (state) => state.isSubmitting,
      ),
    );

    final showPayment =
        permissions.can('transactions.add_payment') && detail.canReceivePayment;
    final showStatus =
        permissions.can('services.orders.change_status') && !detail.isCancelled;
    final showEdit =
        permissions.can('services.orders.edit') && detail.isEditable;
    final showDelete = permissions.can('services.orders.delete');

    if (!showPayment && !showStatus && !showEdit && !showDelete) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showPayment) ...<Widget>[
          EzyButton(
            label: 'Cobrar ahora',
            icon: Icons.payments_outlined,
            isLoading: isSubmitting,
            onPressed: session == null
                ? null
                : () =>
                      confirmServiceOrderPayment(context, ref, detail: detail),
          ),
          if (session == null) ...<Widget>[
            const SizedBox(height: 8),
            NoticeBanner(
              message:
                  'Necesitas una sesión de caja abierta para registrar '
                  'anticipos.',
              tone: EzySeverity.warn,
              actionLabel: 'Ir a caja',
              onAction: () => _goToCashRegister(context),
            ),
          ],
          if (detail.status == 'entregado') ...<Widget>[
            const SizedBox(height: 8),
            const NoticeBanner(
              message:
                  'La orden se entregó con saldo pendiente: registra el cobro.',
              tone: EzySeverity.warn,
            ),
          ],
        ],
        if (showStatus) ...<Widget>[
          if (showPayment) const SizedBox(height: 8),
          EzyButton(
            label: 'Cambiar estatus',
            icon: Icons.sync_alt_outlined,
            variant: EzyButtonVariant.outline,
            isLoading: isSubmitting,
            onPressed: () => _changeStatus(context, ref, detail: detail),
          ),
        ],
        if (showEdit) ...<Widget>[
          const SizedBox(height: 8),
          EzyButton(
            label: 'Guardar diagnóstico',
            icon: Icons.edit_note_outlined,
            variant: EzyButtonVariant.outline,
            isLoading: isSubmitting,
            onPressed: () =>
                showServiceOrderDiagnosisSheet(context, detail: detail),
          ),
          const SizedBox(height: 8),
          EzyButton(
            label: 'Editar orden',
            icon: Icons.edit_outlined,
            variant: EzyButtonVariant.outline,
            isLoading: isSubmitting,
            onPressed: () => context.push(serviceOrderEditPath(detail.id)),
          ),
        ],
        if (showDelete) ...<Widget>[
          const SizedBox(height: 8),
          EzyButton(
            label: 'Eliminar orden',
            icon: Icons.delete_outline,
            variant: EzyButtonVariant.danger,
            isLoading: isSubmitting,
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ],
    );
  }

  /// Cambia el estatus y, si el nuevo estatus es `entregado` con saldo
  /// pendiente, abre el cobro (§8.2).
  static Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref, {
    required ServiceOrderDetail detail,
  }) async {
    final shouldCollect = await showServiceOrderStatusSheet(
      context,
      detail: detail,
    );

    if (!shouldCollect || !context.mounted) {
      return;
    }

    final updated =
        ref.read(serviceOrderDetailControllerProvider).detail ?? detail;

    await confirmServiceOrderPayment(context, ref, detail: updated);
  }

  /// Cierra la hoja y lleva al turno de caja para abrirlo.
  static void _goToCashRegister(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();

    router.go(AppTab.cashRegister.path);
  }

  /// El servidor elimina también la venta vinculada: se pide confirmación
  /// explícita ("Esta acción no se puede deshacer.").
  static Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showEzyConfirmDialog(
      context,
      title: 'Eliminar orden',
      message: 'Vas a eliminar la orden. ${ServiceOrderLabels.deleteWarning}',
      confirmLabel: 'Eliminar',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final deleted = await ref
        .read(serviceOrderDetailControllerProvider.notifier)
        .deleteOrder();

    if (!context.mounted) {
      return;
    }

    if (deleted) {
      ref.read(serviceOrderDetailControllerProvider.notifier).clear();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orden eliminada correctamente.')),
      );

      return;
    }

    final error = ref.read(serviceOrderDetailControllerProvider).errorMessage;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
    }
  }
}
