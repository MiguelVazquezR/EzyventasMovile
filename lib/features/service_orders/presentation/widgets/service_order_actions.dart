import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permissions_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_dialog.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/service_orders_controller.dart';
import '../../data/models/service_order_detail.dart';
import '../../data/models/service_order_status.dart';
import 'service_order_labels.dart';
import 'service_order_payment_sheet.dart';

/// Dock de acciones del detalle de la orden: el bloque héroe de la hoja.
///
/// Va **pegado al borde inferior**, fuera del `ListView`, así el contenido se
/// desplaza por encima de él y las acciones nunca quedan a un scroll de
/// distancia. Reacciona al dinero y al estatus:
///
/// * **Cabecera de saldo**: lo que falta cobrar (`SALDO POR COBRAR`) o
///   `Liquidada` cuando ya no queda nada pendiente.
/// * **CTA principal**: `Cobrar ahora` mientras quede saldo y haya turno de
///   caja abierto; `Entregar orden` cuando la orden ya está pagada y sigue
///   abierta en el taller.
/// * **Píldoras de acción rápida**: cancelación y borrado, según permisos. El
///   cambio de estatus vive en el stepper de la hoja, no aquí.
///
/// La app oculta lo que el usuario no puede hacer; el servidor siempre
/// revalida (`403`).
class ServiceOrderHeroDock extends ConsumerWidget {
  const ServiceOrderHeroDock({super.key, required this.detail});

