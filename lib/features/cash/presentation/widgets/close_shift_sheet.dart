import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../printing/application/printing_providers.dart';
import '../../../printing/application/printer_controller.dart';
import '../../../printing/presentation/cash_cut_actions.dart';
import '../../application/cash_register_controller.dart';
import '../../data/models/cash_movement.dart';
import '../../data/models/cash_session_summary.dart';
import '../../data/models/closed_cash_session.dart';
import '../../data/models/session_bank_account.dart';

/// Abre el corte de caja (3 pasos: resumen → aviso de usuarios → arqueo).
Future<void> showCloseShiftSheet(
  BuildContext context, {
  required int sessionId,
  required int usersCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _CloseShiftSheet(
      sessionId: sessionId,
      usersCount: usersCount,
    ),
  );
}

enum _CloseStep { summary, confirm, count }

class _CloseShiftSheet extends ConsumerStatefulWidget {
  const _CloseShiftSheet({required this.sessionId, required this.usersCount});

  final int sessionId;
  final int usersCount;

  @override
  ConsumerState<_CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends ConsumerState<_CloseShiftSheet> {
  final TextEditingController _cashController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  _CloseStep _step = _CloseStep.summary;
  double _counted = 0;
  bool _hasInput = false;

  @override
  void dispose() {
    _cashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final state = ref.watch(cashRegisterControllerProvider);

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
            _title,
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _subtitle,
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (state.lastClose != null)
            _CloseResult(
              result: state.lastClose!,
              onDismiss: () {
                ref
                    .read(cashRegisterControllerProvider.notifier)
                    .consumeLastClose();
                Navigator.of(context).pop();
              },
            )
          else
            ..._body(state, surfaces),
        ],
      ),
    );
  }

  String get _title => switch (_step) {
    _CloseStep.summary => 'Corte de caja',
    _CloseStep.confirm => 'Confirmar cierre',
    _CloseStep.count => 'Arqueo de efectivo',
  };

  String get _subtitle => switch (_step) {
    _CloseStep.summary => 'Revisa el turno antes de capturar el efectivo.',
    _CloseStep.confirm => 'Este turno lo están usando varios usuarios.',
    _CloseStep.count => 'Cuenta el efectivo físico de la caja.',
  };

  List<Widget> _body(CashRegisterState state, EzySurfaces surfaces) {
    final summary = ref.watch(cashSummaryProvider(widget.sessionId));

    return <Widget>[
      summary.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, stackTrace) => ErrorNotice(
          message:
              error is ApiException ? error.message : 'No se pudo leer el turno.',
          onRetry: () => ref.invalidate(cashSummaryProvider(widget.sessionId)),
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _stepWidgets(data),
        ),
      ),
      if (state.errorMessage != null) ...<Widget>[
        const SizedBox(height: 12),
        NoticeBanner(message: state.errorMessage!),
      ],
    ];
  }

  List<Widget> _stepWidgets(CashSessionSummary summary) {
    return switch (_step) {
      _CloseStep.summary => <Widget>[
        _ShiftReview(summary: summary),
        const SizedBox(height: 16),
        EzyButton(
          label: 'Continuar',
          icon: Icons.arrow_forward_outlined,
          onPressed: () => _continue(summary),
        ),
      ],
      _CloseStep.confirm => <Widget>[
        NoticeBanner(
          message:
              'Hay ${widget.usersCount} usuarios en esta sesión; al cerrarla, '
              'todos saldrán de la caja.',
          tone: EzySeverity.warn,
        ),
        const SizedBox(height: 16),
        EzyButton(
          label: 'Cerrar la caja de todos modos',
          variant: EzyButtonVariant.danger,
          onPressed: () => _startCounting(summary),
        ),
        const SizedBox(height: 8),
        EzyButton(
          label: 'Cancelar',
          variant: EzyButtonVariant.text,
          onPressed: () => setState(() => _step = _CloseStep.summary),
        ),
      ],
      _CloseStep.count => <Widget>[
        _CashCountForm(
          summary: summary,
          controller: _cashController,
          notesController: _notesController,
          onCountedChanged: (value) => setState(() {
            _counted = value;
            _hasInput = _cashController.text.trim().isNotEmpty;
          }),
          hasInput: _hasInput,
        ),
        const SizedBox(height: 16),
        EzyButton(
          label: 'Finalizar turno',
          variant: EzyButtonVariant.danger,
          isLoading: ref.watch(cashRegisterControllerProvider).isSubmitting,
          onPressed: _hasInput ? () => _submit(summary) : null,
        ),
        const SizedBox(height: 8),
        EzyButton(
          label: 'Volver al resumen',
          variant: EzyButtonVariant.text,
          onPressed: () => setState(() => _step = _CloseStep.summary),
        ),
      ],
    };
  }

  /// Pasa al arqueo (o pide confirmación si hay más de un usuario).
  void _continue(CashSessionSummary summary) {
    if (widget.usersCount > 1) {
      setState(() => _step = _CloseStep.confirm);
      return;
    }

    _startCounting(summary);
  }

  void _startCounting(CashSessionSummary summary) {
    setState(() {
      _step = _CloseStep.count;
      _counted = 0;
      _hasInput = false;
      _cashController.text = '';
      _notesController.text = '';
    });
  }

  Future<void> _submit(CashSessionSummary summary) async {
    final notes = _notesController.text.trim();

    final result = await ref
        .read(cashRegisterControllerProvider.notifier)
        .closeShift(
          sessionId: widget.sessionId,
          closingCashBalance: _counted,
          notes: notes.isEmpty ? null : notes,
        );

    if (result != null) {
      ref.invalidate(cashSummaryProvider(widget.sessionId));
    }
  }
}

