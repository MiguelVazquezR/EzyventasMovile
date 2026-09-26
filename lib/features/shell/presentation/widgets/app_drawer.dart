import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/permissions_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../core/widgets/ezy_dialog.dart';
import '../../../../core/widgets/ezy_header_band.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_list_tile.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../account/application/account_providers.dart';
import '../../../account/presentation/account_labels.dart';
import '../../../account/presentation/logout_flow.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../pos/application/cart_controller.dart';

/// Menú lateral del cascarón: la navegación de la app desde que la barra
/// inferior dejó de existir.
///
/// Se abre con la hamburguesa de las cabeceras (`AppScreenHeader`, y la del POS)
/// o deslizando desde el borde izquierdo, y se cierra tocando el fondo, el botón
/// de cerrar o la fila elegida. Reúne en un solo sitio **todo** lo que antes
/// estaba repartido entre la barra inferior (Inicio, Órdenes, Ventas, Cuenta) y
/// el menú del FAB (Vender, Caja, nueva orden de servicio), más los accesos de
/// la pestaña Cuenta que ahorran un salto: perfil, sucursal, suscripción,
/// notificaciones y soporte.
///
/// **Inventario no está**: el alta y el ajuste de productos viven solo en la
/// versión web, y la app no ofrece accesos que el servidor vaya a rechazar
/// (§11.4). Cada fila se pinta solo si los módulos y permisos del servidor la
/// autorizan.
class EzyAppDrawer extends ConsumerWidget {
  const EzyAppDrawer({super.key});

  /// Ancho del panel: 300 px dejan el título de una pestaña entero y siguen
  /// mostrando el borde de la pantalla que queda detrás.
  static const double width = 300;