  final ServiceOrderDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);
    final isSubmitting = ref.watch(
      serviceOrderDetailControllerProvider.select(
        (state) => state.isSubmitting,
      ),
    );

    final canPay = permissions.can('transactions.add_payment');
    final canChangeStatus = permissions.can('services.orders.change_status');
    final canDelete = permissions.can('services.orders.delete');
    final showMoney =
        canPay || permissions.can('services.orders.see_financial_info');

    // El cobro manda: mientras quede saldo, es la acción principal. Cuando la
    // orden ya está pagada y sigue en el taller, el héroe es entregarla.
    final showPayment = canPay && detail.canReceivePayment;
    final showDeliver =
        !showPayment &&
        canChangeStatus &&
        !detail.isCancelled &&
        detail.status != ServiceOrderStatus.delivered.value;

    final pills = <Widget>[
      if (canChangeStatus && !detail.isCancelled)
        _DockPill(
          icon: Icons.close,
          label: 'Cancelar orden',
          tone: EzySeverity.danger,
          onTap: isSubmitting ? null : () => _confirmCancel(context, ref),
        ),
      if (canDelete)
        _DockPill(
          icon: Icons.delete_outline,
          label: 'Eliminar orden',
          tone: EzySeverity.danger,
          onTap: isSubmitting ? null : () => _confirmDelete(context, ref),
        ),
    ];

    // Sin nada que ofrecer (una orden cancelada vista por un usuario de solo
    // lectura) el dock desaparece y la hoja vuelve a ser un documento.
    if (!showPayment && !showDeliver && pills.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: surfaces.panel,
        border: Border(top: BorderSide(color: surfaces.border)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: EzyColors.black1.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      // Dock compacto: la sección fija no debe comerse el documento (§12).
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showMoney) ...<Widget>[
            _BalanceHeadline(amount: detail.pendingAmount),
            const SizedBox(height: 10),
          ],
          if (showPayment) ...<Widget>[
            // Una orden antigua todavía no tiene venta: el cobro la crea
            // (`ensure-transaction`) antes de registrar el anticipo.
            if (!detail.hasTransaction) ...<Widget>[
              const NoticeBanner(
                message:
                    'Esta orden no tiene venta vinculada: al cobrar se creará '
                    'automáticamente.',
                tone: EzySeverity.info,
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 12),
            ],
            // El cobro es la acción principal del detalle: va con el CTA 3D del
            // design system (el mismo relieve que «Finalizar venta» del POS).
            EzyPrimary3dButton(
              label: 'Cobrar ahora',
              icon: Icons.payments_outlined,
              // 48 px y ancho completo: el dock es una barra, no un formulario.
              height: 48,
              maxWidth: double.infinity,
              onPressed: session == null
                  ? null
                  : () => confirmServiceOrderPayment(
                      context,
                      ref,
                      detail: detail,
                    ),
              isLoading: isSubmitting,
            ),
            if (session == null) ...<Widget>[
              const SizedBox(height: 8),
              NoticeBanner(
                message:
                    'Necesitas una sesión de caja abierta para registrar '
                    'anticipos o liquidaciones.',
                tone: EzySeverity.warn,
                actionLabel: 'Ir a caja',
                onAction: () => _goToCashRegister(context),
              ),
            ],
            if (detail.status ==
                ServiceOrderStatus.delivered.value) ...<Widget>[
              const SizedBox(height: 8),
              const NoticeBanner(
                message:
                    'La orden se entregó con saldo pendiente: registra el '
                    'cobro.',
                tone: EzySeverity.warn,
              ),
            ],
          ] else if (showDeliver) ...<Widget>[
            EzyPrimary3dButton(
              label: 'Entregar orden',
              icon: Icons.check_circle_outline,
              height: 48,
              maxWidth: double.infinity,
              isLoading: isSubmitting,
              onPressed: () => ServiceOrderStatusFlow.apply(
                context,
                ref,
                detail: detail,
                next: ServiceOrderStatus.delivered,
              ),
            ),
          ],
          if (pills.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            // `Wrap` y no una tira con scroll: las dos píldoras se ven
            // completas lado a lado (una barra horizontal escondería
            // «Eliminar orden»).
            Wrap(spacing: 8, runSpacing: 8, children: pills),
          ],
        ],
      ),
    );
  }

  /// Cancela la orden con confirmación explícita: el servidor devuelve el stock
  /// de las refacciones y ajusta la venta vinculada, así que no puede ser un
  /// toque silencioso (mismo aviso que la hoja de estatus).
  static Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showEzyConfirmDialog(
      context,
      title: 'Cancelar orden',
      message:
          '¿Seguro que quieres cancelar esta orden? El inventario de las '
          'refacciones se devolverá al stock y la venta vinculada se ajustará.',
      confirmLabel: 'Cancelar orden',
      cancelLabel: 'Regresar',
      isDestructive: true,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    await ref
        .read(serviceOrderDetailControllerProvider.notifier)
        .changeStatus(ServiceOrderStatus.cancelled.value);
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

/// Reglas del cambio de estatus desde el detalle (§8.2).
///
/// Vive aparte del dock porque lo comparten sus dos caminos: el stepper (tocar
/// un paso) y el CTA `Entregar orden`. Regresar de etapa pide confirmación
/// explícita y, cuando la orden pasa a `entregado` con saldo pendiente, el
/// cobro se encadena sin salir de la hoja.
///
/// No comprueba permisos: el stepper solo es táctil con
/// `services.orders.change_status` y el CTA solo se pinta con ese permiso.
class ServiceOrderStatusFlow {
  const ServiceOrderStatusFlow._();

  static Future<void> apply(
    BuildContext context,
    WidgetRef ref, {
    required ServiceOrderDetail detail,
    required ServiceOrderStatus next,
  }) async {
    final current = ServiceOrderStatus.fromValue(detail.status);
    // Regresar de etapa devuelve la orden al taller: no es un retroceso
    // silencioso, se confirma (mismo texto que la hoja de estatus).
    final isBackwards = current != null && next.flowIndex < current.flowIndex;

    if (isBackwards) {
      final confirmed = await showEzyConfirmDialog(
        context,
        title: 'Regresar estatus',
        message:
            '${ServiceOrderLabels.revertWarning}\n\n'
            'Nuevo estatus: ${ServiceOrderLabels.status(next.value)}.',
        confirmLabel: 'Regresar estatus',
        isDestructive: true,
      );

      if (!confirmed || !context.mounted) {
        return;
      }
    }

    final applied = await ref
        .read(serviceOrderDetailControllerProvider.notifier)
        .changeStatus(next.value);

    // El `422` del servidor se queda en la hoja: el controlador publica el
    // mensaje y el detalle lo pinta en su aviso.
    if (!applied || !context.mounted) {
      return;
    }

    final updated = ref.read(serviceOrderDetailControllerProvider).detail;

    if (next != ServiceOrderStatus.delivered ||
        updated == null ||
        updated.pendingAmount <= 0.01) {
      return;
    }

    await confirmServiceOrderPayment(context, ref, detail: updated);
  }
}

/// Cabecera del dock: el monto que falta cobrar o el visto bueno de que la
/// orden ya está liquidada. Sin saldo el bloque no grita, baja a verde.
class _BalanceHeadline extends StatelessWidget {
  const _BalanceHeadline({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isPending = amount > 0.01;
    final severity = isPending ? EzySeverity.warn : EzySeverity.success;
    final color = StatusPalette.text(context, severity);

    return Row(
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: StatusPalette.base(severity).withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPending
                ? Icons.account_balance_wallet_outlined
                : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            isPending ? 'SALDO POR COBRAR' : 'SALDO DE LA ORDEN',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.microLabel.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          isPending ? Money.format(amount) : 'Liquidada',
          style: isPending
              ? EzyTextStyles.moneyMedium.copyWith(color: color)
              : EzyTextStyles.bodyStrong.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Píldora de acción rápida del dock (34 px, radio 999).
///
/// Hermana de `EzyChip`, pero con un tono propio para la acción destructiva:
/// el `tone` de `EzyChip` describe el estatus de un **dato**, no una acción
/// elegible.
class _DockPill extends StatelessWidget {
  const _DockPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.tone,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final EzySeverity? tone;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final severity = tone;
    final isEnabled = onTap != null;
    final foreground = !isEnabled
        ? surfaces.textMuted
        : severity == null
        ? surfaces.textSecondary
        : StatusPalette.text(context, severity);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: severity == null
              ? surfaces.panelInner
              : StatusPalette.soft(severity),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: severity == null
                ? surfaces.border
                : StatusPalette.border(severity),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: EzyTextStyles.caption.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
