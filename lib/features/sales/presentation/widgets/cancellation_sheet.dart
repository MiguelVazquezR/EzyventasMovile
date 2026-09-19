import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_button.dart';
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

    final canRefund = ref
        .read(permissionsProvider)
        .can('transactions.refund');
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
    final surfaces = context.surfaces;
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
          Text(
            'Anular transacción',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cancelación o reembolso',
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          NoticeBanner(
            message: widget.detail.paidAmount > 0.01
                ? 'Esta venta (folio ${widget.detail.folio}) tiene pagos '
                      'registrados por ${Money.format(widget.detail.paidAmount)}.'
                : 'Esta venta no tiene pagos registrados.',
            tone: EzySeverity.info,
          ),
          const SizedBox(height: 16),
          if (canRefund)
            _OptionCard(
              isSelected: _action == _CancellationAction.refund,
              title: 'Devolver al cliente (reembolso)',
              onTap: () =>
                  setState(() => _action = _CancellationAction.refund),
              child: _action == _CancellationAction.refund
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (session != null)
                          _MethodOption(
                            isSelected: _refundMethod == RefundMethod.cash,
                            label: RefundMethod.cash.label,
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
                        _MethodOption(
                          isSelected: _refundMethod == RefundMethod.transfer,
                          label: RefundMethod.transfer.label,
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
                            onSelected: (account) => setState(
                              () => _bankAccountId = account.id,
                            ),
                          ),
                        ],
                        if (customer != null)
                          _MethodOption(
                            isSelected: _refundMethod == RefundMethod.balance,
                            label: RefundMethod.balance.label,
                            onTap: () => setState(
                              () => _refundMethod = RefundMethod.balance,
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: NoticeBanner(
                              message:
                                  'No se puede abonar a saldo (venta sin cliente).',
                              tone: EzySeverity.warn,
                            ),
                          ),
                      ],
                    )
                  : null,
            ),
          if (canRefund && canCancel) const SizedBox(height: 12),
          if (canCancel)
            _OptionCard(
              isSelected: _action == _CancellationAction.penalty,
              isDanger: true,
              title: 'Cobrar como penalización',
              description:
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

/// Tarjeta seleccionable de una opción de anulación.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.isSelected,
    required this.title,
    required this.onTap,
    this.description,
    this.child,
    this.isDanger = false,
  });

  final bool isSelected;
  final String title;
  final VoidCallback onTap;
  final String? description;
  final Widget? child;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final accent = isDanger ? EzyColors.danger : EzyColors.primary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.12)
              : surfaces.panelInner,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent.withValues(alpha: 0.6) : surfaces.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: isSelected ? accent : surfaces.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: isDanger && isSelected
                          ? StatusPalette.text(context, EzySeverity.danger)
                          : surfaces.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (description != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                description!,
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ],
            if (child != null) ...<Widget>[
              const SizedBox(height: 12),
              child!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Opción de reembolso (efectivo de caja, transferencia o saldo a favor).
class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: isSelected ? EzyColors.primary : surfaces.textMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: EzyTextStyles.body.copyWith(
                  color: isSelected
                      ? surfaces.textPrimary
                      : surfaces.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
