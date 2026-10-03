import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permissions_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/sales_controller.dart';
import '../../data/models/transaction_detail.dart';
import 'abono_sheet.dart';
import 'cancellation_sheet.dart';

/// Acciones disponibles en el detalle según permisos y estatus.
///
/// La app oculta lo que el usuario no puede hacer; el servidor siempre
/// revalida (`403`).
class TransactionActionBar extends ConsumerWidget {
  const TransactionActionBar({super.key, required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final session = ref.watch(activeCashSessionProvider);
    final isSubmitting = ref.watch(
      transactionDetailControllerProvider.select((state) => state.isSubmitting),
    );

    final showPayment =
        permissions.can('transactions.add_payment') && detail.canReceivePayment;
    final showCancellation =
        (permissions.can('transactions.cancel') ||
            permissions.can('transactions.refund')) &&
        detail.canBeCancelled;

    // Venta anulada (o sin permisos): no hay barra que mostrar.
    if (!showPayment && !showCancellation) {
      return const SizedBox.shrink();
    }

    final needsRegister = showPayment && session == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (needsRegister) ...<Widget>[
          _ClosedRegisterCard(onOpen: () => _goToCashRegister(context)),
          const SizedBox(height: 12),
        ],
        // Las dos acciones van a lo ancho y una debajo de la otra: el CTA de
        // abono lleva la etiqueta larga y `EzyPrimary3dButton` no encoge su
        // fila de contenido, así que en un carril a medias desborda.
        if (showPayment)
          EzyPrimary3dButton(
            label: 'Registrar abono',
            icon: Icons.add_rounded,
            height: 46,
            maxWidth: 520,
            isLoading: isSubmitting,
            onPressed: needsRegister
                ? null
                : () => showAbonoSheet(context, detail: detail),
          ),
        if (showPayment && showCancellation) const SizedBox(height: 10),
        if (showCancellation)
          _TactileOutlineButton(
            label: 'Cancelar o reembolsar',
            icon: Icons.undo_rounded,
            onTap: () => showCancellationSheet(context, detail: detail),
          ),
      ],
    );
  }

  /// Cierra la hoja y lleva al turno de caja para abrirlo.
  static void _goToCashRegister(BuildContext context) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();

    router.go(AppTab.cashRegister.path);
  }
}

/// Aviso crítico de caja cerrada: no se puede abonar sin turno abierto.
class _ClosedRegisterCard extends StatelessWidget {
  const _ClosedRegisterCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, EzySeverity.warn);
    final accent = EzyColors.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.warning_amber_rounded, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Caja cerrada',
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Necesitas una sesión de caja abierta para registrar abonos.',
            style: EzyTextStyles.caption.copyWith(color: color),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.point_of_sale_outlined, size: 16, color: color),
                  const SizedBox(width: 6),
                  Text(
                    'Ir a caja',
                    style: EzyTextStyles.button.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
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

/// Acción secundaria táctil: panel con borde reforzado que se hunde al pulsar.
class _TactileOutlineButton extends StatefulWidget {
  const _TactileOutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_TactileOutlineButton> createState() => _TactileOutlineButtonState();
}

class _TactileOutlineButtonState extends State<_TactileOutlineButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: 46,
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaces.borderStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(widget.icon, size: 18, color: EzyColors.danger),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                style: EzyTextStyles.button.copyWith(
                  fontWeight: FontWeight.w700,
                  color: surfaces.textBody,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
