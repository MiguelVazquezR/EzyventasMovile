import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_search_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../customers/application/customers_providers.dart';
import '../../../customers/data/models/customer.dart';
import '../../application/cart_controller.dart';

/// Verde del chip «saldo a favor» (no existe en la paleta de marca, §5).
const Color _greenSoftLight = Color(0xFFECFDF5);
const Color _greenTextLight = Color(0xFF059669);
const Color _greenTextDark = Color(0xFF34D399);
const Color _greenSoftDark = Color(0xFF10B981);

/// Rojo del chip «debe» (fondo claro + texto fuerte) y azul del chip
/// «crédito» (mismo criterio). Tampoco están en la paleta de marca (§5).
const Color _redSoftLight = Color(0xFFFEE2E2);
const Color _redTextLight = Color(0xFFDC2626);
const Color _redSoftDark = Color(0xFFEF4444);
const Color _redTextDark = Color(0xFFFCA5A5);
const Color _blueSoftLight = Color(0xFFEFF6FF);
const Color _blueTextLight = Color(0xFF1D4ED8);
const Color _blueSoftDark = Color(0xFF3B82F6);
const Color _blueTextDark = Color(0xFF93C5FD);

/// Selector de cliente del cobro (`GET /customers`).
///
/// Guarda la elección en el carrito; «Público general» lo deja sin cliente y
/// permite capturar el nombre del ticket (`guest_name`) en el mismo paso: la
/// tarjeta se expande al elegirla y cada tecla escribe el nombre en el carrito,
/// así que el dato sigue llegando igual a la venta. Con «Público general» la
/// hoja no se cierra (hay que poder escribir); el teclado la cierra con «Listo».
///
/// El lienzo de la hoja es el gris del carrito (`surfaces.background`) y cada
/// pieza va en blanco (`panel`), así la hoja se lee como un paso del cobro y no
/// como otra pantalla encima.
Future<void> showCustomerPickerSheet(BuildContext context) {
  return EzyBottomSheet.show<void>(
    context,
    backgroundColor: context.surfaces.background,
    builder: (sheetContext) => const _CustomerPickerSheet(),
  );
}

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  const _CustomerPickerSheet();

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final TextEditingController _guestController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _search = '';

  @override
  void initState() {
    super.initState();
    _guestController.text = ref.read(cartControllerProvider).guestName;
    // El buscador pinta su borde naranja mientras tiene el foco (§3).
    _searchFocus.addListener(_syncSearchFocus);
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_syncSearchFocus);
    _searchFocus.dispose();
    _guestController.dispose();
    super.dispose();
  }

  void _syncSearchFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final cart = ref.watch(cartControllerProvider);
    final controller = ref.read(cartControllerProvider.notifier);
    final customers = ref.watch(customerSearchProvider(_search));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SheetHeader(onClose: () => Navigator.of(context).pop()),
        Flexible(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              _GuestCard(
                isSelected: cart.customer == null,
                controller: _guestController,
                onSelected: () {
                  controller.setGuestName(_guestController.text);
                  controller.setCustomer(null);
                },
                onTicketNameChanged: controller.setGuestName,
                onSubmitted: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 12),
              EzySearchField(
                hint: 'Buscar cliente por nombre o teléfono…',
                fillColor: surfaces.panel,
                focusNode: _searchFocus,
                borderColor: _searchFocus.hasFocus
                    ? EzyColors.primary
                    : surfaces.border,
                onChanged: (value) => setState(() => _search = value.trim()),
              ),
              const SizedBox(height: 16),
              _ListHeader(total: customers.value?.total),
              const SizedBox(height: 8),
              customers.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: EzyColors.primary,
                    ),
                  ),
                ),
                error: (error, stackTrace) => ErrorNotice(
                  message: 'No se pudieron cargar los clientes.',
                  onRetry: () =>
                      ref.invalidate(customerSearchProvider(_search)),
                ),
                data: (page) {
                  if (page.items.isEmpty) {
                    return const _EmptyResults();
                  }

                  return Column(
                    children: <Widget>[
                      for (final customer in page.items)
                        _CustomerTile(
                          customer: customer,
                          isSelected: cart.customer?.id == customer.id,
                          onTap: () {
                            controller.setCustomer(customer);
                            Navigator.of(context).pop();
                          },
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Cabecera de la hoja: título 18.5 px `w700`, subtítulo corto y cierre en un
/// círculo de 32 px (§1).
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Cliente de la venta',
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    color: surfaces.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Requerido para crédito o saldo a favor',
                  style: EzyTextStyles.caption.copyWith(
                    fontSize: 12.5,
                    color: surfaces.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          EzyIconButton(
            icon: Icons.close,
            size: 32,
            iconSize: 16,
            tooltip: 'Cerrar',
            color: surfaces.textSecondary,
            background: surfaces.panel,
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

/// Micro-etiqueta «CLIENTES REGISTRADOS» con el contador en chip naranja (§4).
class _ListHeader extends StatelessWidget {
  const _ListHeader({this.total});

  /// Total del servidor; `null` mientras la primera página va en camino.
  final int? total;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final count = total;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'CLIENTES REGISTRADOS',
            style: EzyTextStyles.microLabel.copyWith(
              fontSize: 11,
              letterSpacing: 0.8,
              color: surfaces.textMuted,
            ),
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: EzyColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count cliente${count == 1 ? '' : 's'}',
              style: EzyTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: EzyColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Indicador de selección (20 px) de las tarjetas: relleno naranja con punto
/// blanco cuando está activo, aro gris cuando no (§2 y §5).
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.isSelected});

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? EzyColors.primary : Colors.transparent,
        border: isSelected ? null : Border.all(color: surfaces.borderStrong),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: EzyColors.white,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}


/// Venta sin cliente registrado (`guest_name`) como tarjeta seleccionable y
/// expandible: al elegirla aparece el nombre del ticket (§2).
class _GuestCard extends StatelessWidget {
  const _GuestCard({
    required this.isSelected,
    required this.controller,
    required this.onSelected,
    required this.onTicketNameChanged,
    required this.onSubmitted,
  });

  final bool isSelected;
  final TextEditingController controller;
  final VoidCallback onSelected;
  final ValueChanged<String> onTicketNameChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onSelected,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? EzyColors.primary.withValues(alpha: 0.5)
                : surfaces.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: EzyColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: EzyColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: EzyColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Público general',
                        style: EzyTextStyles.bodyStrong.copyWith(
                          fontSize: 14,
                          color: surfaces.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Venta rápida sin asignar saldo',
                        style: EzyTextStyles.caption.copyWith(
                          fontSize: 11.5,
                          color: surfaces.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _RadioDot(isSelected: isSelected),
              ],
            ),
            // El campo solo existe con la tarjeta elegida: seleccionarla ya es
            // la acción de «vender sin cliente».
            if (isSelected) ...<Widget>[
              const SizedBox(height: 10),
              _TicketNameField(
                controller: controller,
                onChanged: onTicketNameChanged,
                onSubmitted: onSubmitted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nombre del ticket (`guest_name`): etiqueta compacta y campo de 44 px (§2).
class _TicketNameField extends StatelessWidget {
  const _TicketNameField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'NOMBRE PARA EL TICKET',
          style: EzyTextStyles.microLabel.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: surfaces.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: surfaces.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: surfaces.border),
          ),
          child: Center(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onSubmitted(),
              textInputAction: TextInputAction.done,
              maxLength: 255,
              style: EzyTextStyles.fieldValue.copyWith(
                color: surfaces.textPrimary,
              ),
              decoration: InputDecoration(
                counterText: '',
                isDense: true,
                contentPadding: EdgeInsets.zero,
                // El tema global rellena los campos con `panelInner`; aquí el
                // relleno se iguala al gris del contenedor para que el hueco del
                // placeholder no se vea de otro color.
                filled: true,
                fillColor: surfaces.background,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Ej. Mostrador / Mesa 4 / Juan',
                hintStyle: EzyTextStyles.fieldValue.copyWith(
                  color: surfaces.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// Fila de cliente: avatar con iniciales, datos con chips de saldo y el mismo
/// indicador de selección de «Público general» (§5).
class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.isSelected,
    required this.onTap,
  });

  final Customer customer;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phone = customer.phone;

    final badges = <Widget>[
      if (customer.hasBalanceInFavor)
        _BalanceChip(
          label: 'Saldo a favor ${Money.format(customer.balance)}',
          background: isDark
              ? _greenSoftDark.withValues(alpha: 0.15)
              : _greenSoftLight,
          foreground: isDark ? _greenTextDark : _greenTextLight,
        ),
      if (customer.hasDebt)
        _BalanceChip(
          label: 'Debe ${Money.format(customer.balance.abs())}',
          background: isDark
              ? _redSoftDark.withValues(alpha: 0.15)
              : _redSoftLight,
          foreground: isDark ? _redTextDark : _redTextLight,
        ),
      if (customer.hasCredit)
        _BalanceChip(
          label: 'Crédito ${Money.format(customer.availableCredit)}',
          background: isDark
              ? _blueSoftDark.withValues(alpha: 0.15)
              : _blueSoftLight,
          foreground: isDark ? _blueTextDark : _blueTextLight,
        ),
    ];

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          // Fondo blanco también al seleccionar: el estado se marca solo con el
          // borde primario (el tinte translúcido se veía sucio sobre el gris).
          color: surfaces.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? EzyColors.primary.withValues(alpha: 0.5)
                : surfaces.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: EzyColors.cardShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CustomerAvatar(
              initials: _initials(customer.displayName),
              isSelected: isSelected,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    customer.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.bodyStrong.copyWith(
                      fontSize: 14,
                      color: surfaces.textPrimary,
                    ),
                  ),
                  if (phone != null && phone.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      phone,
                      style: EzyTextStyles.secondary.copyWith(
                        color: surfaces.textSecondary,
                      ),
                    ),
                  ],
                  if (badges.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: badges),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _RadioDot(isSelected: isSelected),
            ),
          ],
        ),
      ),
    );
  }
}


