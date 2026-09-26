import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/permissions_service.dart';
import '../../../core/scanner/scanner_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/app_drawer_scope.dart';
import '../../../core/widgets/app_screen_header.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/ezy_header_band.dart';
import '../../../core/widgets/ezy_icon_button.dart';
import '../../../core/widgets/ezy_search_field.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../cash/application/cash_register_controller.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../catalog/presentation/widgets/product_catalog_view.dart';
import 'widgets/cart_bar.dart';

/// Pestaña "Vender" (POS): catálogo + carrito + cobro.
///
/// La cabecera es la banda curva de marca: avatar, negocio y sucursal activa, el
/// disparador del menú lateral y, debajo, el buscador flotante con el botón
/// redondo del escáner. El buscador no se va con el scroll: es el campo que el
/// mostrador usa a cada rato, y el botón del escáner es el añadido rápido por
/// código.
///
/// El cobro exige una sesión de caja abierta: si no la hay, el aviso del cuerpo
/// lleva a Caja y la barra del carrito lo dice en su primera línea. El catálogo
/// es `ProductCatalogView` (chips de categoría, reja de dos columnas y detalle en
/// hoja) y el carrito, `CartBar`.
class PointOfSaleScreen extends ConsumerStatefulWidget {
  const PointOfSaleScreen({super.key});

  /// Alto del buscador y de su botón de escáner.
  static const double searchRowHeight = 52;

  @override
  ConsumerState<PointOfSaleScreen> createState() => _PointOfSaleScreenState();
}

class _PointOfSaleScreenState extends ConsumerState<PointOfSaleScreen>
    with WidgetsBindingObserver {
  /// Buscador del catálogo: vive en la cabecera del POS y lo comparte el
  /// catálogo para poder vaciarlo desde «Limpiar filtros».
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  /// Al volver la app a primer plano se refresca el turno: si otro usuario lo
  /// cerró desde la web, el POS vuelve a la pantalla de apertura.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }

    ref.read(cashRegisterControllerProvider.notifier).refresh();
    ref.read(productsControllerProvider.notifier).refresh();
  }

  /// Escanea un código de barras o QR y lo deja en el buscador (§12).
  ///
  /// El texto entra por la misma búsqueda del catálogo (nombre o SKU), así que un
  /// código que no exista se resuelve con el «sin resultados» de siempre y su
  /// «Limpiar filtros», no con un error inventado.
  Future<void> _scanCode() async {
    final scan = ref.read(scannerLauncherProvider);
    final code = (await scan(context))?.trim();

    if (code == null || code.isEmpty || !mounted) {
      return;
    }

    _searchController.text = code;
    await ref.read(productsControllerProvider.notifier).setSearch(code);

    if (!mounted) {
      return;
    }

    // §12: la confirmación se da aquí, en la pantalla que abrió el escáner.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Código escaneado: $code')));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final access = state.context;
    final user = state.user;
    final session = ref.watch(activeCashSessionProvider);
    final permissions = ref.watch(permissionsProvider);
    final products = ref.read(productsControllerProvider.notifier);

    if (!permissions.can('pos.access')) {
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              const AppScreenHeader(title: 'Punto de venta'),
              const Expanded(
                child: EmptyState(
                  icon: Icons.lock_outline,
                  title: 'Tu usuario no tiene permiso para esta acción.',
                  message:
                      'Pide al administrador el permiso de acceso al punto de venta.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            EzyHeaderBand(
              // 14 arriba y 16 abajo: el buscador queda pegado al borde curvo de
              // la banda, con el aire justo para leerse como card flotante.
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: <Widget>[
                  _SellerRow(
                    name: user?.name ?? '',
                    photoUrl: user?.profilePhotoUrl,
                    businessName: access?.businessName ?? 'Punto de venta',
                    branchName:
                        access?.currentBranch?.label ??
                        access?.user.branch?.name ??
                        '',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: EzySearchField(
                          hint: 'Buscar por nombre o SKU…',
                          controller: _searchController,
                          onChanged: products.setSearch,
                          onSubmitted: products.setSearch,
                          height: PointOfSaleScreen.searchRowHeight,
                          radius: 22,
                          // Card claro con sombra sobre el degradado de marca.
                          fillColor: context.surfaces.panel,
                          elevated: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _QuickScanButton(onTap: _scanCode),
                    ],
                  ),
                ],
              ),
            ),
            if (session == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: NoticeBanner(
                  message:
                      'Necesitas una sesión de caja abierta para registrar ventas.',
                  tone: EzySeverity.warn,
                  icon: Icons.warning_amber_rounded,
                  actionLabel: 'Ir a Caja',
                  onAction: () => context.go(AppTab.cashRegister.path),
                ),
              ),
            if (!permissions.can('pos.create_sale'))
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: NoticeBanner(
                  message: 'Tu usuario no tiene permiso para esta acción.',
                  tone: EzySeverity.info,
                  icon: Icons.lock_outline,
                ),
              ),
            Expanded(
              child: ProductCatalogView(searchController: _searchController),
            ),
            const CartBar(),
          ],
        ),
      ),
    );
  }
}

