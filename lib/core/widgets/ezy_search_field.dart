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
  void dispose() {
    _debouncer.cancel();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
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

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
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
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}
