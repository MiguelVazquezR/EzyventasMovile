import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/field_label.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cash/application/cash_register_controller.dart';
import '../../../cash/data/models/bank_account.dart';
import '../../../pos/data/models/payment_draft.dart';
import '../../../pos/presentation/widgets/payment_sheet.dart';
import '../../application/sales_controller.dart';
import '../../data/models/transaction_detail.dart';
import 'abono_ticket_view.dart';

/// Registra un abono a una venta (`POST /transactions/{id}/payments`).
///
/// Al confirmar muestra el ticket de abono que devolvió el servidor. El saldo a
/// favor se pide con `use_balance: true` y, si el servidor responde con error,
/// se muestra su `message`.
Future<void> showAbonoSheet(
  BuildContext context, {
  required TransactionDetail detail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _AbonoSheet(detail: detail),
  );
}

class _AbonoSheet extends ConsumerStatefulWidget {
  const _AbonoSheet({required this.detail});

  final TransactionDetail detail;

  @override
  ConsumerState<_AbonoSheet> createState() => _AbonoSheetState();
}

class _AbonoSheetState extends ConsumerState<_AbonoSheet> {
  /// Se precarga un pago en efectivo por el saldo pendiente (como la web).
  late final List<PaymentDraft> _payments = <PaymentDraft>[
    PaymentDraft(
      method: PosPaymentMethod.cash,
      amount: widget.detail.pendingBalance,
    ),
  ];

  bool _useBalance = false;

  @override
  void initState() {
    super.initState();

    // Un ticket de un abono anterior no debe confundirse con el nuevo.
    Future<void>.microtask(
      () =>
          ref.read(transactionDetailControllerProvider.notifier).consumeReceipt(),
    );
  }

  /// Saldo pendiente que acepta el servidor (no admite sobrepagos en abonos).
  double get _remaining => widget.detail.pendingBalance;

  /// Saldo a favor disponible del cliente.
  double get _balanceAvailable {
    final balance = widget.detail.customer?.balance ?? 0;

    return balance > 0 ? balance : 0;
  }

  /// Saldo a favor que se aplicaría: `min(disponible, pendiente)`.
  double get _balanceUsed {
    if (!_useBalance || _balanceAvailable <= 0) {
      return 0;
    }

    return Money.round2(
      _balanceAvailable < _remaining ? _balanceAvailable : _remaining,
    );
  }

  double get _paymentsTotal =>
      Money.round2(_payments.fold<double>(0, (sum, p) => sum + p.amount));

  double get _covered => Money.round2(_paymentsTotal + _balanceUsed);

  /// Lo que sigue pendiente después del abono.
  double get _leftToPay => Money.round2(_remaining - _covered);

  /// El servidor rechaza el abono que excede el saldo pendiente.
  bool get _overpaid => _covered > Money.round2(_remaining + 0.01);

  bool get _hasIncompletePayment => _payments.any(
    (payment) =>
        payment.amount <= 0 ||
        (payment.method.requiresBankAccount &&
            (payment.bankAccountId ?? 0) <= 0),
  );

  bool get _canSubmit =>
      _covered > 0.005 && !_overpaid && !_hasIncompletePayment;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final state = ref.watch(transactionDetailControllerProvider);
    final receipt = state.receipt;