  /// Etiqueta del botón de cierre de la cabecera del panel.
  static const String closeTooltip = 'Cerrar menú';


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = context.surfaces;
    final state = ref.watch(authControllerProvider);
    final access = state.context;
    final user = state.user;
    final permissions = ref.watch(permissionsProvider);
    final tabs = ref.watch(visibleTabsProvider);
    final notificationTotal = ref.watch(notificationsTotalProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final currentTab = AppTab.fromLocation(GoRouterState.of(context).uri.path);

    // Nombre del negocio y sucursal activa, como en la cabecera del POS: es el
    // dato que el cajero necesita tener a la vista antes de cobrar. Sin
    // suscripción el nombre del negocio cae al de la sucursal, así que se quitan
    // las repeticiones (`Centro · Centro`).
    final branch = access?.currentBranch?.label ?? user?.branch?.name ?? '';
    final headerSubtitle = <String>{
      if (access != null && access.businessName.isNotEmpty) access.businessName,
      if (branch.isNotEmpty) branch,
    }.join(' · ');

    final navRows = <_DrawerRow>[
      for (final tab in tabs)
        _DrawerRow(
          icon: tab == currentTab ? tab.activeIcon : tab.icon,
          title: tab.label,
          isSelected: tab == currentTab,
          onTap: () => _goToTab(context, tab),
        ),
    ];

    final canCreateSale = permissions.can('pos.create_sale');
    final actionRows = <_DrawerRow>[
      if (permissions.isTabVisible(AppTab.sell))
        _DrawerRow(
          icon: Icons.add_shopping_cart_outlined,
          title: canCreateSale ? 'Nueva venta' : 'Abrir el punto de venta',
          subtitle: canCreateSale
              ? 'Lleva a Vender con el carrito listo para cobrar.'
              : 'Revisa el catálogo y los precios de la sucursal.',
          onTap: canCreateSale
              ? () => _startNewSale(context, ref)
              : () => _goToTab(context, AppTab.sell),
        ),
      if (permissions.can('services.orders.create'))
        _DrawerRow(
          icon: Icons.build_outlined,
          title: 'Nueva orden de servicio',
          subtitle: 'Registra el equipo, el cliente y el diagnóstico.',
          onTap: () => _push(context, serviceOrderNewPath),
        ),
    ];

    final accountRows = <_DrawerRow>[
      _DrawerRow(
        icon: Icons.person_outline,
        title: AccountLabels.profile,
        subtitle: AccountLabels.profileSubtitle,
        onTap: () => _push(context, profilePath),
      ),
      if (permissions.can('system.branches.switch'))
        _DrawerRow(
          icon: Icons.storefront_outlined,
          title: AccountLabels.changeBranch,
          subtitle: branch.isEmpty ? AccountLabels.branchTitle : branch,
          onTap: () => _push(context, branchSwitchPath),
        ),
      if (user?.isSubscriptionOwner ?? false)
        _DrawerRow(
          icon: Icons.workspace_premium_outlined,
          title: AccountLabels.subscription,
          subtitle: AccountLabels.subscriptionSubtitle,
          onTap: () => _push(context, subscriptionPath),
        ),
      _DrawerRow(
        icon: Icons.notifications_none,
        title: AccountLabels.notifications,
        badgeCount: notificationTotal,
        onTap: () => _push(context, notificationsPath),
      ),
      _DrawerRow(
        icon: Icons.help_outline,
        title: AccountLabels.support,
        subtitle: AccountLabels.supportSubtitle,
        onTap: () => _push(context, supportPath),
      ),
    ];

    return Drawer(
      width: width,
      backgroundColor: surfaces.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          _DrawerHeader(
            name: user?.name ?? '',
            photoUrl: user?.profilePhotoUrl,
            subtitle: headerSubtitle,
          ),
          const _SectionLabel('Navegación'),
          ..._rows(navRows),
          if (actionRows.isNotEmpty) ...<Widget>[
            const _SectionLabel('Acciones'),
            ..._rows(actionRows),
          ],
          const _SectionLabel('Cuenta'),
          ..._rows(accountRows),
          const _SectionLabel('Preferencias'),
          EzyListTile(
            icon: Icons.dark_mode_outlined,
            title: AccountLabels.darkMode,
            subtitle: AccountLabels.darkModeSubtitle,
            trailing: Switch(
              value: isDark,
              onChanged: (value) => ref
                  .read(themeModeProvider.notifier)
                  .setMode(value ? ThemeMode.dark : ThemeMode.light),
            ),
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          EzyListTile(
            icon: Icons.logout,
            title: AccountLabels.logout,
            isDestructive: true,
            showDivider: false,
            onTap: () => confirmAndLogout(context, ref),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  /// Filas de una sección con el divisor solo **entre** ellas: la última de cada
  /// bloque la separa el rótulo de la sección siguiente.
  List<Widget> _rows(List<_DrawerRow> rows) => <Widget>[
    for (var index = 0; index < rows.length; index++)
      EzyListTile(
        icon: rows[index].icon,
        title: rows[index].title,
        subtitle: rows[index].subtitle,
        badgeCount: rows[index].badgeCount,
        isSelected: rows[index].isSelected,
        showDivider: index < rows.length - 1,
        onTap: rows[index].onTap,
      ),
  ];

  /// Cambia de pestaña del cascarón cerrando antes el menú.
  void _goToTab(BuildContext context, AppTab tab) {
    _close(context);
    context.go(tab.path);
  }

  /// Abre una pantalla de sección (perfil, sucursal, soporte…) que vive fuera
  /// del cascarón, cerrando antes el menú para que el `push` no quede debajo.
  void _push(BuildContext context, String path) {
    _close(context);
    context.push(path);
  }

  /// Cierra el panel. `closeDrawer` es idempotente: si ya estuviera cerrado —una
  /// pulsación que llega tarde— no hace nada; un `pop` a ciegas se llevaría por
  /// delante la pantalla de debajo.
  void _close(BuildContext context) => Scaffold.maybeOf(context)?.closeDrawer();

  /// Empieza una venta limpia desde el menú: cierra el panel, vuelve a la
  /// pestaña Vender y, si había líneas sin cobrar, pide confirmación antes de
  /// vaciar el carrito (es trabajo del mostrador: perderlo sin avisar sería peor
  /// que el aviso).
  Future<void> _startNewSale(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartControllerProvider);

    if (!cart.isEmpty) {
      final confirmed = await showEzyConfirmDialog(
        context,
        title: 'Empezar una venta nueva',
        message:
            'El carrito tiene ${cart.lines.length} '
            '${cart.lines.length == 1 ? 'producto' : 'productos'} sin cobrar. '
            'Se vaciará para empezar otra venta.',
        confirmLabel: 'Vaciar y empezar',
        isDestructive: true,
      );

      if (!confirmed) {
        return;
      }

      ref.read(cartControllerProvider.notifier).clear();
    }

    if (!context.mounted) {
      return;
    }

    _goToTab(context, AppTab.sell);
  }
}

/// Cabecera del panel: avatar, nombre del usuario y negocio · sucursal sobre el
/// degradado de marca, con el botón de cerrar a la derecha.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.name,
    required this.subtitle,
    this.photoUrl,
  });

  final String name;
  final String subtitle;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();

    return EzyHeaderBand(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 20),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: EzyColors.white.withValues(alpha: 0.65)),
            ),
            child: UserAvatar(
              name: name,
              photoUrl: photoUrl,
              size: 44,
              onBrand: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  trimmed.isEmpty ? 'Tu sesión' : trimmed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 15,
                    color: EzyColors.white,
                  ),
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.secondary.copyWith(
                      color: EzyColors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
          EzyIconButton(
            icon: Icons.close,
            tooltip: EzyAppDrawer.closeTooltip,
            color: EzyColors.white,
            background: EzyColors.white.withValues(alpha: 0.18),
            borderColor: EzyColors.white.withValues(alpha: 0.32),
            onTap: () => Scaffold.maybeOf(context)?.closeDrawer(),
          ),
        ],
      ),
    );
  }
}

/// Rótulo de sección del panel: micro-etiqueta en MAYÚSCULAS sobre el fondo.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.microLabel.copyWith(
          color: context.surfaces.textMuted,
        ),
      ),
    );
  }
}

/// Fila del panel antes de convertirse en `EzyListTile`.
class _DrawerRow {
  const _DrawerRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badgeCount,
    this.isSelected = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final int? badgeCount;
  final bool isSelected;
}

