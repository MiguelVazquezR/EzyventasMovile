import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/ezy_list_tile.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../auth/application/auth_controller.dart';

/// Pestaña «Inicio».
///
/// Es el destino por defecto tras el login. Hoy solo da la bienvenida y las
/// pistas de por dónde empezar: el resumen con datos reales (ventas del día,
/// apartados por vencer, órdenes abiertas) se monta cuando el servidor entregue
/// ese resumen.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessContext = ref.watch(authControllerProvider).context;
    final permissions = ref.watch(permissionsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            AppScreenHeader(
              title: 'Inicio',
              subtitle: accessContext?.businessName,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: <Widget>[
                  // Sin módulos contratados la bienvenida se quedaría sin nada
                  // que ofrecer: se explica lo que falta y a quién pedirlo
                  // (§11.4), sin botones que el servidor vaya a rechazar.
                  if (permissions.moduleKeys.isEmpty) ...<Widget>[
                    const NoticeBanner(
                      message:
                          'Tu suscripción no tiene módulos activos. Contacta '
                          'al administrador para renovar el plan.',
                      tone: EzySeverity.warn,
                    ),
                    const SizedBox(height: 12),
                  ],
                  _WelcomeCard(name: accessContext?.user.name ?? ''),
                  const SizedBox(height: 20),
                  const _NextStepsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de bienvenida: pastilla de marca, saludo y qué va a vivir aquí
/// (§11.1).
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name});

  /// Nombre del usuario tal como lo entrega el servidor.
  final String name;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final trimmed = name.trim();

    return SectionCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // §6: una sola pastilla de marca por pantalla.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: EzyColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: EzyColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              '¡Bienvenido!',
              style: EzyTextStyles.badge.copyWith(color: EzyColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            trimmed.isEmpty ? 'Hola' : 'Hola, $trimmed',
            style: EzyTextStyles.screenTitle.copyWith(
              fontSize: 20,
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Estamos preparando el resumen de tu negocio: ventas del día, '
            'apartados por vencer y órdenes de servicio abiertas.',
            style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Mientras tanto, muévete con el menú lateral: el botón de tres '
            'líneas de la cabecera lleva a Vender, Órdenes, Caja y Ventas.',
            style: EzyTextStyles.body.copyWith(color: surfaces.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Pistas de por dónde empezar.
///
/// Son filas del design system (`EzyListTile` sobre un panel) y solo se pintan
/// las que el usuario **puede** abrir: la app no ofrece accesos que el servidor
/// vaya a rechazar (§11.4).
class _NextStepsCard extends ConsumerWidget {
  const _NextStepsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = ref.watch(permissionsProvider);
    final rows =
        <({IconData icon, String title, String subtitle, AppTab tab})>[
          if (permissions.isTabVisible(AppTab.sell))
            (
              icon: Icons.shopping_cart_outlined,
              title: 'Vender',
              subtitle: 'Cobra con el catálogo y el carrito de la sucursal.',
              tab: AppTab.sell,
            ),
          if (permissions.isTabVisible(AppTab.serviceOrders))
            (
              icon: Icons.build_outlined,
              title: 'Órdenes de servicio',
              subtitle: 'Registra el equipo y sigue su estatus.',
              tab: AppTab.serviceOrders,
            ),
          if (permissions.isTabVisible(AppTab.cashRegister))
            (
              icon: Icons.account_balance_outlined,
              title: 'Caja',
              subtitle: 'Abre el turno, registra movimientos y haz el corte.',
              tab: AppTab.cashRegister,
            ),
          if (permissions.isTabVisible(AppTab.sales))
            (
              icon: Icons.receipt_long_outlined,
              title: 'Ventas',
              subtitle: 'Consulta el historial, los abonos y las cancelaciones.',
              tab: AppTab.sales,
            ),
        ];

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: <Widget>[
          for (int i = 0; i < rows.length; i++)
            EzyListTile(
              icon: rows[i].icon,
              title: rows[i].title,
              subtitle: rows[i].subtitle,
              showDivider: i < rows.length - 1,
              onTap: () => context.go(rows[i].tab.path),
            ),
        ],
      ),
    );
  }
}
