import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/status_palette.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/ezy_dialog.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/cash_register_controller.dart';
import '../data/models/active_cash_session.dart';
import '../data/models/opening_bank_balance.dart';
import 'widgets/cash_shift_setup.dart';
import 'widgets/close_shift_sheet.dart';

/// Pestaña "Caja".
///
/// Estados:
/// - **sin turno**: apertura (terminal + fondo + saldos bancarios), unión a un
///   turno abierto, retome sin contar el fondo, o aviso para abrir desde la web;
/// - **con turno**: resumen del turno y corte de caja (arqueo con diferencia en
///   vivo), más la salida del turno sin cerrarlo.
class CashRegisterScreen extends ConsumerWidget {
  const CashRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cashRegisterControllerProvider);
    final controller = ref.read(cashRegisterControllerProvider.notifier);
    final session = state.activeSession;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AppScreenHeader(
              title: 'Caja',
              subtitle: session == null
                  ? 'Sin turno abierto'
                  : 'Turno abierto en ${session.cashRegisterName}',
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    if (state.notice != null) ...<Widget>[
                      NoticeBanner(
                        message: state.notice!,
                        tone: EzySeverity.success,
                        icon: Icons.check_circle_outline,
                        actionLabel: 'Ocultar',
                        onAction: controller.consumeNotice,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (session != null)
                      ..._shiftWidgets(ref, session)
                    else
                      ..._setupWidgets(ref, state),
                    if (state.isLoading) ...<Widget>[
                      const SizedBox(height: 16),
                      const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Turno abierto: resumen, corte y salida del turno.
  List<Widget> _shiftWidgets(WidgetRef ref, ActiveCashSession session) {
    final state = ref.watch(cashRegisterControllerProvider);
    final controller = ref.read(cashRegisterControllerProvider.notifier);

    return <Widget>[
      SectionCard(
        title: 'Turno actual',
        trailing: const StatusBadge(
          label: 'Abierta',
          severity: EzySeverity.success,
          showDot: true,
        ),
        child: Column(
          children: <Widget>[
            SectionRow(label: 'Terminal', value: session.cashRegisterName),
            SectionRow(
              label: 'Apertura',
              value: AppFormatters.dateTime(session.openedAt),
            ),
            if (session.opener != null)
              SectionRow(label: 'Abrió', value: session.opener!.name),
            SectionRow(
              label: 'Fondo inicial',
              value: Money.format(session.openingCashBalance),
            ),
            SectionRow(
              label: 'Usuarios en la sesión',
              value: '${session.users.length}',
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SectionCard(
        title: 'Cobros del turno',
        child: Column(
          children: <Widget>[
            SectionRow(
              label: 'Efectivo',
              value: Money.format(session.totals.cash),
            ),
            SectionRow(
              label: 'Tarjeta',
              value: Money.format(session.totals.card),
            ),
            SectionRow(
              label: 'Transferencia',
              value: Money.format(session.totals.transfer),
            ),
            SectionRow(
              label: 'Saldo a favor',
              value: Money.format(session.totals.balance),
            ),
            const Divider(height: 24),
            SectionRow(
              label: 'Total cobrado',
              value: Money.format(session.totals.total),
              emphasized: true,
            ),
          ],
        ),
      ),
      if (session.openingBankBalances.isNotEmpty) ...<Widget>[
        const SizedBox(height: 12),
        _BankSnapshotCard(balances: session.openingBankBalances),
      ],
      if (session.hasMultipleUsers) ...<Widget>[
        const SizedBox(height: 12),
        NoticeBanner(
          message:
              'Hay ${session.users.length} usuarios en esta sesión; al cerrarla, '
              'todos saldrán de la caja.',
          tone: EzySeverity.warn,
        ),
      ],
      if (state.errorMessage != null) ...<Widget>[
        const SizedBox(height: 12),
        NoticeBanner(message: state.errorMessage!),
      ],
      const SizedBox(height: 16),
      EzyButton(
        label: 'Hacer corte',
        icon: Icons.point_of_sale_outlined,
        onPressed: () => showCloseShiftSheet(
          ref.context,
          sessionId: session.id,
          usersCount: session.users.length,
        ),
      ),
      const SizedBox(height: 8),
      EzyButton(
        label: 'Salir del turno',
        variant: EzyButtonVariant.outline,
        icon: Icons.logout_outlined,
        isLoading: state.isSubmitting,
        onPressed: () => _confirmLeave(ref, controller, session),
      ),
      const SizedBox(height: 8),
      EzyButton(
        label: 'Actualizar estado',
        variant: EzyButtonVariant.text,
        onPressed: controller.refresh,
      ),
    ];
  }

  /// Sin turno: apertura, unión/retome o aviso para abrir desde la web.
  List<Widget> _setupWidgets(WidgetRef ref, CashRegisterState state) {
    return <Widget>[
      if (state.canStartShift)
        StartShiftCard(
          registers: state.availableCashRegisters,
          bankAccounts: state.bankAccounts,
        ),
      if (state.canJoinShift) ...<Widget>[
        if (state.canStartShift) const SizedBox(height: 12),
        JoinableShiftsCard(sessions: state.joinableSessions),
      ],
      if (state.isBlocked) const ShiftUnavailable(),
    ];
  }

  Future<void> _confirmLeave(
    WidgetRef ref,
    CashRegisterController controller,
    ActiveCashSession session,
  ) async {
    final confirmed = await showEzyConfirmDialog(
      ref.context,
      title: 'Salir del turno',
      message:
          'Dejarás de cobrar en este dispositivo. La caja sigue abierta para '
          'los demás usuarios.',
      confirmLabel: 'Salir del turno',
    );

    if (confirmed) {
      await controller.leaveShift(session.id);
    }
  }
}

/// Saldos bancarios declarados al abrir el turno (snapshot congelado).
class _BankSnapshotCard extends StatelessWidget {
  const _BankSnapshotCard({required this.balances});

  final List<OpeningBankBalance> balances;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Saldos bancarios al abrir',
      child: Column(
        children: <Widget>[
          for (final balance in balances)
            SectionRow(
              label: balance.label,
              value: Money.format(balance.balance),
            ),
        ],
      ),
    );
  }
}
