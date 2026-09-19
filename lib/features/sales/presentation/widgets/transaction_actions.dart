import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permissions_service.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/sales_controller.dart';
import '../../data/models/transaction_detail.dart';
import 'abono_sheet.dart';
import 'cancellation_sheet.dart';

/// Acciones disponibles en el detalle según permisos y estatus.
///
/// La app oculta lo que el usuario no puede hacer; el servidor siempre
/// revalida (`403`).
class TransactionActionBar extends ConsumerWidget {
  const TransactionActionBar({super.key, required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);
    final isSubmitting = ref.watch(
      transactionDetailControllerProvider.select(
        (state) => state.isSubmitting,
      ),
    );

    final showPayment =
        permissions.can('transactions.add_payment') && detail.canReceivePayment;
    final showCancellation =
        (permissions.can('transactions.cancel') ||
            permissions.can('transactions.refund')) &&
        detail.canBeCancelled;

    if (!showPayment && !showCancellation) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showPayment) ...<Widget>[
          EzyButton(
            label: 'Registrar abono',
            icon: Icons.payments_outlined,
            isLoading: isSubmitting,
            onPressed: session == null
                ? null
                : () => showAbonoSheet(context, detail: detail),
          ),
          if (session == null) ...<Widget>[
            const SizedBox(height: 8),
            NoticeBanner(
              message:
                  'Necesitas una sesión de caja abierta para registrar abonos.',
              tone: EzySeverity.warn,
              actionLabel: 'Ir a caja',
              onAction: () => _goToCashRegister(context),
            ),
          ],
        ],
        if (showCancellation) ...<Widget>[
          if (showPayment) const SizedBox(height: 8),
          EzyButton(
            label: 'Cancelar o reembolsar',
            icon: Icons.undo_outlined,
            variant: EzyButtonVariant.outline,
            onPressed: () => showCancellationSheet(context, detail: detail),
          ),
        ],
      ],
    );
  }

  /// Cierra la hoja y lleva al turno de caja para abrirlo.
  static void _goToCashRegister(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();

    router.go(AppTab.cashRegister.path);
  }
}
