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
import '../../../../core/widgets/user_avatar.dart';
import '../../../account/application/account_providers.dart';
import '../../../account/presentation/account_labels.dart';
import '../../../account/presentation/logout_flow.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../pos/application/cart_controller.dart';
import 'drawer_tiles.dart';

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

  /// Versión y build que firma el pie del panel. Se mantienen al día con
  /// `version:` de `pubspec.yaml` (`0.1.0+1`): la app no lleva paquete de
  /// versión —una dependencia más para un texto— y el dato solo se usa aquí.
  static const String appVersion = '0.1.0';
  static const String buildNumber = '1';


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
          icon: Icons.add,
          title: canCreateSale ? 'Nueva venta' : 'Abrir el punto de venta',
          subtitle: canCreateSale
              ? 'Abrir terminal POS'
              : 'Revisa el catálogo y los precios de la sucursal.',
          isPrimaryAction: true,
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

    // El pie no debe quedar bajo la barra de gestos del sistema.
    final bottomInset = MediaQuery.paddingOf(context).bottom;

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
          const DrawerSectionLabel('Navegación'),
          DrawerSectionCard(children: _rows(navRows)),
          if (actionRows.isNotEmpty) ...<Widget>[
            const DrawerSectionLabel('Acciones rápidas'),
            DrawerSectionCard(children: _rows(actionRows)),
          ],
          const DrawerSectionLabel('Cuenta'),
          DrawerSectionCard(children: _rows(accountRows)),
          const DrawerSectionLabel('Preferencias'),
          DrawerSectionCard(
            children: <Widget>[
              DrawerNavTile(
                icon: Icons.dark_mode_outlined,
                title: AccountLabels.darkMode,
                subtitle: AccountLabels.darkModeSubtitle,
                trailing: Switch.adaptive(
                  value: isDark,
                  onChanged: (value) => ref
                      .read(themeModeProvider.notifier)
                      .setMode(value ? ThemeMode.dark : ThemeMode.light),
                ),
                onTap: () => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ],
          ),
          DrawerDestructiveTile(
            icon: Icons.logout,
            title: AccountLabels.logout,
            onTap: () => confirmAndLogout(context, ref),
          ),
          _DrawerFooter(bottomInset: bottomInset),
        ],
      ),
    );
  }

  /// Filas de una sección con el divisor solo **entre** ellas: de eso se encarga
  /// la tarjeta (`DrawerSectionCard`), así que aquí solo se traducen los datos.
  List<Widget> _rows(List<_DrawerRow> rows) => <Widget>[
    for (final row in rows)
      DrawerNavTile(
        icon: row.icon,
        title: row.title,
        subtitle: row.subtitle,
        badgeCount: row.badgeCount,
        isSelected: row.isSelected,
        isPrimary: row.isPrimaryAction,
        onTap: row.onTap,
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
    // El panel cuelga del `Scaffold` a pantalla completa (cubre el hueco del
    // `AppBar`), así que la banda arranca en el borde superior de la pantalla —
    // el degradado sí llega arriba— y el contenido baja lo que mida la barra de
    // notificaciones: la hora, la batería y el notch no se pisan nunca.
    final topInset = MediaQuery.paddingOf(context).top;

    return EzyHeaderBand(
      decoration: EzyHeaderBandDecoration.circles,
      padding: EdgeInsets.fromLTRB(16, topInset + 14, 12, 18),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: 2,
                  color: EzyColors.white.withValues(alpha: 0.65),
                ),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
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
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: EzyColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            EzyIconButton(
              icon: Icons.close,
              tooltip: EzyAppDrawer.closeTooltip,
              size: 30,
              iconSize: 14,
              color: EzyColors.white,
              background: EzyColors.white.withValues(alpha: 0.18),
              borderColor: EzyColors.white.withValues(alpha: 0.32),
              onTap: () => Scaffold.maybeOf(context)?.closeDrawer(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pie del panel: firma de versión centrada al final del recorrido.
class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({required this.bottomInset});

  /// Alto de la barra de gestos del sistema, para no escribir debajo de ella.
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Text(
        'EZY POS V${EzyAppDrawer.appVersion} · '
        'BUILD ${EzyAppDrawer.buildNumber}',
        textAlign: TextAlign.center,
        style: EzyTextStyles.microLabel.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.surfaces.textMuted,
        ),
      ),
    );
  }
}

/// Fila del panel antes de convertirse en `DrawerNavTile`.
class _DrawerRow {
  const _DrawerRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badgeCount,
    this.isSelected = false,
    this.isPrimaryAction = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final int? badgeCount;
  final bool isSelected;

  /// Acción de marca (`Nueva venta`): icono en cuadro naranja y título primario.
  final bool isPrimaryAction;
}

