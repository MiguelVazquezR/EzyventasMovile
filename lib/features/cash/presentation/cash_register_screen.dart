import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/ezy_dialog.dart';
import '../../../core/widgets/notice_banner.dart';
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
    final surfaces = context.surfaces;
    final state = ref.watch(cashRegisterControllerProvider);
    final controller = ref.read(cashRegisterControllerProvider.notifier);
    final session = state.activeSession;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: surfaces.panel,
                border: Border(bottom: BorderSide(color: surfaces.border)),
              ),
              child: AppScreenHeader(
                title: 'Caja',
                subtitle: session == null
                    ? 'Sin turno abierto'
                    : 'Turno abierto en ${session.cashRegisterName}',
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: <Widget>[
                    ..._notices(state, controller),
                    if (session != null)
                      ..._shiftWidgets(ref, session)
                    else
                      ..._setupWidgets(state),
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

  /// Zona de avisos superiores: éxito del controlador y error del servidor.
  List<Widget> _notices(
    CashRegisterState state,
    CashRegisterController controller,
  ) {
    return <Widget>[
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
      // Con una terminal en conflicto el aviso vive dentro de la tarjeta de
      // apertura («Unirme»), así que aquí no se duplica.
      if (state.errorMessage != null && state.conflict == null) ...<Widget>[
        NoticeBanner(
          message: state.errorMessage!,
          tone: EzySeverity.danger,
          actionLabel: 'Ocultar',
          onAction: controller.consumeError,
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  /// Turno abierto: resumen, cobros, snapshot bancario, corte y salida.
  List<Widget> _shiftWidgets(WidgetRef ref, ActiveCashSession session) {
    final surfaces = ref.context.surfaces;
    final state = ref.watch(cashRegisterControllerProvider);
    final controller = ref.read(cashRegisterControllerProvider.notifier);

    return <Widget>[
      _FlatCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Expanded(child: _CardTitle('Turno actual')),
                _OpenStatusPill(),
              ],
            ),
            const SizedBox(height: 14),
            _DataRow(label: 'Terminal', value: session.cashRegisterName),
            _DataRow(
              label: 'Apertura',
              value: 'Hoy · ${AppFormatters.time(session.openedAt)} hrs',
            ),
            if (session.opener != null)
              _DataRow(label: 'Abrió', value: session.opener!.name),
            _DataRow(
              label: 'Fondo inicial',
              value: Money.formatWithCurrency(session.openingCashBalance),
              valueColor: EzyColors.primary,
              bold: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Usuarios en la sesión',
                    style: EzyTextStyles.body.copyWith(
                      color: surfaces.textSecondary,
                    ),
                  ),
                ),
                _SoftChip(
                  label: '${session.users.length} usuarios',
                  color: EzyColors.info,
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _FlatCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Expanded(child: _CardTitle('Cobros del turno')),
                _SoftChip(
                  label: 'En tiempo real',
                  color: EzyColors.primary,
                  fontSize: 10,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _MethodRow(
              icon: '💵',
              label: 'Efectivo',
              value: Money.format(session.totals.cash),
            ),
            _MethodRow(
              icon: '💳',
              label: 'Tarjeta',
              value: Money.format(session.totals.card),
            ),
            _MethodRow(
              icon: '⚡',
              label: 'Transferencia (SPEI)',
              value: Money.format(session.totals.transfer),
            ),
            _MethodRow(
              icon: '🏷️',
              label: 'Saldo a favor usado',
              value: '-${Money.format(session.totals.balance)}',
              valueColor: EzyColors.success,
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: surfaces.borderStrong),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'TOTAL COBRADO',
                        style: EzyTextStyles.badge.copyWith(
                          fontSize: 12,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w900,
                          color: surfaces.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Suma bruta del turno',
                        style: EzyTextStyles.caption.copyWith(
                          fontSize: 10,
                          color: surfaces.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  Money.format(session.totals.total),
                  style: EzyTextStyles.moneyMedium.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: EzyColors.primary,
                  ),
                ),
              ],
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
          title: 'Sesión multi-usuario',
          message:
              'Hay ${session.users.length} usuarios en esta sesión; al cerrarla, '
              'todos saldrán de la caja.',
          tone: EzySeverity.warn,
        ),
      ],
      const SizedBox(height: 16),
      _CloseShiftCta(
        isLoading: state.isSubmitting,
        onPressed: () async {
          // La hoja devuelve `true` cuando el cierre viajó al servidor y el
          // cajero pulsó `Listo`: se refresca el turno para soltar la pantalla
          // en cuanto el estado del servidor lo confirme.
          final closed = await showCloseShiftSheet(
            ref.context,
            sessionId: session.id,
            usersCount: session.users.length,
          );
          if (closed == true) {
            controller.refresh();
          }
        },
      ),
      const SizedBox(height: 10),
      EzyButton(
        label: 'Salir del turno',
        variant: EzyButtonVariant.outline,
        icon: Icons.logout_outlined,
        height: 44,
        isLoading: state.isSubmitting,
        onPressed: () => _confirmLeave(ref, controller, session),
      ),
      const SizedBox(height: 4),
      EzyButton(
        label: 'Actualizar estado',
        variant: EzyButtonVariant.text,
        onPressed: controller.refresh,
      ),
    ];
  }

  /// Sin turno: apertura, unión/retome o aviso para abrir desde la web.
  List<Widget> _setupWidgets(CashRegisterState state) {
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
    // El diálogo del sistema (§4): mismo panel y mismos botones que el resto de
    // la app, en vez de un `Dialog` copiado a mano.
    final confirmed = await showEzyConfirmDialog(
      ref.context,
      title: 'Salir del turno',
      message:
          'Dejarás de cobrar en este dispositivo. La caja sigue abierta para '
          'los demás usuarios.',
      confirmLabel: 'Salir del turno',
      isDestructive: true,
    );

    if (confirmed) {
      await controller.leaveShift(session.id);
    }
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

/// Badge «ABIERTA» con punto pulsante verde.
class _OpenStatusPill extends StatelessWidget {
  const _OpenStatusPill();

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, EzySeverity.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.success),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(EzySeverity.success)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PulsingDot(color: color),
          const SizedBox(width: 6),
          Text(
            'ABIERTA',
            style: EzyTextStyles.badge.copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto de actividad de 6 px (opacidad 1 → 0.4 → 1 en 1.5 s).
class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.4).animate(_controller),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Fila etiqueta-valor del turno.
class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: EzyTextStyles.body.copyWith(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? surfaces.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila del desglose de cobros por método (emoji + monto).
class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: EzyTextStyles.body.copyWith(color: surfaces.textBody),
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
      ),
    );
  }
}

