import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/field_label.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../application/cash_register_controller.dart';
import '../../data/models/bank_account.dart';
import '../../data/models/cash_register_ref.dart';
import '../../data/models/joinable_cash_session.dart';

/// Formulario de apertura de turno: terminal libre, fondo de efectivo y saldos
/// bancarios declarados (`POST /cash-register-sessions`).
class StartShiftCard extends ConsumerStatefulWidget {
  const StartShiftCard({
    super.key,
    required this.registers,
    required this.bankAccounts,
  });

  final List<CashRegisterRef> registers;
  final List<BankAccount> bankAccounts;

  @override
  ConsumerState<StartShiftCard> createState() => _StartShiftCardState();
}

class _StartShiftCardState extends ConsumerState<StartShiftCard> {
  final TextEditingController _cashController = TextEditingController(
    text: '0',
  );
  final Map<int, TextEditingController> _bankControllers =
      <int, TextEditingController>{};

  int? _registerId;
  double _openingCash = 0;

  @override
  void initState() {
    super.initState();
    _registerId = widget.registers.isEmpty ? null : widget.registers.first.id;
    _syncBankControllers();
  }

  /// Los terminales y las cuentas bancarias los refresca el controlador: si las
  /// listas cambian hay que seguir a los datos. Antes el desplegable se quedaba
  /// con un id que ya no existía (el `DropdownButtonFormField` truena cuando su
  /// valor no está en los `items`) y las cuentas nuevas se enviaban sin saldo
  /// declarado porque no tenían controlador.
  @override
  void didUpdateWidget(StartShiftCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.registers.any((register) => register.id == _registerId)) {
      _registerId = widget.registers.isEmpty ? null : widget.registers.first.id;
    }

    _syncBankControllers();
  }

  /// Crea el campo de cada cuenta bancaria y descarta las que desaparecieron.
  void _syncBankControllers() {
    final ids = <int>{for (final account in widget.bankAccounts) account.id};

    for (final account in widget.bankAccounts) {
      _bankControllers.putIfAbsent(
        account.id,
        () => TextEditingController(text: MoneyField.format(account.balance)),
      );
    }

    for (final id in _bankControllers.keys.toList(growable: false)) {
      if (!ids.contains(id)) {
        _bankControllers.remove(id)!.dispose();
      }
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    for (final controller in _bankControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashRegisterControllerProvider);
    final controller = ref.read(cashRegisterControllerProvider.notifier);
    final conflict = state.conflict;

    return SectionCard(
      title: 'Iniciar turno',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _TerminalSelector(
            registers: widget.registers,
            selectedId: _registerId,
            onChanged: (id) => setState(() => _registerId = id),
          ),
          const SizedBox(height: 16),
          MoneyField(
            label: 'Fondo de efectivo',
            isRequired: true,
            controller: _cashController,
            onChanged: (value) => _openingCash = value,
          ),
          if (widget.bankAccounts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const FieldLabel('Saldos bancarios declarados'),
            const SizedBox(height: 4),
            Text(
              'Edita el saldo si no coincide con el sistema. Las cuentas que no '
              'declares heredan el saldo del último corte.',
              style: EzyTextStyles.caption.copyWith(
                color: context.surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            for (final account in widget.bankAccounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MoneyField(
                  label: account.label,
                  controller: _bankControllers[account.id],
                ),
              ),
          ],
          if (conflict != null) ...<Widget>[
            NoticeBanner(
              message: state.errorMessage ?? '',
              tone: EzySeverity.warn,
              actionLabel: 'Unirme a esa sesión',
              onAction: () => controller.joinShift(conflict.sessionId),
            ),
            const SizedBox(height: 12),
          ] else if (state.errorMessage != null) ...<Widget>[
            NoticeBanner(message: state.errorMessage!),
            const SizedBox(height: 12),
          ],
          EzyButton(
            label: 'Iniciar turno',
            icon: Icons.lock_open_outlined,
            isLoading: state.isSubmitting,
            onPressed: _registerId == null ? null : () => _start(controller),
          ),
        ],
      ),
    );
  }

  void _start(CashRegisterController controller) {
    final registerId = _registerId;
    if (registerId == null) {
      return;
    }

    final balances = <int, double>{};
    _bankControllers.forEach((id, textController) {
      balances[id] = Money.parseInput(textController.text);
    });

    controller.startShift(
      cashRegisterId: registerId,
      openingCashBalance: _openingCash,
      declaredBankBalances: balances,
    );
  }
}