/// Resumen del turno antes del arqueo (equivalente a la vista `initial` web).
class _ShiftReview extends StatelessWidget {
  const _ShiftReview({required this.summary});

  final CashSessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: 'Turno',
          trailing: const StatusBadge(
            label: 'Abierta',
            severity: EzySeverity.success,
            showDot: true,
          ),
          child: Column(
            children: <Widget>[
              SectionRow(
                label: 'Terminal',
                value: summary.session.cashRegisterName,
              ),
              SectionRow(
                label: 'Abierto',
                value: AppFormatters.dateTime(summary.session.openedAt),
              ),
              if (summary.session.opener != null)
                SectionRow(
                  label: 'Abrió',
                  value: summary.session.opener!.name,
                ),
              SectionRow(
                label: 'Usuarios en la sesión',
                value: '${summary.session.users.length}',
              ),
              SectionRow(
                label: 'Operaciones',
                value:
                    '${summary.transactionsCount} ventas · '
                    '${summary.paymentsCount} pagos',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Efectivo',
          child: Column(
            children: <Widget>[
              SectionRow(
                label: 'Fondo inicial',
                value: Money.format(summary.opening),
              ),
              SectionRow(
                label: 'Ventas en efectivo',
                value: Money.format(summary.cashSales),
              ),
              if (summary.inflows != 0)
                SectionRow(
                  label: 'Ingresos',
                  value: Money.format(summary.inflows),
                ),
              if (summary.outflows != 0)
                SectionRow(
                  label: 'Egresos',
                  value: Money.format(summary.outflows),
                ),
              const Divider(height: 24),
              SectionRow(
                label: 'Total esperado',
                value: Money.format(summary.expectedTotal),
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Cobros por método',
          child: Column(
            children: <Widget>[
              SectionRow(
                label: 'Efectivo',
                value: Money.format(summary.payments.cash),
              ),
              SectionRow(
                label: 'Tarjeta',
                value: Money.format(summary.payments.card),
              ),
              SectionRow(
                label: 'Transferencia',
                value: Money.format(summary.payments.transfer),
              ),
              SectionRow(
                label: 'Saldo a favor',
                value: Money.format(summary.payments.balance),
              ),
              const Divider(height: 24),
              SectionRow(
                label: 'Total cobrado',
                value: Money.format(summary.payments.total),
                emphasized: true,
              ),
            ],
          ),
        ),
        if (summary.hasMovements) ...<Widget>[
          const SizedBox(height: 12),
          _MovementsCard(movements: summary.cashMovements),
        ],
        if (summary.bankAccounts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _BankAccountsCard(accounts: summary.bankAccounts),
        ],
      ],
    );
  }
}
/// Movimientos manuales de efectivo del turno (solo lectura en la app).
class _MovementsCard extends StatelessWidget {
  const _MovementsCard({required this.movements});

  final List<CashMovement> movements;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Movimientos de efectivo',
      child: Column(
        children: <Widget>[
          for (final movement in movements)
            SectionRow(
              label: <String>[
                movement.label,
                if (movement.description != null &&
                    movement.description!.isNotEmpty)
                  movement.description!,
              ].join(' · '),
              value: Money.format(
                movement.isInflow ? movement.amount : -movement.amount,
              ),
            ),
        ],
      ),
    );
  }
}

/// Arqueo bancario del turno: saldo inicial, movimientos y saldo final.
class _BankAccountsCard extends StatelessWidget {
  const _BankAccountsCard({required this.accounts});

