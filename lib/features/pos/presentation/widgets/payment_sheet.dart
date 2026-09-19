import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/field_label.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cash/application/cash_register_controller.dart';
import '../../../cash/data/models/bank_account.dart';
import '../../application/cart_controller.dart';
import '../../application/cart_state.dart';
import '../../data/models/payment_draft.dart';

/// Tipo de operación que captura el cobro.
enum PaymentMode { checkout, layaway }

/// Captura de pagos: efectivo, tarjeta, transferencia y saldo a favor.
///
/// Devuelve `true` cuando la operación quedó registrada en el servidor (el folio
/// y el cambio los muestra la hoja del carrito).
Future<bool> showPaymentSheet(
  BuildContext context, {
  PaymentMode mode = PaymentMode.checkout,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _PaymentSheet(mode: mode),
  );

  return result ?? false;
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.mode});

  final PaymentMode mode;

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final TextEditingController _expirationController = TextEditingController();

  DateTime? _expirationDate;

  bool get _isLayaway => widget.mode == PaymentMode.layaway;

  @override
  void initState() {
    super.initState();

    if (!_isLayaway) {
      Future<void>.microtask(
        () => ref.read(cartControllerProvider.notifier).preparePayments(),
      );
    }
  }

  @override
  void dispose() {
    _expirationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
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
          _SheetHeader(isLayaway: _isLayaway, cart: cart),
          const SizedBox(height: 16),
          _AmountsCard(cart: cart),
          if (cart.customer?.hasBalanceInFavor ?? false) ...<Widget>[
            const SizedBox(height: 12),
            _BalanceSwitch(
              customerBalance: cart.customer!.balance,
              balanceUsed: cart.balanceUsed,
              value: cart.useBalance,
              onChanged: controller.setUseBalance,
            ),
          ],
          const SizedBox(height: 12),
          _PaymentsCard(cart: cart, banks: banks),
          if (_isLayaway) ...<Widget>[
            const SizedBox(height: 12),
            _ExpirationField(
              controller: _expirationController,
              errorText: cart.errorFor('layaway_expiration_date'),
              onTap: _pickExpirationDate,
            ),
          ],
          if (cart.remaining > 0.01) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(
              message: cart.customer == null
                  ? 'Selecciona un cliente para dejar saldo pendiente.'
                  : 'Quedarán ${Money.format(cart.remaining)} a crédito del '
                        'cliente (disponible '
                        '${Money.format(cart.availableCredit)}).',
              tone: EzySeverity.warn,
            ),
          ],
          if (cart.blockerMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(message: cart.blockerMessage!),
          ],
          if (cart.errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(message: cart.errorMessage!),
          ],
          const SizedBox(height: 16),
          EzyButton(
            label: _isLayaway ? 'Crear apartado' : 'Finalizar venta',
            icon: Icons.check_outlined,
            isLoading: cart.isSubmitting,
            onPressed: _canSubmit(cart) ? () => _submit(cart) : null,
          ),
        ],
      ),
    );
  }

  /// El apartado exige fecha límite; la venta exige cliente si queda saldo.
  bool _canSubmit(CartState cart) {
    if (_isLayaway) {
      return cart.payments.every((payment) => payment.isComplete) &&
          _expirationDate != null;
    }

    return cart.canSubmitCheckout;
  }

  Future<void> _submit(CartState cart) async {
    final sessionId = ref.read(activeCashSessionProvider)?.id;
    if (sessionId == null) {
      return;
    }

    final controller = ref.read(cartControllerProvider.notifier);
    final result = _isLayaway
        ? await controller.layaway(
            sessionId: sessionId,
            expirationDate: _expirationDate!,
          )
        : await controller.checkout(sessionId: sessionId);

    if (result != null && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Fecha límite del apartado (`after:today` en el servidor).
  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? tomorrow,
      firstDate: tomorrow,
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Fecha límite del apartado',
    );

    if (picked != null) {
      setState(() {
        _expirationDate = picked;
        _expirationController.text = AppFormatters.date(picked);
      });
    }
  }
}