/// Avatar cuadrado del cliente: neutro con iniciales en el tono de texto, y
/// naranja con iniciales blancas cuando está seleccionado (§5).
class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.initials, required this.isSelected});

  final String initials;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isSelected ? EzyColors.primary : surfaces.panelInner,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? EzyColors.primary : surfaces.border,
        ),
      ),
      child: Text(
        initials,
        style: EzyTextStyles.bodyStrong.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isSelected ? EzyColors.white : surfaces.textPrimary,
        ),
      ),
    );
  }
}

/// Chip de un dato de saldo: pastilla redondeada con relleno y texto propios (§5).
class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: EzyTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

/// Estado vacío del buscador: círculo naranja de 52 px y frase corta (§6).
class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: EzyColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: EzyColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(Icons.search, color: EzyColors.primary, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            'Sin resultados',
            textAlign: TextAlign.center,
            style: EzyTextStyles.bodyStrong.copyWith(
              fontSize: 14,
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No encontramos clientes con ese criterio de búsqueda.',
            textAlign: TextAlign.center,
            style: EzyTextStyles.body.copyWith(
              fontSize: 13,
              color: surfaces.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Iniciales del avatar (máximo 2 letras) a partir del nombre a mostrar.
String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (words.isEmpty) {
    return '?';
  }

  if (words.length == 1) {
    final word = words.first;
    return (word.length >= 2 ? word.substring(0, 2) : word).toUpperCase();
  }

  return '${words[0][0]}${words[1][0]}'.toUpperCase();
}

