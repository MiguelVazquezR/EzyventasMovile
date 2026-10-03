import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_action_bar.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_selectable_tile.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../cash/application/cash_register_controller.dart';
import '../../../cash/data/models/bank_account.dart';
import '../../../pos/presentation/widgets/payment_sheet.dart';
import '../../application/sales_controller.dart';
import '../../data/models/refund_method.dart';
import '../../data/models/transaction_detail.dart';

/// `#C95B00`: el naranja de marca es ilegible como texto sobre un fondo claro
/// (§13: el naranja pleno no llega al umbral), así que en modo claro el badge de
/// reembolso y el «Cancelar» del CTA usan este tono oscuro.
const Color _primaryTextLight = Color(0xFFC95B00);

/// Acción de anulación elegida por el usuario.
enum _CancellationAction { refund, penalty }

/// Anula una venta: devuelve el dinero (`POST /transactions/{id}/refund`) o lo
/// retiene como penalización (`POST /transactions/{id}/cancel` con
/// `action = penalty`).
///
/// El contrato **no** acepta un motivo escrito: el servidor responde con el
/// `message` que explica el resultado y la app lo muestra tal cual.
Future<bool?> showCancellationSheet(
  BuildContext context, {
  required TransactionDetail detail,
}) {
  return EzyBottomSheet.show<bool>(
    context,
    builder: (sheetContext) => _CancellationSheet(detail: detail),
  );
}

