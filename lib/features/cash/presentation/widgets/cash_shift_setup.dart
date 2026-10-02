import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/field_label.dart';
import '../../../../core/widgets/money_field.dart';
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
    final surfaces = context.surfaces;
    final state = ref.watch(cashRegisterControllerProvider);
    final controller = ref.read(cashRegisterControllerProvider.notifier);
    final conflict = state.conflict;
    final canSubmit = _registerId != null && !state.isSubmitting;

    return _FlatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Expanded(child: _CardTitle('Iniciar turno')),
              _SoftChip(label: 'Apertura', color: EzyColors.primary),
            ],
          ),
          const SizedBox(height: 14),
          _TerminalSelector(
            registers: widget.registers,
            selectedId: _registerId,
            onChanged: (id) => setState(() => _registerId = id),
          ),
          const SizedBox(height: 14),
          MoneyField(
            label: 'Fondo inicial de efectivo',
            isRequired: true,
            controller: _cashController,
            fieldHeight: 46,
            borderRadius: 12,
            fillColor: surfaces.panelInner,
            borderColor: surfaces.border,
            prefixColor: EzyColors.primary,
            prefixIconSize: 14,
            suffixText: 'MXN',
            onChanged: (value) => setState(() => _openingCash = value),
          ),
          if (widget.bankAccounts.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            Divider(height: 1, color: surfaces.border),
            const SizedBox(height: 14),
            const FieldLabel(
              'Saldos bancarios declarados',
              requiredMarkColor: EzyColors.danger,
            ),
            const SizedBox(height: 4),
            Text(
              'Edita el saldo si no coincide con el sistema. Las cuentas no '
              'declaradas heredan el último corte.',
              style: EzyTextStyles.caption.copyWith(
                fontSize: 11,
                color: surfaces.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            for (final account in widget.bankAccounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BankAccountPanel(
                  account: account,
                  controller: _bankControllers[account.id],
                ),
              ),
          ],
          if (conflict != null) ...<Widget>[
            const SizedBox(height: 4),
            _ConflictBanner(
              conflict: conflict,
              message: state.errorMessage,
              isSubmitting: state.isSubmitting,
              onJoin: () => controller.joinShift(conflict.sessionId),
            ),
          ],
          const SizedBox(height: 16),
          _Pill3dButton(
            label: 'Iniciar turno',
            icon: Icons.lock_open_outlined,
            isLoading: state.isSubmitting,
            onPressed: canSubmit ? () => _start(controller) : null,
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
        const FieldLabel(
          'Terminal de venta',
          isRequired: true,
          requiredMarkColor: EzyColors.danger,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 46,
          child: DropdownButtonFormField<int>(
            initialValue: selectedId,
            isExpanded: true,
            isDense: true,
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
              filled: true,
              fillColor: surfaces.panelInner,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              prefixIcon: const Icon(
                Icons.point_of_sale_outlined,
                size: 18,
                color: EzyColors.primary,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 36),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: surfaces.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: surfaces.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: EzyColors.primary,
                  width: 1.4,
                ),
              ),
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

    return _FlatCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _CardTitle('Turnos abiertos')),
              _SoftChip(
                label: sessions.length == 1
                    ? '1 disponible'
                    : '${sessions.length} disponibles',
                color: EzyColors.info,
              ),
            ],
          ),
          const SizedBox(height: 12),
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
          Text(
            'Retomar continúa con el fondo y los saldos declarados en el último '
            'corte sin volver a contarlos.',
            style: EzyTextStyles.caption.copyWith(
              fontSize: 11,
              color: surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 4),
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
      padding: const EdgeInsets.only(bottom: 10),
      // Panel interno del sistema: `panelInner`, radio 16 y borde de 1 px desde
      // `SectionCard` (antes era un `Container` pintado a mano).
      child: SectionCard(
        inner: true,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const _StatusDot(color: EzyColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.cashRegister?.name ?? 'Terminal',
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              <String>[
                'Abierto ${AppFormatters.dateTime(session.openedAt)}',
                if (session.opener != null) 'por ${session.opener!.name}',
              ].join(' · '),
              style: EzyTextStyles.secondary.copyWith(
                fontSize: 11.5,
                color: surfaces.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: surfaces.border),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: isSubmitting ? null : onRejoin,
                      icon: const Icon(Icons.replay_rounded, size: 15),
                      label: const Text('Retomar'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        foregroundColor: EzyColors.primary,
                        textStyle: EzyTextStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: isSubmitting ? null : onJoin,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: surfaces.textPrimary,
                    side: BorderSide(color: surfaces.borderStrong),
                    shape: const StadiumBorder(),
                    textStyle: EzyTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Unirme'),
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
    final surfaces = context.surfaces;
    final controller = ref.read(cashRegisterControllerProvider.notifier);

    return _FlatCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _CardTitle('Sin cajas disponibles'),
          const SizedBox(height: 8),
          Text(
            'Pide que abran una terminal desde la plataforma web.',
            style: EzyTextStyles.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No hay terminales libres ni turnos abiertos en esta sucursal. '
            'Cuando alguien abra caja podrás unirte desde aquí.',
            style: EzyTextStyles.caption.copyWith(
              fontSize: 11.5,
              color: surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: controller.refresh,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Actualizar estado de cajas'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                foregroundColor: EzyColors.primary,
                textStyle: EzyTextStyles.caption.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card plana del rediseño: panel con borde de 1 px, radio 16 y **sin sombra**.
class _FlatCard extends StatelessWidget {
  const _FlatCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      decoration: BoxDecoration(
        color: surfaces.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
        boxShadow: null,
      ),
      padding: padding,
      child: child,
    );
  }
}

/// Título de card del rediseño: 11 px, MAYÚSCULAS, `w800`.
class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: EzyTextStyles.cardTitle.copyWith(
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w800,
        color: context.surfaces.textPrimary,
      ),
    );
  }
}

/// Chip pastilla con el tinte suave (12 %) y el borde (30 %) de un color.
class _SoftChip extends StatelessWidget {
  const _SoftChip({
    required this.label,
    required this.color,
    this.fontSize = 10.5,
  });

  final String label;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: EzyTextStyles.badge.copyWith(
          fontSize: fontSize,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Punto de estado de una sesión abierta: **estático**.
///
/// El tinte verde basta para leerse como «abierto»; animarlo en bucle dejaría
/// sin terminar a `pumpAndSettle` en las pruebas de la pestaña.
class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// CTA de marca: pastilla de 48 px con el relieve 3D (degradado, bisel y doble
/// sombra). Deshabilitado queda al 45 % de opacidad, sin relieve.
class _Pill3dButton extends StatefulWidget {
  const _Pill3dButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  @override
  State<_Pill3dButton> createState() => _Pill3dButtonState();
}

class _Pill3dButtonState extends State<_Pill3dButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final enabled = widget.onPressed != null && !widget.isLoading;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: Opacity(
        opacity: enabled || widget.isLoading ? 1 : 0.45,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          height: 48,
          transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Color(0xFFFB9E2E),
                      Color(0xFFF68C0F),
                      Color(0xFFC95B00),
                    ],
                    stops: <double>[0.0, 0.42, 1.0],
                  )
                : null,
            color: enabled ? null : surfaces.panelInner,
            borderRadius: BorderRadius.circular(999),
            boxShadow: enabled && !_pressed
                ? const <BoxShadow>[
                    BoxShadow(color: Color(0xFF853700), offset: Offset(0, 3)),
                    BoxShadow(
                      color: Color(0x66F68C0F),
                      offset: Offset(0, 6),
                      blurRadius: 18,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            // Bisel en una caja interior **sin radio**: un `Border` con lados de
            // distinto color junto a un `borderRadius` dispara la aserción de
            // Flutter y el contenido dejaría de pintarse.
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: enabled
                    ? const Border(
                        top: BorderSide(color: Color(0x6BFFFFFF)),
                        bottom: BorderSide(color: Color(0xFF944000), width: 2),
                      )
                    : null,
              ),
              child: Center(child: _content(enabled, surfaces)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(bool enabled, EzySurfaces surfaces) {
    final color = enabled ? EzyColors.white : surfaces.textMuted;

    if (widget.isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: EzyColors.white,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          Icon(
            widget.icon,
            size: 18,
            color: color,
            shadows: const <Shadow>[
              Shadow(
                color: Colors.black38,
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: EzyTextStyles.button.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: const <Shadow>[
              Shadow(
                color: Colors.black38,
                offset: Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cuenta bancaria declarada en la apertura: sub-panel con el nombre, el banco y
/// su campo de saldo.
class _BankAccountPanel extends StatelessWidget {
  const _BankAccountPanel({required this.account, this.controller});

  final BankAccount account;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final bankName = account.bankName;
    final title = (account.accountName?.isNotEmpty ?? false)
        ? account.accountName!
        : account.label;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 12,
                    color: surfaces.textPrimary,
                  ),
                ),
              ),
              if (bankName != null && bankName.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                _SoftChip(label: bankName, color: EzyColors.info, fontSize: 10),
              ],
            ],
          ),
          const SizedBox(height: 10),
          MoneyField(
            label: 'Saldo declarado',
            controller: controller,
            fieldHeight: 46,
            borderRadius: 12,
            fillColor: surfaces.panel,
            borderColor: surfaces.borderStrong,
            prefixColor: EzyColors.primary,
            prefixIconSize: 14,
          ),
        ],
      ),
    );
  }
}

/// Terminal ocupada por otro usuario (`409 cash_register_in_use`): se anuncia el
/// aviso del servidor y se ofrece unirse a esa sesión.
class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({
    required this.conflict,
    required this.message,
    required this.isSubmitting,
    required this.onJoin,
  });

  final CashRegisterConflict conflict;
  final String? message;
  final bool isSubmitting;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, EzySeverity.warn);
    final text = message;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.warn),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StatusPalette.border(EzySeverity.warn)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  (text == null || text.isEmpty) ? conflict.label : text,
                  style: EzyTextStyles.body.copyWith(color: color),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: isSubmitting ? null : onJoin,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    foregroundColor: color,
                    side: BorderSide(
                      color: StatusPalette.border(EzySeverity.warn),
                    ),
                    shape: const StadiumBorder(),
                    textStyle: EzyTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Unirme a esa sesión'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
