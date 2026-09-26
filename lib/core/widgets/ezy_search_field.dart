import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/search_debouncer.dart';

/// Buscador del design system: campo relleno, lupa a la izquierda y botón de
/// limpiar (§12, §14).
///
/// Cada tecla pasa por [SearchDebouncer] para no lanzar una petición por
/// pulsación: `onChanged` siempre recibe el último texto escrito. El botón de
/// limpiar cancela el temporizador pendiente antes de avisar con cadena vacía,
/// así no llega una consulta vieja después de borrar.
///
/// [trailing] es el hueco de acción a la derecha (§10): el POS mete ahí el botón
/// del escáner de códigos, que es un blanco táctil de 44 px dentro de los 48 del
/// campo.
class EzySearchField extends StatefulWidget {
  const EzySearchField({
    super.key,
    this.hint = 'Buscar',
    this.onChanged,
    this.onSubmitted,
    this.controller,
    this.focusNode,
    this.autofocus = false,
    this.debounce = const Duration(milliseconds: 350),
    this.height = 48,
    this.enabled = true,
    this.trailing,
    this.borderColor,
    this.fillColor,
    this.radius = 16,
    this.elevated = false,
  });

  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Si no se pasa, el campo crea y libera el suyo.
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool autofocus;
  final Duration debounce;
  final double height;
  final bool enabled;

  /// Acción a la derecha del texto (escáner, filtros…). Va **después** del botón
  /// de limpiar, así que el hueco del pulgar no se mueve al escribir.
  final Widget? trailing;

  /// Color del borde de 1 px; por defecto `border`. Sobre una pieza con relieve
  /// (el buscador flotante del POS) se pasa `border` para no recargarla.
  final Color? borderColor;

  /// Relleno del campo; por defecto `panelInner`.
  final Color? fillColor;

  /// Radio de las esquinas; el buscador flotante del POS usa 22 (pill).
  final double radius;

  /// Card flotante: añade la sombra suave que separa el campo del fondo cuando
  /// va montado sobre la cabecera (POS) en lugar de dentro de un panel.
  final bool elevated;

  @override
  State<EzySearchField> createState() => _EzySearchFieldState();
}

class _EzySearchFieldState extends State<EzySearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final SearchDebouncer _debouncer = SearchDebouncer(
    delay: widget.debounce,
  );
  late bool _hasText = _controller.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // El campo puede recibir un controlador de fuera (p. ej. «Limpiar filtros»
    // del catálogo): sin este oyente, vaciarlo por código dejaría la «x» del
    // buscador pintada como si todavía hubiera texto.
    _controller.addListener(_syncHasText);
  }

  @override
  void dispose() {
    _debouncer.cancel();
    _controller.removeListener(_syncHasText);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _syncHasText() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _handleChanged(String value) {
    if (_hasText != value.isNotEmpty) {
      setState(() => _hasText = value.isNotEmpty);
    }

    _debouncer.run(() => widget.onChanged?.call(value));
  }

  void _clear() {
    _debouncer.cancel();
    _controller.clear();
    setState(() => _hasText = false);
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    // La sombra del buscador flotante se adapta al tema: sobre fondo oscuro
    // necesita más opacidad para leerse, sobre claro se ensucia con poco.
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.fillColor ?? surfaces.panelInner,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: widget.borderColor ?? surfaces.border),
        boxShadow: widget.elevated
            ? <BoxShadow>[
                BoxShadow(
                  color: EzyColors.black2.withValues(alpha: isDark ? 0.5 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          const SizedBox(width: 14),
          Icon(Icons.search, size: 20, color: surfaces.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: widget.focusNode,
              autofocus: widget.autofocus,
              enabled: widget.enabled,
              textInputAction: TextInputAction.search,
              onChanged: _handleChanged,
              onSubmitted: widget.onSubmitted,
              style: EzyTextStyles.fieldValue.copyWith(
                color: surfaces.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintStyle: EzyTextStyles.fieldValue.copyWith(
                  color: surfaces.textMuted,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (_hasText)
            SizedBox(
              width: 44,
              height: widget.height,
              child: GestureDetector(
                onTap: _clear,
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Icon(Icons.close, size: 18, color: surfaces.textMuted),
                ),
              ),
            ),
          if (widget.trailing != null) ...<Widget>[
            widget.trailing!,
            const SizedBox(width: 2),
          ] else if (!_hasText)
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}
