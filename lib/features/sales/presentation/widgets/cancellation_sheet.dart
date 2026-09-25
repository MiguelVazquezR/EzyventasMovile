import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_selectable_tile.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cash/application/cash_register_controller.dart';
import '../../../cash/data/models/active_cash_session.dart';
import '../../../pos/presentation/widgets/payment_sheet.dart';
import '../../application/sales_controller.dart';
import '../../data/models/refund_method.dart';
import '../../data/models/transaction_detail.dart';

/// Acción de anulación elegida por el usuario.
enum _CancellationAction { refund, penalty }

/// Anula una venta: devuelve el dinero (`POST /transactions/{id}/refund`) o lo
/// retiene como penalización (`POST /transactions/{id}/cancel` con
/// `action = penalty`).
///
/// El contrato **no** acepta un motivo escrito: el servidor responde con el
/// `message` que explica el resultado y la app lo muestra tal cual.
Future<void> showCancellationSheet(
  BuildContext context, {
  required TransactionDetail detail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _CancellationSheet(detail: detail),
  );
}

class _CancellationSheet extends ConsumerStatefulWidget {
  const _CancellationSheet({required this.detail});

  final TransactionDetail detail;

  @override
  ConsumerState<_CancellationSheet> createState() => _CancellationSheetState();
}

class _CancellationSheetState extends ConsumerState<_CancellationSheet> {
  late _CancellationAction _action;
  RefundMethod? _refundMethod;
  int? _bankAccountId;

  @override
  void initState() {
    super.initState();

    final canRefund = ref.read(permissionsProvider).can('transactions.refund');
    final session = ref.read(activeCashSessionProvider);
    final hasCustomer = widget.detail.customer != null;

    _action = canRefund
        ? _CancellationAction.refund
        : _CancellationAction.penalty;

    // Método por defecto inteligente, igual que la web: caja si hay turno,
    // saldo a favor si la venta tiene cliente.
    _refundMethod = session != null
        ? RefundMethod.cash
        : (hasCustomer ? RefundMethod.balance : null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionDetailControllerProvider);
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);
    final banks = ref.watch(bankAccountsProvider);
    final customer = widget.detail.customer;

    final canRefund = permissions.can('transactions.refund');
    final canCancel = permissions.can('transactions.cancel');

    // La caja puede haberse cerrado después de abrir la hoja.
    if (_refundMethod == RefundMethod.cash && session == null) {
      _refundMethod = customer != null ? RefundMethod.balance : null;
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          EzySheetHeader(
            title: 'Anular transacción',
            subtitle: 'Cancelación o reembolso',
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 4),
          NoticeBanner(
            message: widget.detail.paidAmount > 0.01
                ? 'Esta venta (folio ${widget.detail.folio}) tiene pagos '
                      'registrados por ${Money.format(widget.detail.paidAmount)}.'
                : 'Esta venta no tiene pagos registrados.',
            tone: EzySeverity.info,
          ),
          const SizedBox(height: 16),
          if (canRefund)
            EzySelectableTile(
              isSelected: _action == _CancellationAction.refund,
              title: 'Devolver al cliente (reembolso)',
              onTap: () => setState(() => _action = _CancellationAction.refund),
              child: _action == _CancellationAction.refund
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (session != null)
                          EzySelectableTile(
                            compact: true,
                            isSelected: _refundMethod == RefundMethod.cash,
                            title: RefundMethod.cash.label,
                            onTap: () => setState(
                              () => _refundMethod = RefundMethod.cash,
                            ),
                          )
                        else
                          const NoticeBanner(
                            message:
                                'No hay caja abierta para devolver efectivo.',
                            tone: EzySeverity.warn,
                          ),
                        EzySelectableTile(
                          compact: true,
                          isSelected: _refundMethod == RefundMethod.transfer,
                          title: RefundMethod.transfer.label,
                          onTap: () => setState(
                            () => _refundMethod = RefundMethod.transfer,
                          ),
                        ),
                        if (_refundMethod == RefundMethod.transfer) ...<Widget>[
                          const SizedBox(height: 8),
                          BankAccountSelector(
                            banks: banks,
                            selectedId: _bankAccountId,
                            errorText: _bankAccountId == null
                                ? 'Selecciona la cuenta bancaria para el reembolso por transferencia.'
                                : null,
                            onSelected: (account) =>
                                setState(() => _bankAccountId = account.id),
                          ),
                        ],
                        if (customer != null)
                          EzySelectableTile(
                            compact: true,
                            isSelected: _refundMethod == RefundMethod.balance,
                            title: RefundMethod.balance.label,
                            onTap: () => setState(
                              () => _refundMethod = RefundMethod.balance,
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: NoticeBanner(
                              message: 'No se puede abonar a saldo (venta sin cliente).',
                              tone: EzySeverity.warn,
                            ),
                          ),
                      ],
                    )
                  : null,
            ),
          if (canRefund && canCancel) const SizedBox(height: 12),
          if (canCancel)
            EzySelectableTile(
              isSelected: _action == _CancellationAction.penalty,
              accent: EzyColors.danger,
              title: 'Cobrar como penalización',
              subtitle:
                  'El dinero no se devuelve. Se cancela la venta pero el negocio '
                  'retiene el monto pagado.',
              onTap: () =>
                  setState(() => _action = _CancellationAction.penalty),
            ),
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(message: state.errorMessage!),
          ],
          const SizedBox(height: 20),
          EzyButton(
            label: _action == _CancellationAction.refund
                ? 'Confirmar devolución'
                : 'Confirmar penalización',
            icon: _action == _CancellationAction.refund
                ? Icons.replay_outlined
                : Icons.block_outlined,
            variant: _action == _CancellationAction.refund
                ? EzyButtonVariant.primary
                : EzyButtonVariant.danger,
            isLoading: state.isSubmitting,
            onPressed: (_canConfirm(session) && !state.isSubmitting)
                ? _submit
                : null,
          ),
          const SizedBox(height: 8),
          EzyButton(
            label: 'Cancelar',
            variant: EzyButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// El reembolso exige método (y cuenta si es transferencia).
  bool _canConfirm(ActiveCashSession? session) {
    if (_action == _CancellationAction.penalty) {
      return true;
    }

    final method = _refundMethod;
    if (method == null) {
      return false;
    }

    if (method.requiresSession && session == null) {
      return false;
    }

    return !method.requiresBankAccount || _bankAccountId != null;
  }

  Future<void> _submit() async {
    final controller = ref.read(transactionDetailControllerProvider.notifier);

    final result = _action == _CancellationAction.penalty
        ? await controller.cancelWithPenalty()
        : await controller.refund(
            method: _refundMethod!,
            bankAccountId: _bankAccountId,
          );

    if (result != null && mounted) {
      Navigator.of(context).pop();
    }
  }
}
