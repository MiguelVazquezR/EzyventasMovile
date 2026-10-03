import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_amount.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
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
  final result = await EzyBottomSheet.show<bool>(
    context,
    maxHeightFactor: 0.96,
    // §3 del rediseño: la hoja se apoya en el **mismo lienzo gris del POS** que el
    // carrito y el selector de cliente; las secciones blancas y su sombra son las
    // que dan el relieve.
    backgroundColor: context.surfaces.background,
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
    // Sin cliente no se puede dejar saldo pendiente: el aviso contextual del
    // desglose ya lo cuenta con su título, así que el motivo genérico del
    // carrito —exactamente el mismo texto— no se repite.
    final pendingWithoutCustomer =
        cart.remaining > 0.01 && cart.customer == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EzySheetHeader(
          title: _isLayaway ? 'Apartado' : 'Cobro',
          subtitle: cart.customer == null
              ? 'Venta de público general'
              : 'Cliente: ${cart.customer!.displayName}',
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              _AmountsCard(cart: cart, isLayaway: _isLayaway),
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
                  title: cart.customer == null
                      ? 'Saldo pendiente'
                      : 'Cuenta por cobrar',
                  message: cart.customer == null
                      ? 'Selecciona un cliente para dejar saldo pendiente.'
                      : 'Quedarán ${Money.format(cart.remaining)} a crédito del '
                            'cliente (disponible '
                            '${Money.format(cart.availableCredit)}).',
                  tone: EzySeverity.warn,
                ),
              ],
              if (cart.blockerMessage != null &&
                  !pendingWithoutCustomer) ...<Widget>[
                const SizedBox(height: 12),
                NoticeBanner(message: cart.blockerMessage!),
              ],
              if (cart.errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                NoticeBanner(message: cart.errorMessage!),
              ],
            ],
          ),
        ),
        // §8: cobrar es el héroe de la hoja — CTA de 56 px con relieve 3D.
        EzyActionBar(
          child: EzyPrimary3dButton(
            label: _isLayaway ? 'Crear apartado' : 'Finalizar venta',
            icon: Icons.check_outlined,
            height: 56,
            isLoading: cart.isSubmitting,
            onPressed: _canSubmit(cart) ? () => _submit(cart) : null,
          ),
        ),
      ],
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

/// Desglose financiero del cobro: total, cobertura, saldo a favor, pagos y
/// restante, con el color de estatus del estado final.
class _AmountsCard extends StatelessWidget {
  const _AmountsCard({required this.cart, required this.isLayaway});

  final CartState cart;
  final bool isLayaway;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isChange = cart.remaining < -0.01;
    final success = StatusPalette.text(context, EzySeverity.success);