    // El abono ya se registró: se muestra el ticket que devolvió el servidor.
    if (receipt != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          AbonoTicketView(
            receipt: receipt,
            onDone: () {
              ref
                  .read(transactionDetailControllerProvider.notifier)
                  .consumeReceipt();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'Registrar abono',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Folio ${widget.detail.folio} · ${widget.detail.customerLabel}',
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Resumen de la venta',
            child: Column(
              children: <Widget>[
                SectionRow(
                  label: 'Total',
                  value: Money.format(widget.detail.total),
                ),
                SectionRow(
                  label: 'Pagado',
                  value: Money.format(widget.detail.paidAmount),
                ),
                const Divider(height: 20),
                SectionRow(
                  label: 'Saldo pendiente',
                  value: Money.format(_remaining),
                  emphasized: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _PaymentsCard(
            payments: _payments,
            leftToPay: _leftToPay,
            onAdd: _addPayment,
            onRemove: _removePayment,
            onAmountChanged: _setAmount,
            onBankAccount: _setBankAccount,
            onFillRemaining: _fillRemaining,
          ),
          if (_balanceAvailable > 0) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Saldo a favor',
              // `Material` transparente: sin él el *ripple* del interruptor se
              // pinta debajo del fondo de la tarjeta.
              child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _useBalance,
                  onChanged: _setUseBalance,
                  title: Text(
                    'Usar saldo a favor',
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Disponible ${Money.format(_balanceAvailable)} · se '
                    'aplicarán ${Money.format(_balanceUsed)}',
                    style: EzyTextStyles.secondary.copyWith(
                      color: surfaces.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (_overpaid) ...<Widget>[
            const SizedBox(height: 12),
            const NoticeBanner(
              message: 'El monto total del pago excede el saldo pendiente.',
            ),
          ] else if (_leftToPay > 0.01) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(
              message:
                  'Quedarán ${Money.format(_leftToPay)} pendientes de la venta.',
              tone: EzySeverity.warn,
            ),
          ],
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(message: state.errorMessage!),
          ],
          const SizedBox(height: 16),
          EzyButton(
            label: 'Registrar abono',
            icon: Icons.check_outlined,
            isLoading: state.isSubmitting,
            onPressed: (_canSubmit && !state.isSubmitting) ? _submit : null,
          ),
        ],
      ),
    );
  }

  void _addPayment(PosPaymentMethod method) {
    setState(() {
      _payments.add(
        PaymentDraft(
          method: method,
          amount: _leftToPay > 0.005 ? _leftToPay : 0,
        ),
      );
    });
  }

  void _removePayment(int index) {
    setState(() => _payments.removeAt(index));
  }

  /// El saldo a favor se aplica primero: al activarlo se ajusta (o se quita) el
  /// efectivo para no exceder el pendiente, porque el servidor rechaza el
  /// sobrepago en los abonos.
  void _setUseBalance(bool value) {
    setState(() {
      _useBalance = value;

      if (!value) {
        return;
      }

      final balanceToUse = Money.round2(
        _balanceAvailable < _remaining ? _balanceAvailable : _remaining,
      );
      final cashDue = Money.round2(_remaining - balanceToUse);
      final index = _payments.indexWhere((payment) => payment.isCash);

      if (index < 0) {
        return;
      }

      if (cashDue <= 0.005) {
        _payments.removeAt(index);
        return;
      }

      _payments[index] = _payments[index].copyWith(amount: cashDue);
    });
  }

  void _setAmount(int index, double amount) {
    setState(
      () => _payments[index] = _payments[index].copyWith(amount: amount),
    );
  }

  void _setBankAccount(int index, {required int id, required String name}) {
    setState(
      () => _payments[index] = _payments[index].copyWith(
        bankAccountId: id,
        bankAccountName: name,
      ),
    );
  }

  /// Rellena el pago en efectivo con lo que falta por cubrir.
  void _fillRemaining() {
    if (_leftToPay <= 0.005) {
      return;
    }

    setState(() {
      final index = _payments.indexWhere((payment) => payment.isCash);

      if (index < 0) {
        _payments.add(
          PaymentDraft(method: PosPaymentMethod.cash, amount: _leftToPay),
        );
        return;
      }

      _payments[index] = _payments[index].copyWith(
        amount: Money.round2(_payments[index].amount + _leftToPay),
      );
    });
  }

  /// Envía el abono: el servidor recalcula saldo, deuda y movimientos de caja.
  Future<void> _submit() async {
    final sessionId = ref.read(activeCashSessionProvider)?.id;
    if (sessionId == null) {
      return;
    }

    await ref
        .read(transactionDetailControllerProvider.notifier)
        .addPayment(
          sessionId: sessionId,
          useBalance: _useBalance && _balanceUsed > 0,
          payments: _payments
              .where((payment) => payment.amount > 0)
              .toList(growable: false),
        );
  }
}

/// Captura de los pagos del abono (pago mixto, cuentas destino).
class _PaymentsCard extends ConsumerWidget {
  const _PaymentsCard({
    required this.payments,
    required this.leftToPay,
    required this.onAdd,
    required this.onRemove,
    required this.onAmountChanged,
    required this.onBankAccount,
    required this.onFillRemaining,
  });

  final List<PaymentDraft> payments;
  final double leftToPay;
  final ValueChanged<PosPaymentMethod> onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int index, double amount) onAmountChanged;
  final void Function(int index, {required int id, required String name})
  onBankAccount;
  final VoidCallback onFillRemaining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banks = ref.watch(bankAccountsProvider);

    return SectionCard(
      title: 'Pago',
      trailing: leftToPay > 0.005
          ? TextButton(
              onPressed: onFillRemaining,
              child: const Text('Liquidar saldo'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var index = 0; index < payments.length; index++)
            Padding(
              padding: EdgeInsets.only(bottom: index == payments.length - 1 ? 0 : 16),
              child: _AbonoPaymentRow(
                payment: payments[index],
                banks: banks,
                onRemove: () => onRemove(index),
                onAmountChanged: (amount) => onAmountChanged(index, amount),
                onBankAccount: (account) => onBankAccount(
                  index,
                  id: account.id,
                  name: account.label,
                ),
              ),
            ),
          const SizedBox(height: 16),
          _AddPaymentRow(
            used: payments
                .map((payment) => payment.method)
                .toSet(),
            onAdd: onAdd,
          ),
        ],
      ),
    );
  }
}

/// Un pago del abono: método, monto y cuenta destino.
class _AbonoPaymentRow extends StatelessWidget {
  const _AbonoPaymentRow({
    required this.payment,
    required this.banks,
    required this.onRemove,
    required this.onAmountChanged,
    required this.onBankAccount,
  });

  final PaymentDraft payment;
  final AsyncValue<List<BankAccount>> banks;
  final VoidCallback onRemove;
  final ValueChanged<double> onAmountChanged;
  final ValueChanged<BankAccount> onBankAccount;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                payment.method.label,
                style: EzyTextStyles.bodyStrong.copyWith(
                  color: surfaces.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Quitar método',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 18, color: surfaces.textMuted),
            ),
          ],
        ),
        PaymentAmountField(payment: payment, onChanged: onAmountChanged),
        if (payment.method.requiresBankAccount) ...<Widget>[
          const SizedBox(height: 12),
          BankAccountSelector(
            banks: banks,
            selectedId: payment.bankAccountId,
            errorText: payment.needsBankAccount
                ? 'Selecciona la cuenta destino para los pagos con tarjeta o transferencia.'
                : null,
            onSelected: onBankAccount,
          ),
        ],
      ],
    );
  }
}

/// Agrega un método de pago que aún no está en el abono.
class _AddPaymentRow extends StatelessWidget {
  const _AddPaymentRow({required this.used, required this.onAdd});

  final Set<PosPaymentMethod> used;
  final ValueChanged<PosPaymentMethod> onAdd;

  @override
  Widget build(BuildContext context) {
    final available = PosPaymentMethod.values
        .where((method) => !used.contains(method))
        .toList(growable: false);

    if (available.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const FieldLabel('Agregar método'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            for (final method in available)
              ActionChip(
                label: Text(method.label),
                onPressed: () => onAdd(method),
              ),
          ],
        ),
      ],
    );
  }
}