  final List<SessionBankAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Cuentas bancarias',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final account in accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    account.label,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SectionRow(
                    label: 'Saldo inicial',
                    value: Money.format(account.initialBalance),
                  ),
                  if (account.received != 0)
                    SectionRow(
                      label: 'Recibido',
                      value: Money.format(account.received),
                    ),
                  if (account.spent != 0)
                    SectionRow(
                      label: 'Gastado',
                      value: Money.format(account.spent),
                    ),
                  if (account.transferredIn != 0)
                    SectionRow(
                      label: 'Transferencias recibidas',
                      value: Money.format(account.transferredIn),
                    ),
                  if (account.transferredOut != 0)
                    SectionRow(
                      label: 'Transferencias enviadas',
                      value: Money.format(account.transferredOut),
                    ),
                  SectionRow(
                    label: 'Saldo final',
                    value: Money.format(account.finalBalance),
                    emphasized: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


/// Arqueo: efectivo contado, diferencia en vivo y notas.
class _CashCountForm extends StatelessWidget {
  const _CashCountForm({
    required this.summary,
    required this.controller,
    required this.notesController,
    required this.onCountedChanged,
    required this.hasInput,
  });

  final CashSessionSummary summary;
  final TextEditingController controller;
  final TextEditingController notesController;
  final ValueChanged<double> onCountedChanged;
  final bool hasInput;

  @override
  Widget build(BuildContext context) {
    // Diferencia en vivo: contado − esperado (verde sin diferencia).
    final counted = hasInput ? Money.parseInput(controller.text) : 0.0;
    final difference = summary.differenceFor(counted);
    final balanced = difference.abs() < 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        MoneyField(
          label: 'Efectivo físico contado',
          isRequired: true,
          emphasized: true,
          controller: controller,
          onChanged: onCountedChanged,
        ),
        const SizedBox(height: 12),
        NoticeBanner(
          message: balanced
              ? 'Sin diferencia.'
              : 'Descuadre: ${Money.format(difference)}',
          tone: balanced ? EzySeverity.success : EzySeverity.warn,
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Comparativo',
          child: Column(
            children: <Widget>[
              SectionRow(
                label: 'Total esperado',
                value: Money.format(summary.expectedTotal),
              ),
              SectionRow(
                label: 'Contado',
                value: hasInput ? Money.format(counted) : '—',
              ),
              const Divider(height: 24),
              SectionRow(
                label: 'Diferencia',
                value: hasInput ? Money.format(difference) : '—',
                emphasized: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EzyTextField(
          label: 'Notas de arqueo',
          hint: 'Opcional',
          maxLines: 3,
          controller: notesController,
          maxLength: 1000,
        ),
      ],
    );
  }
}

/// Resultado del corte: esperado, contado y diferencia + impresión y WhatsApp.
class _CloseResult extends ConsumerWidget {
  const _CloseResult({required this.result, required this.onDismiss});

  final CloseCashSessionResult result;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = result.session;
    final printer = ref.watch(printerControllerProvider);
    final job = ref.watch(printJobProvider);
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: 'Turno cerrado',
          trailing: const StatusBadge(
            label: 'Cerrada',
            severity: EzySeverity.neutral,
          ),
          child: Column(
            children: <Widget>[
              SectionRow(
                label: 'Cerrado',
                value: AppFormatters.dateTime(session.closedAt),
              ),
              SectionRow(
                label: 'Total esperado',
                value: Money.format(session.calculatedCashTotal),
              ),
              SectionRow(
                label: 'Efectivo contado',
                value: Money.format(session.closingCashBalance),
              ),
              const Divider(height: 24),
              SectionRow(
                label: 'Diferencia',
                value: Money.format(session.cashDifference),
                emphasized: true,
              ),
            ],
          ),
        ),
        if (result.message.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          NoticeBanner(
            message: result.message,
            tone: EzySeverity.success,
            icon: Icons.check_circle_outline,
          ),
        ],
        if (job.errorMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          NoticeBanner(
            message: job.errorMessage!,
            actionLabel: 'Ocultar',
            onAction: ref.read(printJobProvider.notifier).consumeError,
          ),
        ],
        if (job.warningMessage != null) ...<Widget>[
          const SizedBox(height: 12),
          NoticeBanner(
            message: job.warningMessage!,
            tone: EzySeverity.warn,
            actionLabel: 'Ocultar',
            onAction: ref.read(printJobProvider.notifier).consumeWarning,
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: 'Impresión del corte',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                printer.statusLabel,
                style: EzyTextStyles.body.copyWith(
                  color: surfaces.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'El corte lo arma el servidor y el teléfono solo lo imprime: '
                'puedes reimprimirlo cuando quieras.',
                style: EzyTextStyles.caption.copyWith(
                  color: surfaces.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              EzyButton(
                label: 'Imprimir corte',
                icon: Icons.print_outlined,
                isLoading: job.isSubmitting || job.isFetchingCut,
                onPressed: printer.isAdapterOn && !job.isBusy
                    ? () => printCashCut(context, ref, sessionId: session.id)
                    : null,
              ),
              const SizedBox(height: 8),
              EzyButton(
                label: 'Enviar corte por WhatsApp',
                icon: Icons.chat_outlined,
                variant: EzyButtonVariant.outline,
                onPressed: job.isBusy
                    ? null
                    : () => sendCashCutByWhatsApp(
                        context,
                        ref,
                        sessionId: session.id,
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EzyButton(label: 'Listo', onPressed: onDismiss),
      ],
    );
  }
}