/// Selector de terminal libre.
class _TerminalSelector extends StatelessWidget {
  const _TerminalSelector({
    required this.registers,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CashRegisterRef> registers;
  final int? selectedId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const FieldLabel('Terminal', isRequired: true),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: selectedId,
          isExpanded: true,
          items: <DropdownMenuItem<int>>[
            for (final register in registers)
              DropdownMenuItem<int>(
                value: register.id,
                child: Text(
                  register.name,
                  style: EzyTextStyles.fieldValue.copyWith(
                    color: surfaces.textPrimary,
                  ),
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
          decoration: InputDecoration(
            hintText: 'Seleccionar terminal libre…',
            hintStyle: EzyTextStyles.fieldValue.copyWith(
              color: surfaces.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Turnos abiertos de la sucursal: unirse al actual o retomarlo sin contar el
/// fondo otra vez (`/join` y `/rejoin-or-start`).
class JoinableShiftsCard extends ConsumerWidget {
  const JoinableShiftsCard({super.key, required this.sessions});

  final List<JoinableCashSession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final state = ref.watch(cashRegisterControllerProvider);
    final controller = ref.read(cashRegisterControllerProvider.notifier);

    return SectionCard(
      title: 'Turnos abiertos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final session in sessions)
            _JoinableShiftTile(
              session: session,
              isSubmitting: state.isSubmitting,
              onJoin: () => controller.joinShift(session.id),
              onRejoin: session.opener == null || session.cashRegister == null
                  ? null
                  : () => controller.rejoinShift(
                      cashRegisterId: session.cashRegister!.id,
                      originalOpenerId: session.opener!.id,
                    ),
            ),
          if (state.errorMessage != null)
            NoticeBanner(message: state.errorMessage!)
          else
            Text(
              'Retomar continúa el turno con el fondo y los saldos del último '
              'corte, sin volver a capturarlos.',
              style: EzyTextStyles.caption.copyWith(color: surfaces.textMuted),
            ),
        ],
      ),
    );
  }
}

class _JoinableShiftTile extends StatelessWidget {
  const _JoinableShiftTile({
    required this.session,
    required this.isSubmitting,
    required this.onJoin,
    this.onRejoin,
  });

  final JoinableCashSession session;
  final bool isSubmitting;
  final VoidCallback onJoin;
  final VoidCallback? onRejoin;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        inner: true,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              session.cashRegister?.name ?? 'Terminal',
              style: EzyTextStyles.bodyStrong.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              <String>[
                'Abierto ${AppFormatters.dateTime(session.openedAt)}',
                if (session.opener != null) 'por ${session.opener!.name}',
              ].join(' · '),
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: EzyButton(
                    label: 'Unirme',
                    icon: Icons.login_outlined,
                    variant: EzyButtonVariant.outline,
                    isLoading: isSubmitting,
                    onPressed: onJoin,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: EzyButton(
                    label: 'Retomar',
                    icon: Icons.restart_alt_outlined,
                    variant: EzyButtonVariant.text,
                    onPressed: isSubmitting ? null : onRejoin,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sin terminales libres ni turnos abiertos: hay que abrir caja desde la web.
class ShiftUnavailable extends ConsumerWidget {
  const ShiftUnavailable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cashRegisterControllerProvider);
    final controller = ref.read(cashRegisterControllerProvider.notifier);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Pide que abran caja desde la versión web.',
            style: EzyTextStyles.bodyStrong.copyWith(
              color: context.surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay terminales libres ni turnos abiertos en esta sucursal. '
            'Cuando alguien abra caja podrás unirte desde aquí.',
            style: EzyTextStyles.body.copyWith(
              color: context.surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null)
            NoticeBanner(
              message: state.errorMessage!,
              tone: EzySeverity.info,
              actionLabel: 'Actualizar estado',
              onAction: controller.refresh,
            )
          else
            EzyButton(
              label: 'Actualizar estado',
              variant: EzyButtonVariant.outline,
              icon: Icons.refresh,
              onPressed: controller.refresh,
            ),
        ],
      ),
    );
  }
}
