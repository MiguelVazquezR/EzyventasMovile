import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_controller.dart';
import '../data/models/active_cash_session.dart';

/// Pestaña "Caja".
///
/// Muestra el turno abierto con los datos que ya entregan `login` y `me`
/// (terminal, apertura, fondo y cobros por método). La apertura y el corte
/// llegan en la siguiente etapa.
class CashRegisterScreen extends ConsumerWidget {
  const CashRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeCashSessionProvider);

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
              child: session == null
                  ? _NoSessionState(
                      onRefresh: () => ref
                          .read(authControllerProvider.notifier)
                          .refreshContext(),
                    )
                  : _SessionSummary(session: session),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSessionState extends StatelessWidget {
  const _NoSessionState({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        const EmptyState(
          icon: Icons.account_balance_outlined,
          title: 'No tienes una sesión de caja abierta.',
          message:
              'Abre el turno con el fondo de efectivo y los saldos bancarios '
              'para poder cobrar.',
          compact: true,
        ),
        const SizedBox(height: 12),
        NoticeBanner(
          message:
              'La apertura y el corte de caja se habilitan en la siguiente entrega de la app.',
          tone: EzySeverity.info,
          actionLabel: 'Actualizar estado',
          onAction: onRefresh,
        ),
      ],
    );
  }
}

class _SessionSummary extends StatelessWidget {
  const _SessionSummary({required this.session});

  final ActiveCashSession session;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        SectionCard(
          title: 'Turno actual',
          trailing: const StatusBadge(
            label: 'Abierta',
            severity: EzySeverity.success,
            showDot: true,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionRow(label: 'Terminal', value: session.cashRegisterName),
              SectionRow(label: 'Abrió', value: session.opener?.name ?? '—'),
              SectionRow(
                label: 'Apertura',
                value: AppFormatters.dateTime(session.openedAt),
              ),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
        if (session.hasMultipleUsers) ...<Widget>[
          const SizedBox(height: 12),
          NoticeBanner(
            message:
                'Hay ${session.users.length} usuarios en esta sesión; al cerrarla, todos saldrán de la caja.',
            tone: EzySeverity.warn,
          ),
        ],
        const SizedBox(height: 12),
        const _UpcomingCard(),
      ],
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard();

  static const List<String> _items = <String>[
    'Unirse a un turno ya abierto o retomarlo en este dispositivo.',
    'Apertura de turno con fondo de efectivo y saldos bancarios declarados.',
    'Corte: efectivo contado, diferencia en vivo y notas de arqueo.',
  ];

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Siguiente entrega',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: EzyColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: EzyTextStyles.body.copyWith(
                        color: surfaces.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