/// Método de reembolso por defecto: caja si hay turno abierto, saldo a favor si
/// la venta tiene cliente y, en su defecto, transferencia.
RefundMethod resolveDefaultRefundMethod({
  required bool hasOpenDrawer,
  required bool hasCustomer,
}) {
  if (hasOpenDrawer) {
    return RefundMethod.cash;
  }
  if (hasCustomer) {
    return RefundMethod.balance;
  }
  return RefundMethod.transfer;
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
  int? _accountId;

  @override
  void initState() {
    super.initState();

    final canRefund = ref.read(permissionsProvider).can('transactions.refund');
    final hasDrawer = ref.read(activeCashSessionProvider) != null;
    final hasCustomer = widget.detail.customer != null;

    _action = canRefund
        ? _CancellationAction.refund
        : _CancellationAction.penalty;
    _refundMethod = resolveDefaultRefundMethod(
      hasOpenDrawer: hasDrawer,
      hasCustomer: hasCustomer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(transactionDetailControllerProvider);
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);
    final banks = ref.watch(bankAccountsProvider);

    final canRefund = permissions.can('transactions.refund');
    final canCancel = permissions.can('transactions.cancel');
    final customer = widget.detail.customer;
    final hasDrawer = session != null;

    // El turno pudo cerrarse después de abrir la hoja: el efectivo deja de ser
    // un método válido y se cae al siguiente método disponible.
    if (_refundMethod == RefundMethod.cash && !hasDrawer) {
      _refundMethod = resolveDefaultRefundMethod(
        hasOpenDrawer: false,
        hasCustomer: customer != null,
      );
    }

    final isConfirmEnabled =
        !state.isSubmitting &&
        (_action == _CancellationAction.penalty ||
            _isRefundReady(
              hasDrawer: hasDrawer,
              hasCustomer: customer != null,
            ));

    // El asa de arrastre, el radio de 24, el fondo del panel y el alto máximo
    // (90 %) los pone el estándar de hojas (`EzyBottomSheet` + el tema): la hoja
    // no repite banderas ni pinta su propio recorte.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EzySheetHeader(
          title: 'Anular transacción',
          subtitle: 'Cancelación o reembolso',
          padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
          trailing: EzyIconButton(
            icon: Icons.close,
            tooltip: 'Cerrar',
            size: 32,
            iconSize: 16,
            color: surfaces.textSecondary,
            background: surfaces.panelInner,
            borderColor: surfaces.border,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              // Aviso contextual con nombre (§5): el folio y lo cobrado son los
              // dos datos que deciden la anulación.
              NoticeBanner(
                tone: EzySeverity.info,
                title: 'Venta #${widget.detail.folio}',
                message: widget.detail.paidAmount > 0.01
                    ? 'Esta venta tiene pagos registrados por '
                          '${Money.format(widget.detail.paidAmount)}.'
                    : 'Esta venta no tiene pagos registrados.',
              ),
              if (state.errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                NoticeBanner(message: state.errorMessage!),
              ],
              const SizedBox(height: 16),
              if (canRefund)
                _refundOption(
                  banks: banks,
                  hasDrawer: hasDrawer,
                  customerName: customer?.name,
                ),
              if (canRefund && canCancel) const SizedBox(height: 12),
              if (canCancel) _penaltyOption(),
            ],
          ),
        ),
        _footer(
          isDark: isDark,
          isSubmitting: state.isSubmitting,
          isConfirmEnabled: isConfirmEnabled,
        ),
      ],
    );
  }

  /// Opción «devolver el dinero», con los submétodos de reembolso desplegados
  /// mientras está elegida.
  Widget _refundOption({
    required AsyncValue<List<BankAccount>> banks,
    required bool hasDrawer,
    required String? customerName,
  }) {
    final isSelected = _action == _CancellationAction.refund;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return EzySelectableTile(
      accent: EzyColors.primary,
      title: 'Devolver al cliente (reembolso)',
      subtitle: 'Se reintegra el importe pagado por la vía seleccionada',
      trailing: _BadgePill(
        label: 'REEMBOLSO',
        accent: EzyColors.primary,
        textColor: isDark ? EzyColors.primary : _primaryTextLight,
        borderAlpha: 0.35,
      ),
      isSelected: isSelected,
      onTap: () => setState(() => _action = _CancellationAction.refund),
      child: isSelected
          ? _refundMethods(
              banks: banks,
              hasDrawer: hasDrawer,
              customerName: customerName,
            )
          : null,
    );
  }

  /// Opción destructiva: la venta se cancela y el negocio retiene lo cobrado.
  Widget _penaltyOption() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return EzySelectableTile(
      accent: EzyColors.danger,
      title: 'Cobrar como penalización',
      subtitle:
          'El dinero no se devuelve. Se cancela la venta pero el negocio '
          'retiene el monto pagado.',
      trailing: _BadgePill(
        label: 'RETENCIÓN',
        accent: EzyColors.danger,
        textColor: isDark
            ? EzyColors.dangerTextDark
            : EzyColors.dangerTextLight,
        borderAlpha: 0.30,
      ),
      isSelected: _action == _CancellationAction.penalty,
      onTap: () => setState(() => _action = _CancellationAction.penalty),
    );
  }

  /// El reembolso exige método válido (y cuenta si es transferencia).
  bool _isRefundReady({required bool hasDrawer, required bool hasCustomer}) {
    switch (_refundMethod) {
      case RefundMethod.cash:
        return hasDrawer;
      case RefundMethod.transfer:
        return _accountId != null;
      case RefundMethod.balance:
        return hasCustomer;
      case null:
        return false;
    }
  }

  /// Submétodos de reembolso, visibles con la opción «Reembolso» seleccionada.
  Widget _refundMethods({
    required AsyncValue<List<BankAccount>> banks,
    required bool hasDrawer,
    required String? customerName,
  }) {
    final method = _refundMethod;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EzySelectableTile(
          compact: true,
          title: RefundMethod.cash.label,
          isSelected: method == RefundMethod.cash,
          onTap: () => setState(() => _refundMethod = RefundMethod.cash),
        ),
        if (!hasDrawer) ...<Widget>[
          const SizedBox(height: 2),
          const NoticeBanner(
            message: 'No hay caja abierta para devolver efectivo.',
            tone: EzySeverity.warn,
          ),
        ],
        EzySelectableTile(
          compact: true,
          title: RefundMethod.transfer.label,
          isSelected: method == RefundMethod.transfer,
          onTap: () => setState(() => _refundMethod = RefundMethod.transfer),
        ),
        if (method == RefundMethod.transfer) ...<Widget>[
          const SizedBox(height: 8),
          BankAccountSelector(
            banks: banks,
            selectedId: _accountId,
            errorText: _accountId == null
                ? 'Selecciona la cuenta bancaria para el reembolso por '
                      'transferencia.'
                : null,
            onSelected: (account) => setState(() => _accountId = account.id),
          ),
        ],
        EzySelectableTile(
          compact: true,
          title: RefundMethod.balance.label,
          subtitle: customerName,
          isSelected: method == RefundMethod.balance,
          onTap: () => setState(() => _refundMethod = RefundMethod.balance),
        ),
        if (customerName == null) ...<Widget>[
          const SizedBox(height: 2),
          const NoticeBanner(
            message: 'No se puede abonar a saldo (venta sin cliente).',
            tone: EzySeverity.warn,
          ),
        ],
      ],
    );
  }

  /// CTA del pie: la cara del botón cambia con la acción elegida —naranja al
  /// devolver, rojo del sistema al retener— y «Cancelar» queda como salida.
  Widget _footer({
    required bool isDark,
    required bool isSubmitting,
    required bool isConfirmEnabled,
  }) {
    final isRefund = _action == _CancellationAction.refund;

    return EzyActionBar(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: <Widget>[
        // CTA estándar del sistema (§4): naranja de marca al devolver el dinero y
        // rojo destructivo al retenerlo. La anulación no inventa botón propio.
        EzyButton(
          label: isRefund ? 'Confirmar devolución' : 'Confirmar penalización',
          icon: isRefund ? Icons.replay_outlined : Icons.block_outlined,
          variant: isRefund
              ? EzyButtonVariant.primary
              : EzyButtonVariant.danger,
          isLoading: isSubmitting,
          onPressed: isConfirmEnabled ? _submit : null,
        ),
        EzyButton(
          label: 'Cancelar',
          variant: EzyButtonVariant.text,
          expand: false,
          textColor: isDark ? EzyColors.primary : _primaryTextLight,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  /// La venta se cierra y la hoja se retira. El aviso de éxito lo pinta el
  /// detalle con el `message` del servidor (`state.notice`), así que la hoja solo
  /// devuelve `true` a quien la abrió.
  Future<void> _submit() async {
    final controller = ref.read(transactionDetailControllerProvider.notifier);

    final result = _action == _CancellationAction.penalty
        ? await controller.cancelWithPenalty()
        : await controller.refund(
            method: _refundMethod!,
            bankAccountId: _accountId,
          );

    if (result != null && mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

/// Micro-etiqueta de estado de la tarjeta de anulación («REEMBOLSO» /
/// «RETENCIÓN»), a la derecha del título.
///
/// El color del texto lo elige quien la usa: el rojo del sistema no se lee igual
/// sobre el panel claro que sobre el oscuro (`dangerTextLight` / `dangerTextDark`).
class _BadgePill extends StatelessWidget {
  const _BadgePill({
    required this.label,
    required this.accent,
    required this.textColor,
    required this.borderAlpha,
  });

  final String label;
  final Color accent;
  final Color textColor;
  final double borderAlpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: borderAlpha)),
      ),
      child: Text(
        label,
        style: EzyTextStyles.badge.copyWith(
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