/// Encabezado del cobro (tipo de operación y cliente).
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.isLayaway, required this.cart});

  final bool isLayaway;
  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          isLayaway ? 'Apartado' : 'Cobro',
          style: EzyTextStyles.screenTitle.copyWith(
            color: surfaces.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          cart.customer == null
              ? 'Venta de público general'
              : 'Cliente: ${cart.customer!.displayName}',
          style: EzyTextStyles.secondary.copyWith(
            color: surfaces.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Total de la venta, saldo a favor usado y restante/cambio.
class _AmountsCard extends StatelessWidget {
  const _AmountsCard({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isChange = cart.remaining < -0.01;
    final highlight = StatusPalette.text(
      context,
      isChange ? EzySeverity.success : EzySeverity.warn,
    );

    return SectionCard(
      title: 'Total de la venta',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            Money.format(cart.total),
            style: EzyTextStyles.moneyLarge.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          if (cart.balanceUsed > 0)
            SectionRow(
              label: 'Saldo a favor aplicado',
              value: '-${Money.format(cart.balanceUsed)}',
            ),
          if (cart.paymentsTotal > 0)
            SectionRow(
              label: 'Pagos capturados',
              value: Money.format(cart.paymentsTotal),
            ),
          const Divider(height: 24),
          SectionRow(
            label: isChange ? 'Su cambio' : 'Restante',
            value: Money.format(isChange ? -cart.remaining : cart.remaining),
            emphasized: true,
            valueStyle: EzyTextStyles.moneyMedium.copyWith(color: highlight),
          ),
          if (isChange)
            Text(
              'El cambio lo calcula y devuelve el servidor al registrar la venta.',
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

/// Interruptor "Usar saldo a favor" (`use_balance`).
class _BalanceSwitch extends StatelessWidget {
  const _BalanceSwitch({
    required this.customerBalance,
    required this.balanceUsed,
    required this.value,
    required this.onChanged,
  });

  final double customerBalance;
  final double balanceUsed;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Saldo a favor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'El cliente tiene ${Money.format(customerBalance)} a favor.',
            style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
          ),
          if (value)
            SectionRow(
              label: 'Se aplicará',
              value: '-${Money.format(balanceUsed)}',
              emphasized: true,
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: value,
            onChanged: onChanged,
            title: Text(
              'Usar saldo a favor',
              style: EzyTextStyles.bodyStrong.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Captura de pagos: montos, cuenta destino y métodos disponibles.
class _PaymentsCard extends ConsumerWidget {
  const _PaymentsCard({required this.cart, required this.banks});

  final CartState cart;
  final AsyncValue<List<BankAccount>> banks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final controller = ref.read(cartControllerProvider.notifier);

    return SectionCard(
      title: 'Pagos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (cart.payments.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Sin pagos capturados: la venta quedará a crédito del cliente '
                'o se cubrirá con su saldo a favor.',
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
            ),
          for (var index = 0; index < cart.payments.length; index++)
            _PaymentTile(
              index: index,
              payment: cart.payments[index],
              banks: banks,
              errorText: cart.errorFor('payments.$index.bank_account_id'),
            ),
          _AddPaymentRow(
            used: cart.payments.map((payment) => payment.method).toSet(),
            onAdd: controller.addPayment,
          ),
        ],
      ),
    );
  }
}



/// Un pago: método, monto y cuenta destino si es tarjeta o transferencia.
class _PaymentTile extends ConsumerWidget {
  const _PaymentTile({
    required this.index,
    required this.payment,
    required this.banks,
    this.errorText,
  });

  final int index;
  final PaymentDraft payment;
  final AsyncValue<List<BankAccount>> banks;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(cartControllerProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surfaces.panelInner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  payment.method.label,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    color: context.surfaces.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => controller.removePayment(index),
                tooltip: 'Quitar método',
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          PaymentAmountField(
            payment: payment,
            onChanged: (value) => controller.setPaymentAmount(index, value),
          ),
          if (payment.method.requiresBankAccount) ...<Widget>[
            const SizedBox(height: 12),
            BankAccountSelector(
              banks: banks,
              selectedId: payment.bankAccountId,
              errorText: errorText,
              onSelected: (account) => controller.setPaymentBankAccount(
                index,
                id: account.id,
                name: account.label,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Monto del pago: mantiene su controlador para no perder el cursor y refleja
/// los cambios de monto hechos desde el carrito (por ejemplo al agregar otro
/// método de pago).
class PaymentAmountField extends StatefulWidget {
  const PaymentAmountField({
    super.key,
    required this.payment,
    required this.onChanged,
  });

  final PaymentDraft payment;
  final ValueChanged<double> onChanged;

  @override
  State<PaymentAmountField> createState() => _PaymentAmountFieldState();
}

class _PaymentAmountFieldState extends State<PaymentAmountField> {
  late final TextEditingController _controller = TextEditingController(
    text: MoneyField.format(widget.payment.amount),
  );

  @override
  void didUpdateWidget(PaymentAmountField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.payment.amount != oldWidget.payment.amount &&
        Money.parseInput(_controller.text) != widget.payment.amount) {
      _controller.text = MoneyField.format(widget.payment.amount);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MoneyField(
    label: 'Monto',
    controller: _controller,
    onChanged: widget.onChanged,
  );
}

/// Agrega un método de pago que aún no está en el cobro.
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

/// Fecha límite del apartado (solo lectura, se elige en el calendario).
class _ExpirationField extends StatelessWidget {
  const _ExpirationField({
    required this.controller,
    required this.onTap,
    this.errorText,
  });

  final TextEditingController controller;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return EzyTextField(
      label: 'Fecha límite del apartado',
      isRequired: true,
      readOnly: true,
      controller: controller,
      hint: 'Seleccionar fecha…',
      errorText: errorText,
      helperText: 'Debe ser posterior a hoy.',
      suffix: const Icon(Icons.calendar_today_outlined, size: 18),
      onTap: onTap,
    );
  }
}

/// Cuenta destino de los pagos con tarjeta o transferencia.
class BankAccountSelector extends StatelessWidget {
  const BankAccountSelector({
    super.key,
    required this.banks,
    required this.selectedId,
    required this.onSelected,
    this.errorText,
  });

  final AsyncValue<List<BankAccount>> banks;
  final int? selectedId;
  final ValueChanged<BankAccount> onSelected;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const FieldLabel('Cuenta destino', isRequired: true),
        const SizedBox(height: 8),
        banks.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (error, stackTrace) => const NoticeBanner(
            message: 'No se pudieron cargar las cuentas bancarias.',
          ),
          data: (accounts) {
            if (accounts.isEmpty) {
              return const NoticeBanner(
                message:
                    'No tienes cuentas bancarias asignadas para este método.',
              );
            }

            return DropdownButtonFormField<int>(
              initialValue: selectedId,
              isExpanded: true,
              items: <DropdownMenuItem<int>>[
                for (final account in accounts)
                  DropdownMenuItem<int>(
                    value: account.id,
                    child: Text(
                      account.label,
                      style: EzyTextStyles.fieldValue.copyWith(
                        color: surfaces.textPrimary,
                      ),
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                onSelected(
                  accounts.firstWhere((account) => account.id == value),
                );
              },
              decoration: InputDecoration(
                hintText: 'Seleccionar cuenta…',
                errorText: errorText,
                hintStyle: EzyTextStyles.fieldValue.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

