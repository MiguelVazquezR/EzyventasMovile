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
import '../../../sales/presentation/widgets/abono_ticket_view.dart';
import '../../application/service_orders_controller.dart';
import '../../data/models/service_order_detail.dart';

/// Anticipo de una orden (`POST /service-orders/{id}/payments`).
///
/// Si la orden no tiene venta vinculada, primero se crea con
/// `POST /service-orders/{id}/ensure-transaction` (§9, órdenes antiguas).
Future<void> confirmServiceOrderPayment(
  BuildContext context,
  WidgetRef ref, {
  required ServiceOrderDetail detail,
}) async {
  var current = detail;

  if (!current.hasTransaction) {
    final ensured = await ref
        .read(serviceOrderDetailControllerProvider.notifier)
        .ensureTransaction();

    if (!context.mounted || !ensured) {
      final error = ref.read(serviceOrderDetailControllerProvider).errorMessage;

      if (error != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }

      return;
    }

    current = ref.read(serviceOrderDetailControllerProvider).detail ?? current;
  }

  if (!context.mounted) {
    return;
  }

  return showServiceOrderPaymentSheet(context, detail: current);
}

/// Hoja de anticipo con pago mixto y saldo a favor del cliente.
Future<void> showServiceOrderPaymentSheet(
  BuildContext context, {
  required ServiceOrderDetail detail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ServiceOrderPaymentSheet(detail: detail),
  );
}

class _ServiceOrderPaymentSheet extends ConsumerStatefulWidget {
  const _ServiceOrderPaymentSheet({required this.detail});

  final ServiceOrderDetail detail;

  @override
  ConsumerState<_ServiceOrderPaymentSheet> createState() =>
      _ServiceOrderPaymentSheetState();
}

class _ServiceOrderPaymentSheetState
    extends ConsumerState<_ServiceOrderPaymentSheet> {
  /// Se precarga un pago en efectivo por el saldo pendiente (como la web).
  late final List<PaymentDraft> _payments = <PaymentDraft>[
    PaymentDraft(method: PosPaymentMethod.cash, amount: _remaining),
  ];

  bool _useBalance = false;

  @override
  void initState() {
    super.initState();

    // Un ticket de un anticipo anterior no debe confundirse con el nuevo.
    Future<void>.microtask(
      () =>
          ref.read(serviceOrderDetailControllerProvider.notifier).consumeReceipt(),
    );
  }

  /// Saldo pendiente que acepta el servidor.
  double get _remaining {
    final linked = widget.detail.transaction;

    return linked == null ? widget.detail.pendingAmount : linked.remainingDue;
  }

  double get _balanceAvailable {
    final balance = widget.detail.customer?.balance ?? 0;

    return balance > 0 ? balance : 0;
  }

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

  double get _leftToPay => Money.round2(_remaining - _covered);

  bool get _overpaid => _covered > Money.round2(_remaining + 0.01);

  bool get _hasIncompletePayment => _payments.any(
    (payment) =>
        payment.amount <= 0 ||
        (payment.method.requiresBankAccount &&
            (payment.bankAccountId ?? 0) <= 0),
  );

  bool get _canSubmit =>
      _covered > 0.005 && !_overpaid && !_hasIncompletePayment;

  void _addPayment(PosPaymentMethod method) {
    setState(() {
      _payments.add(
        PaymentDraft(
          method: method,
          amount: method == PosPaymentMethod.cash && _leftToPay > 0.005
              ? _leftToPay
              : 0,
        ),
      );
    });
  }

  void _removePayment(int index) => setState(() => _payments.removeAt(index));

  void _setAmount(int index, double amount) {
    setState(() => _payments[index] = _payments[index].copyWith(amount: amount));
  }

  void _setBankAccount(int index, {required int id, required String name}) {
    setState(
      () => _payments[index] = _payments[index].copyWith(
        bankAccountId: id,
        bankAccountName: name,
      ),
    );
  }

  /// El saldo a favor se aplica con `use_balance: true` y no es un pago.
  void _setUseBalance(bool value) => setState(() => _useBalance = value);

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

  Future<void> _submit() async {
    final sessionId = ref.read(activeCashSessionProvider)?.id;
    if (sessionId == null) {
      return;
    }

    await ref
        .read(serviceOrderDetailControllerProvider.notifier)
        .addPayment(
          sessionId: sessionId,
          useBalance: _useBalance && _balanceUsed > 0,
          payments: _payments
              .where((payment) => payment.amount > 0)
              .toList(growable: false),
        );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final state = ref.watch(serviceOrderDetailControllerProvider);
    final receipt = state.receipt;

    // El anticipo ya se registró: se muestra el ticket que devolvió el servidor.
    if (receipt != null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          AbonoTicketView(
            receipt: receipt,
            onDone: () {
              ref
                  .read(serviceOrderDetailControllerProvider.notifier)
                  .consumeReceipt();
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }

    final banks = ref.watch(bankAccountsProvider);

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
            'Cobrar orden',
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
          if (state.errorMessage != null) ...<Widget>[
            NoticeBanner(
              message: state.errorMessage!,
              actionLabel: 'Ocultar',
              onAction: ref
                  .read(serviceOrderDetailControllerProvider.notifier)
                  .consumeError,
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: 'Resumen de la orden',
            child: Column(
              children: <Widget>[
                SectionRow(
                  label: 'Total',
                  value: Money.format(widget.detail.finalTotal),
                ),
                SectionRow(
                  label: 'Pagado',
                  value: Money.format(widget.detail.totalPaid),
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
            banks: banks,
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
                    'Disponible ${Money.format(_balanceAvailable)}',
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: 'Resultado del cobro',
            child: Column(
              children: <Widget>[
                SectionRow(label: 'Cubierto', value: Money.format(_covered)),
                SectionRow(
                  label: 'Queda pendiente',
                  value: Money.format(_leftToPay < 0 ? 0 : _leftToPay),
                  emphasized: _leftToPay > 0.005,
                ),
                if (_overpaid)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: NoticeBanner(
                      message: 'El monto excede el saldo pendiente de la orden.',
                      tone: EzySeverity.warn,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EzyButton(
            label: 'Registrar anticipo',
            icon: Icons.payments_outlined,
            isLoading: state.isSubmitting,
            onPressed: _canSubmit && !state.isSubmitting ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// Captura de los pagos del anticipo (pago mixto y cuentas destino).
class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({
    required this.payments,
    required this.banks,
    required this.leftToPay,
    required this.onAdd,
    required this.onRemove,
    required this.onAmountChanged,
    required this.onBankAccount,
    required this.onFillRemaining,
  });

  final List<PaymentDraft> payments;
  final AsyncValue<List<BankAccount>> banks;
  final double leftToPay;
  final ValueChanged<PosPaymentMethod> onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int index, double amount) onAmountChanged;
  final void Function(int index, {required int id, required String name})
  onBankAccount;
  final VoidCallback onFillRemaining;

  @override
  Widget build(BuildContext context) {
    final used = payments.map((payment) => payment.method).toSet();
    final available = PosPaymentMethod.values
        .where((method) => !used.contains(method))
        .toList(growable: false);

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
              padding: EdgeInsets.only(
                bottom: index == payments.length - 1 ? 0 : 16,
              ),
              child: _PaymentRow(
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
          if (available.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
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
        ],
      ),
    );
  }
}

/// Un pago del anticipo: método, monto y cuenta destino.
class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
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
                ? 'Selecciona la cuenta destino para los pagos con tarjeta o '
                      'transferencia.'
                : null,
            onSelected: onBankAccount,
          ),
        ],
      ],
    );
  }
}