/// Cabecera del POS: avatar del vendedor, su nombre, el negocio · sucursal y el
/// disparador del menú lateral.
///
/// Arriba va el nombre del vendedor (el dato humano de la sesión) y debajo, en
/// chico, el negocio con la sucursal activa (`ApontePhone · Melchor Ocampo`),
/// igual que en la cabecera del menú lateral. Cuando el nombre del negocio y el
/// de la sucursal son el mismo (usuario sin suscripción) se quita la repetición,
/// y lo que no quepa se corta con `…` en lugar de desbordar la banda.
///
/// El avatar y el nombre quedan del lado del pulgar que sostiene el teléfono; la
/// hamburguesa, del otro. Sin `AppDrawerScope` (una prueba de widget) la
/// hamburguesa no se pinta: no hay menú que abrir.
class _SellerRow extends StatelessWidget {
  const _SellerRow({
    required this.name,
    required this.businessName,
    required this.branchName,
    this.photoUrl,
  });

  final String name;
  final String businessName;
  final String branchName;
  final String? photoUrl;

  /// `Negocio · Sucursal`, sin repetir el nombre cuando son el mismo.
  static String contextLabel(String businessName, String branchName) {
    return <String>{
      if (businessName.trim().isNotEmpty) businessName.trim(),
      if (branchName.trim().isNotEmpty) branchName.trim(),
    }.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final openDrawer = AppDrawerScope.maybeOf(context);
    final seller = name.trim();
    final label = contextLabel(businessName, branchName);

    return Row(
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
            size: 42,
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
                // Sin nombre de usuario (sesión a medias) el titular es el
                // negocio: nunca queda una línea en blanco en la banda.
                seller.isEmpty ? businessName : seller,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EzyTextStyles.bodyStrong.copyWith(
                  fontSize: 16,
                  color: EzyColors.white,
                ),
              ),
              if (label.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.storefront_outlined,
                      size: 13,
                      color: EzyColors.white.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EzyTextStyles.secondary.copyWith(
                          color: EzyColors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (openDrawer != null) ...<Widget>[
          const SizedBox(width: 8),
          EzyIconButton(
            icon: Icons.menu,
            tooltip: appDrawerOpenTooltip,
            color: EzyColors.white,
            background: EzyColors.white.withValues(alpha: 0.18),
            borderColor: EzyColors.white.withValues(alpha: 0.32),
            onTap: openDrawer,
          ),
        ],
      ],
    );
  }
}

/// Botón redondo del escáner: el añadido rápido por código de barras.
///
/// Va junto al buscador y no dentro de él (como `trailing`) para que sea un
/// blanco táctil entero de 52 px: el que dispara el escáner a cada rato quiere
/// acertarle sin mirar. Es blanco con el icono naranja porque sobre el degradado
/// de la cabecera un botón naranja desaparecería.
class _QuickScanButton extends StatelessWidget {
  const _QuickScanButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Escanear código',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: PointOfSaleScreen.searchRowHeight,
          height: PointOfSaleScreen.searchRowHeight,
          decoration: BoxDecoration(
            color: EzyColors.white,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: EzyColors.black2.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.qr_code_scanner,
            size: 24,
            color: EzyColors.primary,
          ),
        ),
      ),
    );
  }
}
