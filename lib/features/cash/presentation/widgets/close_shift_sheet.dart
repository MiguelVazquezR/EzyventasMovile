import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/field_label.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/notice_banner.dart';
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
import '../../data/models/user_ref.dart';

/// Abre el corte de caja: el asistente (`resumen` → `aviso de usuarios` →
/// `arqueo`) que termina en la pantalla del corte.
///
/// Los pasos viven en la misma hoja y **nada se envía al servidor** hasta pulsar
/// `Finalizar turno`: descartar la hoja en cualquier paso cancela el corte. El
/// paso intermedio solo existe cuando hay más de un usuario en la sesión
/// ([usersCount] > 1); con uno se va derecho al arqueo.
///
/// Devuelve `true` cuando el turno se cerró y el cajero pulsó `Listo`; `null`
/// cuando la hoja se descartó sin cerrar.
Future<bool?> showCloseShiftSheet(
  BuildContext context, {
  required int sessionId,
  required int usersCount,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        _CloseShiftSheet(sessionId: sessionId, usersCount: usersCount),
  );
}

/// Pasos del asistente. El resultado no es un paso: lo dicta `lastClose` del
/// controlador (el `PUT` de cierre ya volvió).
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
  bool _hasCount = false;

  @override
  void dispose() {
    _cashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// Pasos que verá el cajero: el aviso de usuarios no existe con uno solo, así
  /// que la barra de progreso tampoco lo cuenta.
  List<String> get _stepLabels => widget.usersCount > 1
      ? const <String>['Resumen', 'Confirmación', 'Arqueo']
      : const <String>['Resumen', 'Arqueo'];

  int get _stepIndex => switch (_step) {
    _CloseStep.summary => 0,
    _CloseStep.confirm => 1,
    _CloseStep.count => _stepLabels.length - 1,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashRegisterControllerProvider);
    final result = state.lastClose;
    final done = result != null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      minChildSize: 0.50,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: <Widget>[
          EzySheetHeader(
            title: done ? 'Corte de caja' : _title,
            subtitle: done
                ? 'El corte quedó guardado en el servidor.'
                : _subtitle,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (!done && _step != _CloseStep.summary) ...<Widget>[
                  EzyIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Volver',
                    onTap: _backToSummary,
                  ),
                  const SizedBox(width: 8),
                ],
                EzyIconButton(
                  icon: Icons.close,
                  tooltip: 'Cerrar',
                  onTap: () => _closeSheet(done),
                ),
              ],
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          _StepTracker(labels: _stepLabels, index: done ? null : _stepIndex),
          const SizedBox(height: 16),
          if (result != null)
            _CloseResult(
              result: result,
              onDismiss: () {
                ref
                    .read(cashRegisterControllerProvider.notifier)
                    .consumeLastClose();
                // El pop lleva `true`: quien abrió la hoja refresca con eso.
                Navigator.of(context).pop(true);
              },
            )
          else
            ..._body(state),
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

  List<Widget> _body(CashRegisterState state) {
    final summary = ref.watch(cashSummaryProvider(widget.sessionId));

    return <Widget>[
      summary.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (error, stackTrace) => ErrorNotice(
          message: error is ApiException
              ? error.message
              : 'No se pudo leer el turno.',
          onRetry: () => ref.invalidate(cashSummaryProvider(widget.sessionId)),
        ),
        data: (data) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _stepWidgets(state, data),
        ),
      ),
      if (state.errorMessage != null) ...<Widget>[
        const SizedBox(height: 12),
        NoticeBanner(message: state.errorMessage!),
      ],
    ];
  }

  List<Widget> _stepWidgets(
    CashRegisterState state,
    CashSessionSummary summary,
  ) {
    final canFinish = _hasCount && !state.isSubmitting;

    return switch (_step) {
      _CloseStep.summary => <Widget>[
        _ShiftReview(summary: summary),
        const SizedBox(height: 20),
        _Pill3D(
          base: EzyColors.primary,
          child: EzyButton(
            label: 'Continuar',
            icon: Icons.arrow_forward_outlined,
            height: 52,
            onPressed: _continue,
          ),
        ),
      ],
      _CloseStep.confirm => <Widget>[
        _MultiUserNotice(
          users: summary.session.users,
          usersCount: widget.usersCount,
        ),
        const SizedBox(height: 20),
        _Pill3D(
          base: EzyColors.danger,
          child: EzyButton(
            label: 'Cerrar la caja de todos modos',
            variant: EzyButtonVariant.danger,
            height: 52,
            onPressed: _startCounting,
          ),
        ),
        const SizedBox(height: 4),
        EzyButton(
          label: 'Cancelar',
          variant: EzyButtonVariant.text,
          onPressed: _backToSummary,
        ),
      ],
      _CloseStep.count => <Widget>[
        _CashCountForm(
          summary: summary,
          controller: _cashController,
          notesController: _notesController,
          onCountedChanged: _onCounted,
          counted: _counted,
          hasInput: _hasCount,
        ),
        const SizedBox(height: 20),
        _Pill3D(
          base: EzyColors.danger,
          enabled: canFinish,
          child: EzyButton(
            label: 'Finalizar turno',
            variant: EzyButtonVariant.danger,
            height: 52,
            isLoading: state.isSubmitting,
            onPressed: canFinish ? _submit : null,
          ),
        ),
        const SizedBox(height: 4),
        EzyButton(
          label: 'Volver al resumen',
          variant: EzyButtonVariant.text,
          onPressed: _backToSummary,
        ),
      ],
    };
  }

  /// Captura del arqueo: mantiene la diferencia y el CTA al día mientras se
  /// escribe (el campo de notas no cambia nada del cuadre).
  void _onCounted(double value) {
    setState(() {
      _counted = value;
      // El cierre exige un monto: con el campo vacío (o con puros separadores,
      // `1,,2`) `toNullableDouble` devuelve `null` y el CTA queda apagado.
      _hasCount = Money.toNullableDouble(_cashController.text) != null;
    });
  }

  /// Pasa al arqueo; con más de un usuario se pide confirmación antes.
  void _continue() {
    if (widget.usersCount > 1) {
      setState(() => _step = _CloseStep.confirm);
      return;
    }

    _startCounting();
  }

  void _startCounting() {
    setState(() {
      _step = _CloseStep.count;
      _counted = 0;
      _hasCount = false;
      _cashController.text = '';
      _notesController.text = '';
    });
  }

  void _backToSummary() {
    setState(() => _step = _CloseStep.summary);
  }

  /// Salir con la X. Si el corte ya se guardó, la hoja sale como `true` (y el
  /// aviso del resultado se limpia) para que el turno se refresque igual que
  /// al pulsar `Listo`; si no, sale como `null` y no se toca nada.
  void _closeSheet(bool closed) {
    if (closed) {
      ref.read(cashRegisterControllerProvider.notifier).consumeLastClose();
      Navigator.of(context).pop(true);
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
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

/// Rastro del asistente: `PASO 2 DE 3 · ARQUEO` y una barra por paso, con la
/// rampa naranja de la marca en lo ya recorrido y el borde de la superficie en
/// lo que falta. En el corte cerrado no hay paso que marcar, así que se va.
class _StepTracker extends StatelessWidget {
  const _StepTracker({required this.labels, required this.index});

  /// Nombres de los pasos que verá el cajero en este turno.
  final List<String> labels;

  /// Paso actual (0-based); `null` cuando el corte ya se cerró.
  final int? index;

  @override
  Widget build(BuildContext context) {
    final current = index;
    if (current == null) {
      return const SizedBox.shrink();
    }

    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FieldLabel(
          'Paso ${current + 1} de ${labels.length} · ${labels[current]}',
          color: EzyColors.primary,
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            for (int i = 0; i < labels.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    // Paso actual más saturado; los ya recorridos, en el naranja
                    // suave de la rampa.
                    color: i > current ? surfaces.borderStrong : null,
                    gradient: i > current
                        ? null
                        : LinearGradient(
                            colors: i == current
                                ? const <Color>[
                                    EzyColors.primary400,
                                    EzyColors.primary600,
                                  ]
                                : const <Color>[
                                    EzyColors.primary300,
                                    EzyColors.primary400,
                                  ],
                          ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Botón con relieve 3D (estilo DiDi / Mercado Pago): por debajo asoma una copia
/// oscurecida del color de la acción y el botón se apoya encima.
///
/// La capa lleva `IgnorePointer`, así que el toque siempre lo recibe el botón de
/// arriba: el relieve es solo pintura (no hay áreas de toque duplicadas) y el
/// alto total suma los 4 px de la profundidad.
class _Pill3D extends StatelessWidget {
  const _Pill3D({required this.base, required this.child, this.enabled = true});

  /// Color pleno de la acción (naranja de marca o rojo de peligro).
  final Color base;

  final Widget child;

  /// Apagado, el relieve desaparece y el botón queda plano: se lee «hoy no se
  /// puede pulsar» sin necesidad de gris propio.
  final bool enabled;

  /// Grosor del relieve, en píxeles.
  static const double _depth = 4;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return child;
    }

    return Stack(
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          top: _depth,
          bottom: 0,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  EzyColors.black2.withValues(alpha: 0.35),
                  base,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: _depth),
          child: child,
        ),
      ],
    );
  }
}

/// Resumen del turno antes del arqueo (equivalente a la vista `initial` web).
///
/// Abre con el monto protagonista —el efectivo que debe haber en la caja— y
/// debajo las tarjetas de siempre: turno, efectivo, cobros por método y los
/// movimientos/cuentas que sí tengan datos.
class _ShiftReview extends StatelessWidget {
  const _ShiftReview({required this.summary});

  final CashSessionSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ExpectedCashCard(expected: summary.expectedTotal),
        const SizedBox(height: 12),
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
                SectionRow(label: 'Abrió', value: summary.session.opener!.name),
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

/// Monto protagonista del resumen: el efectivo que debe haber en la caja,
/// sobre el degradado naranja de la marca.
class _ExpectedCashCard extends StatelessWidget {
  const _ExpectedCashCard({required this.expected});

  final double expected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[EzyColors.primary, EzyColors.primary600],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: EzyColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: EzyColors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FieldLabel('Efectivo esperado', color: EzyColors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Money.format(expected),
            style: EzyTextStyles.moneyLarge.copyWith(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: EzyColors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lo que debe haber en la caja al contar el efectivo.',
            style: EzyTextStyles.caption.copyWith(color: EzyColors.primary50),
          ),
        ],
      ),
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

/// Paso intermedio cuando la caja la compartieron varios cajeros: quiénes están
/// y qué implica cerrarla. El texto del servidor/web se conserva literal.
class _MultiUserNotice extends StatelessWidget {
  const _MultiUserNotice({required this.users, required this.usersCount});

  final List<UserRef> users;
  final int usersCount;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final warnColor = StatusPalette.text(context, EzySeverity.warn);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: StatusPalette.soft(EzySeverity.warn),
              shape: BoxShape.circle,
              border: Border.all(color: StatusPalette.border(EzySeverity.warn)),
            ),
            child: Icon(Icons.groups_2_outlined, size: 34, color: warnColor),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Al cerrar, todos salen y la terminal queda libre.',
          textAlign: TextAlign.center,
          style: EzyTextStyles.bodyStrong.copyWith(color: surfaces.textPrimary),
        ),
        const SizedBox(height: 16),
        NoticeBanner(
          message:
              'Hay $usersCount usuarios en esta sesión; al cerrarla, '
              'todos saldrán de la caja.',
          tone: EzySeverity.warn,
        ),
        if (users.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          SectionCard(
            title: 'Cajeros en la sesión',
            child: Column(
              children: <Widget>[
                for (final user in users) _UserChip(user: user),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Fila de cajero con sus iniciales en el círculo del naranja de marca.
class _UserChip extends StatelessWidget {
  const _UserChip({required this.user});

  final UserRef user;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: EzyColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(user.name),
              style: EzyTextStyles.badge.copyWith(color: EzyColors.primary),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              user.name,
              style: EzyTextStyles.body.copyWith(color: surfaces.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// Dos iniciales del nombre (`María López` → `ML`) para el círculo.
  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }

    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

/// Arqueo: efectivo contado, diferencia en vivo, comparativo y notas.
class _CashCountForm extends StatelessWidget {
  const _CashCountForm({
    required this.summary,
    required this.controller,
    required this.notesController,
    required this.onCountedChanged,
    required this.counted,
    required this.hasInput,
  });

  final CashSessionSummary summary;
  final TextEditingController controller;
  final TextEditingController notesController;
  final ValueChanged<double> onCountedChanged;

  /// Último monto válido capturado (lo lleva el estado de la hoja).
  final double counted;

  /// `false` mientras el campo esté vacío: sin monto no hay comparación.
  final bool hasInput;

  @override
  Widget build(BuildContext context) {
    // Diferencia en vivo: contado − esperado.
    final difference = summary.differenceFor(hasInput ? counted : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          title: 'Efectivo contado',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              MoneyField(
                label: 'Efectivo físico contado',
                isRequired: true,
                emphasized: true,
                suffixText: 'MXN',
                controller: controller,
                onChanged: onCountedChanged,
              ),
              const SizedBox(height: 14),
              _DifferencePanel(difference: difference, hasInput: hasInput),
            ],
          ),
        ),
        const SizedBox(height: 12),
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

/// Diferencia del arqueo en vivo: ámbar si falta efectivo, azul si sobra y verde
/// si la caja cuadra; en gris mientras no haya monto capturado.
class _DifferencePanel extends StatelessWidget {
  const _DifferencePanel({required this.difference, required this.hasInput});

  final double difference;
  final bool hasInput;

  @override
  Widget build(BuildContext context) {
    final balanced = difference.abs() < 0.01;
    final severity = !hasInput
        ? EzySeverity.neutral
        : balanced
        ? EzySeverity.success
        : difference < 0
        ? EzySeverity.warn
        : EzySeverity.info;
    final color = StatusPalette.text(context, severity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StatusPalette.soft(severity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StatusPalette.border(severity)),
      ),
      child: Row(
        children: <Widget>[
          Icon(_icon(balanced), size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _headline(balanced),
                  style: EzyTextStyles.bodyStrong.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  _hint(balanced),
                  style: EzyTextStyles.caption.copyWith(color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusBadge(label: _badge(balanced), severity: severity),
        ],
      ),
    );
  }

  IconData _icon(bool balanced) {
    if (!hasInput) {
      return Icons.calculate_outlined;
    }
    if (balanced) {
      return Icons.check_circle_outline;
    }

    return difference < 0 ? Icons.trending_down : Icons.trending_up;
  }

  /// Titular del panel; el texto de siempre (`Sin diferencia.`,
  /// `Descuadre: …`) se conserva literal.
  String _headline(bool balanced) {
    if (!hasInput) {
      return 'Captura el efectivo contado';
    }

    return balanced
        ? 'Sin diferencia.'
        : 'Descuadre: ${Money.format(difference)}';
  }

  String _hint(bool balanced) {
    if (!hasInput) {
      return 'La comparación aparece al capturar el monto.';
    }
    if (balanced) {
      return 'La caja cuadra con el total esperado.';
    }

    return difference < 0
        ? 'Falta efectivo en la caja.'
        : 'Hay efectivo de más en la caja.';
  }

  String _badge(bool balanced) {
    if (!hasInput) {
      return 'En espera';
    }
    if (balanced) {
      return 'Exacto';
    }

    return difference < 0 ? 'Faltante' : 'Sobrante';
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
        _ClosedHero(difference: session.cashDifference),
        const SizedBox(height: 16),
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
        _Pill3D(
          base: EzyColors.primary,
          child: EzyButton(label: 'Listo', height: 52, onPressed: onDismiss),
        ),
      ],
    );
  }
}

/// Sello del cierre: el cuadre del corte con su diferencia, en el color del
/// resultado (verde si cuadró, ámbar si faltó, azul si sobró).
class _ClosedHero extends StatelessWidget {
  const _ClosedHero({required this.difference});

  final double difference;

  @override
  Widget build(BuildContext context) {
    final balanced = difference.abs() < 0.01;
    final severity = balanced
        ? EzySeverity.success
        : difference < 0
        ? EzySeverity.warn
        : EzySeverity.info;
    final color = StatusPalette.text(context, severity);

    return Column(
      children: <Widget>[
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: StatusPalette.soft(severity),
            shape: BoxShape.circle,
            border: Border.all(color: StatusPalette.border(severity)),
          ),
          child: Icon(
            balanced ? Icons.check_rounded : Icons.receipt_long_outlined,
            size: 34,
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        FieldLabel('Diferencia del corte'),
        const SizedBox(height: 4),
        Text(
          Money.format(difference),
          style: EzyTextStyles.moneyMedium.copyWith(
            color: context.surfaces.textPrimary,
          ),
        ),
      ],
    );
  }
}