/// Saldos bancarios declarados al abrir el turno (snapshot congelado).
class _BankSnapshotCard extends StatelessWidget {
  const _BankSnapshotCard({required this.balances});

  final List<OpeningBankBalance> balances;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return _FlatCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: _CardTitle('Saldos bancarios al abrir')),
              Text(
                'Snapshot inicial',
                style: EzyTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: surfaces.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final balance in balances)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: surfaces.panelInner,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: surfaces.border),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        balance.label,
                        style: EzyTextStyles.body.copyWith(
                          color: surfaces.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      Money.format(balance.balance),
                      style: EzyTextStyles.moneyList.copyWith(
                        color: EzyColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// CTA «Hacer corte»: pastilla de 48 px con el relieve 3D de marca.
class _CloseShiftCta extends StatefulWidget {
  const _CloseShiftCta({required this.onPressed, this.isLoading = false});

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  State<_CloseShiftCta> createState() => _CloseShiftCtaState();
}

class _CloseShiftCtaState extends State<_CloseShiftCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.isLoading;

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: 48,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFFB9E2E),
              Color(0xFFF68C0F),
              Color(0xFFC95B00),
            ],
            stops: <double>[0.0, 0.42, 1.0],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: _pressed
              ? null
              : const <BoxShadow>[
                  BoxShadow(color: Color(0xFF853700), offset: Offset(0, 3)),
                  BoxShadow(
                    color: Color(0x66F68C0F),
                    offset: Offset(0, 6),
                    blurRadius: 18,
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          // El bisel va en una caja interior **sin radio**: un `Border` con
          // lados de distinto color junto a un `borderRadius` dispara la
          // aserción de Flutter y el contenido dejaría de pintarse.
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0x6BFFFFFF)),
                bottom: BorderSide(color: Color(0xFF944000), width: 2),
              ),
            ),
            child: Center(child: _content()),
          ),
        ),
      ),
    );
  }

  Widget _content() {
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
        const Icon(
          Icons.point_of_sale_outlined,
          size: 18,
          color: EzyColors.white,
          shadows: <Shadow>[
            Shadow(color: Colors.black38, offset: Offset(0, 1), blurRadius: 2),
          ],
        ),
        const SizedBox(width: 8),
        Text(
          'Hacer corte',
          style: EzyTextStyles.button.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: EzyColors.white,
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