    return SectionCard(
      title: 'Total de la venta',
      boxShadow: EzyColors.cardShadow,
      trailing: EzyChip(
        label: isLayaway ? 'Apartado' : 'Venta',
        tone: isLayaway ? EzySeverity.warn : null,
        selected: !isLayaway,
        compact: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EzyAmount(value: cart.total, size: EzyAmountSize.hero),
          const SizedBox(height: 16),
          _CoverageBar(paid: cart.paidTotal, total: cart.total),
          if (cart.balanceUsed > 0) ...<Widget>[
            const SizedBox(height: 12),
            _LedgerRow(
              label: 'Saldo a favor aplicado',
              value: '-${Money.format(cart.balanceUsed)}',
              dotColor: EzyColors.success,
              valueColor: success,
            ),
          ],
          if (cart.paymentsTotal > 0) ...<Widget>[
            SizedBox(height: cart.balanceUsed > 0 ? 6 : 12),
            _LedgerRow(
              label: 'Pagos capturados',
              value: Money.format(cart.paymentsTotal),
            ),
          ],
          Divider(height: 24, color: surfaces.border),
          _StateBlock(
            label: isChange ? 'Su cambio' : 'Restante',
            value: Money.format(isChange ? -cart.remaining : cart.remaining),
            tone: isChange ? EzySeverity.success : EzySeverity.warn,
          ),
          if (isChange) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              'El cambio lo calcula y devuelve el servidor al registrar la venta.',
              style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Barra de cobertura: qué parte del total ya está cubierta con pagos y saldo.
class _CoverageBar extends StatelessWidget {
  const _CoverageBar({required this.paid, required this.total});

  final double paid;
  final double total;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    if (total <= 0) {
      return const SizedBox.shrink();
    }

    // Se redondea a puntos porcentuales: la barra es un indicador de un vistazo.
    final filled = (paid / total * 100).round().clamp(0, 100).toInt();
    final complete = filled >= 100;
    final color = complete ? EzyColors.success : EzyColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 6,
            child: Row(
              children: <Widget>[
                if (filled > 0)
                  Expanded(
                    flex: filled,
                    child: ColoredBox(color: color),
                  ),
                if (filled < 100)
                  Expanded(
                    flex: 100 - filled,
                    child: ColoredBox(color: surfaces.borderStrong),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Cubierto',
                style: EzyTextStyles.microLabel.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
            ),
            Text(
              '${Money.format(paid)} de ${Money.format(total)}',
              style: EzyTextStyles.moneyList.copyWith(
                fontSize: 12,
                color: complete ? EzyColors.success : surfaces.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Renglón del desglose: concepto a la izquierda y monto en cifras tabulares.
class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.label,
    required this.value,
    this.dotColor,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? dotColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final dot = dotColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (dot != null) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            label,
            style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: EzyTextStyles.moneyList.copyWith(
            color: valueColor ?? surfaces.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Bloque de estado del cobro: el restante o el cambio, con su color de estatus.
class _StateBlock extends StatelessWidget {
  const _StateBlock({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final EzySeverity tone;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: StatusPalette.soft(tone),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StatusPalette.border(tone)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: EzyTextStyles.microLabel.copyWith(color: color),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: EzyTextStyles.moneyMedium.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
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
    final success = StatusPalette.text(context, EzySeverity.success);

    return SectionCard(
      title: 'Saldo a favor',
      boxShadow: EzyColors.cardShadow,
      trailing: EzyChip(
        icon: Icons.account_balance_wallet_outlined,
        label: Money.format(customerBalance),
        tone: EzySeverity.success,
        compact: true,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // `Material` transparente: el `SectionCard` pinta su propio fondo y sin
          // él el *ripple* del interruptor quedaría debajo del fondo.
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
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
          ),
          Text(
            'El cliente tiene ${Money.format(customerBalance)} a favor.',
            style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
          ),
          if (value) ...<Widget>[
            const SizedBox(height: 10),
            _LedgerRow(
              label: 'Se aplicará',
              value: '-${Money.format(balanceUsed)}',
              dotColor: EzyColors.success,
              valueColor: success,
            ),
          ],
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
      boxShadow: EzyColors.cardShadow,
      trailing: EzyChip(
        icon: Icons.receipt_long_outlined,
        label: 'Métodos',
        count: cart.payments.length,
        compact: true,
      ),
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
              errorText: _bankError(cart, index, cart.payments[index]),
            ),
          _AddPaymentRow(
            used: cart.payments.map((payment) => payment.method).toSet(),
            onAdd: controller.addPayment,
          ),
        ],
      ),
    );
  }

  /// Error del servidor o el motivo local para el selector de cuenta destino.
  String? _bankError(CartState cart, int index, PaymentDraft payment) {
    final serverError = cart.errorFor('payments.$index.bank_account_id');
    if (serverError != null) {
      return serverError;
    }

    return payment.needsBankAccount
        ? 'Selecciona la cuenta destino para los pagos con tarjeta o '
              'transferencia.'
        : null;
  }
}

/// Un pago capturado: método, monto y cuenta destino si el método la exige.
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
    final surfaces = context.surfaces;
    final controller = ref.read(cartControllerProvider.notifier);
    final severity = _methodSeverity(payment.method);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // Cada pago es una pieza blanca que flota dentro de su sección, con la
        // misma sombra que las tarjetas del carrito.
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
        boxShadow: EzyColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: StatusPalette.soft(severity),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: StatusPalette.border(severity)),
                ),
                child: Icon(
                  _methodIcon(payment.method),
                  size: 16,
                  color: StatusPalette.text(context, severity),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Pago ${index + 1}',
                      style: EzyTextStyles.microLabel.copyWith(
                        color: surfaces.textMuted,
                      ),
                    ),
                    Text(
                      payment.method.label,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        color: surfaces.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Tooltip(
                message: 'Quitar método',
                child: GestureDetector(
                  onTap: () => controller.removePayment(index),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaces.panelInner,
                      shape: BoxShape.circle,
                      border: Border.all(color: surfaces.border),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: StatusPalette.text(context, EzySeverity.danger),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PaymentAmountField(
            payment: payment,
            suffixText: 'MXN',
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

/// Severidad que tiñe la pieza de un pago según su método.
EzySeverity _methodSeverity(PosPaymentMethod method) => switch (method) {
  PosPaymentMethod.cash => EzySeverity.success,
  PosPaymentMethod.card => EzySeverity.info,
  PosPaymentMethod.transfer => EzySeverity.neutral,
};

/// Icono que identifica el método de pago.
IconData _methodIcon(PosPaymentMethod method) => switch (method) {
  PosPaymentMethod.cash => Icons.payments_outlined,
  PosPaymentMethod.card => Icons.credit_card,
  PosPaymentMethod.transfer => Icons.account_balance_outlined,
};

/// Monto del pago: mantiene su controlador para no perder el cursor y refleja
/// los cambios de monto hechos desde el carrito (por ejemplo al agregar otro
/// método de pago).
class PaymentAmountField extends StatefulWidget {
  const PaymentAmountField({
    super.key,
    required this.payment,
    required this.onChanged,
    this.suffixText,
  });

  final PaymentDraft payment;
  final ValueChanged<double> onChanged;

  /// Unidad monetaria al final del campo (`MXN` en esta hoja).
  final String? suffixText;

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
    fillColor: context.surfaces.panel,
    suffixText: widget.suffixText,
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
          runSpacing: 8,
          children: <Widget>[
            for (final method in available)
              EzyChip(
                label: method.label,
                icon: Icons.add,
                compact: true,
                onTap: () => onAdd(method),
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
    final surfaces = context.surfaces;

    return EzyTextField(
      label: 'Fecha límite del apartado',
      isRequired: true,
      readOnly: true,
      controller: controller,
      // Campo blanco sobre el lienzo gris, igual que en el resto del POS.
      fillColor: surfaces.panel,
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
    this.label = 'Cuenta destino',
  });

  final AsyncValue<List<BankAccount>> banks;
  final int? selectedId;
  final ValueChanged<BankAccount> onSelected;
  final String? errorText;

  /// Título del selector: la hoja de un pago mixto lo deja en «Cuenta destino»
  /// y el cobro de una orden lo abre a «Cuenta o terminal».
  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FieldLabel(label, isRequired: true),
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
                fillColor: surfaces.panel,
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
