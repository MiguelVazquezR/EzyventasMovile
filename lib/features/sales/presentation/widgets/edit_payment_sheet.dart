import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_dialog.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/field_label.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../cash/application/cash_register_controller.dart';
import '../../../pos/presentation/widgets/payment_sheet.dart';
import '../../application/sales_controller.dart';
import '../../data/models/transaction_detail.dart';
import '../../data/models/transaction_payment_method.dart';

/// Edita un pago de la venta (`PUT .../payments/{paymentId}`) o lo elimina
/// (`DELETE`, `204`).
///
/// Devuelve `true` cuando el pago se actualizó o se eliminó.
Future<bool> showEditPaymentSheet(
  BuildContext context, {
  required TransactionPayment payment,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _EditPaymentSheet(payment: payment),
  );

  return result ?? false;
}

class _EditPaymentSheet extends ConsumerStatefulWidget {
  const _EditPaymentSheet({required this.payment});

  final TransactionPayment payment;

  @override
  ConsumerState<_EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends ConsumerState<_EditPaymentSheet> {
  late final TextEditingController _amountController = TextEditingController(
    text: MoneyField.format(widget.payment.amount.abs()),
  );
  late final TextEditingController _notesController = TextEditingController(
    text: widget.payment.notes ?? '',
  );

  late TransactionPaymentMethod _method =
      widget.payment.method ?? TransactionPaymentMethod.cash;
  late int? _bankAccountId = widget.payment.bankAccount?.id;
  late double _amount = widget.payment.amount.abs();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _needsBankAccount =>
      _method.requiresBankAccount && (_bankAccountId ?? 0) <= 0;

  bool get _canSubmit => _amount >= 0.01 && !_needsBankAccount;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionDetailControllerProvider);
    final banks = ref.watch(bankAccountsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          EzySheetHeader(
            title: 'Editar pago',
            subtitle:
                'El servidor concilia la cuenta bancaria y el saldo del cliente '
                'con el nuevo monto.',
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 4),
          MoneyField(
            label: 'Monto',
            isRequired: true,
            controller: _amountController,
            onChanged: (value) => setState(() => _amount = value),
          ),
          const SizedBox(height: 16),
          _MethodSelector(
            value: _method,
            options: TransactionPaymentMethod.editableOptions(
              widget.payment.method,
            ),
            onChanged: (value) => setState(() {
              _method = value;
              if (!value.requiresBankAccount) {
                _bankAccountId = null;
              }
            }),
          ),
          if (_method.requiresBankAccount) ...<Widget>[
            const SizedBox(height: 16),
            BankAccountSelector(
              banks: banks,
              selectedId: _bankAccountId,
              errorText: _needsBankAccount
                  ? 'Selecciona la cuenta destino para los pagos con tarjeta o transferencia.'
                  : null,
              onSelected: (account) =>
                  setState(() => _bankAccountId = account.id),
            ),
          ],
          const SizedBox(height: 16),
          EzyTextField(
            label: 'Notas internas / referencia',
            hint: 'Ej. Folio de transferencia, terminal usada…',
            maxLines: 3,
            controller: _notesController,
          ),
          if (state.errorMessage != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(message: state.errorMessage!),
          ],
          const SizedBox(height: 16),
          EzyButton(
            label: 'Guardar cambios',
            icon: Icons.check_outlined,
            isLoading: state.isSubmitting,
            onPressed: (_canSubmit && !state.isSubmitting) ? _submit : null,
          ),
          const SizedBox(height: 8),
          EzyButton(
            label: 'Eliminar pago',
            icon: Icons.delete_outline,
            variant: EzyButtonVariant.danger,
            onPressed: state.isSubmitting ? null : _confirmDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final saved = await ref
        .read(transactionDetailControllerProvider.notifier)
        .updatePayment(
          paymentId: widget.payment.id,
          amount: _amount,
          paymentMethod: _method.value,
          bankAccountId: _bankAccountId,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        );

    if (saved && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  /// Confirmación explícita: el borrado revierte el efecto del pago.
  Future<void> _confirmDelete() async {
    final confirmed = await showEzyConfirmDialog(
      context,
      title: 'Eliminar pago',
      message:
          '¿Estás seguro de que quieres eliminar este pago permanentemente?',
      confirmLabel: 'Eliminar pago',
      isDestructive: true,
    );

    if (!confirmed) {
      return;
    }

    final deleted = await ref
        .read(transactionDetailControllerProvider.notifier)
        .deletePayment(widget.payment.id);

    if (deleted && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

/// Selector del método de pago del pago editado.
class _MethodSelector extends StatelessWidget {
  const _MethodSelector({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final TransactionPaymentMethod value;
  final List<TransactionPaymentMethod> options;
  final ValueChanged<TransactionPaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const FieldLabel('Método de pago', isRequired: true),
        const SizedBox(height: 8),
        DropdownButtonFormField<TransactionPaymentMethod>(
          initialValue: value,
          isExpanded: true,
          items: <DropdownMenuItem<TransactionPaymentMethod>>[
            for (final method in options)
              DropdownMenuItem<TransactionPaymentMethod>(
                value: method,
                child: Text(
                  method.label,
                  style: EzyTextStyles.fieldValue.copyWith(
                    color: surfaces.textPrimary,
                  ),
                ),
              ),
          ],
          onChanged: (selected) {
            if (selected != null) {
              onChanged(selected);
            }
          },
          decoration: InputDecoration(
            hintText: 'Seleccionar método…',
            hintStyle: EzyTextStyles.fieldValue.copyWith(
              color: surfaces.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
