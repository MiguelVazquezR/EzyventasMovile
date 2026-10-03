import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';

/// Tokens del prototipo validado "Tesla UI / EzyColors" **solo** para la pantalla
/// de alta/edición de órdenes de servicio.
///
/// El tema compartido coincide con casi todos los valores (radio 24 de card,
/// borde #3A3A3A/#F3F4F6, naranja #F68C0F…); los pocos que difieren —el relleno
/// interno de campos en modo oscuro (#2A2A2A) y el lienzo del modo claro
/// (#E9EBF0)— viven aquí para no alterar el resto de la app.
class SoColors {
  const SoColors._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Superficies
  static const Color darkCanvas = Color(0xFF1A1A1A);
  static const Color lightCanvas = Color(0xFFE9EBF0);
  static const Color darkCard = Color(0xFF232323);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkInner = Color(0xFF2A2A2A);
  static const Color lightInner = Color(0xFFF6F7F9);
  static const Color darkBorder = Color(0xFF3A3A3A);
  static const Color lightBorder = Color(0xFFF3F4F6);
  static const Color lightBorderStrong = Color(0xFFE5E7EB);

  static Color canvas(BuildContext context) =>
      isDark(context) ? darkCanvas : lightCanvas;
  static Color card(BuildContext context) =>
      isDark(context) ? darkCard : lightCard;
  static Color inner(BuildContext context) =>
      isDark(context) ? darkInner : lightInner;
  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorder;

  /// Borde estructural: en claro sube a #E5E7EB para despegar del blanco.
  static Color structuralBorder(BuildContext context) =>
      isDark(context) ? darkBorder : lightBorderStrong;

  // Jerarquía de texto
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFFD1D5DB) : const Color(0xFF374151);
  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563);

  // Acentos
  static const Color primary = Color(0xFFF68C0F);
  static const Color danger = Color(0xFFF80505);
  static const Color success = Color(0xFF22C55E);
  static const Color info = Color(0xFF3B82F6);
  static const Color warn = Color(0xFFF59E0B);

  /// Tono legible del color base según el modo (avisos y banner).
  static Color tone(BuildContext context, Color base) {
    if (!isDark(context)) {
      if (base == warn) return const Color(0xFFB45309);
      if (base == danger) return const Color(0xFFB91C1C);
      if (base == success) return const Color(0xFF15803D);
      if (base == info) return const Color(0xFF1D4ED8);
      return base;
    }

    if (base == warn) return const Color(0xFFFCD34D);
    if (base == danger) return const Color(0xFFFCA5A5);
    if (base == success) return const Color(0xFF86EFAC);
    if (base == info) return const Color(0xFF93C5FD);
    return base;
  }
}

/// Micro-título de sección (`CLIENTE`, `TOTALES`, `DESCUENTO`).
class SoMicroLabel extends StatelessWidget {
  const SoMicroLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = EzyTextStyles.microLabel.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      color: SoColors.textSecondary(context),
    );

    if (trailing == null) {
      return Text(text.toUpperCase(), style: style);
    }

    return Row(
      children: <Widget>[
        Expanded(child: Text(text.toUpperCase(), style: style)),
        trailing!,
      ],
    );
  }
}

/// Etiqueta semántica de un concepto (`REFACCIÓN`, `SERVICIO`).
class SoTag extends StatelessWidget {
  const SoTag({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.badge.copyWith(
          fontSize: 9,
          letterSpacing: 0.8,
          color: SoColors.tone(context, color),
        ),
      ),
    );
  }
}

/// Texto de aviso/nota del pie de sección.
class SoNote extends StatelessWidget {
  const SoNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline,
    this.color = SoColors.warn,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 14, color: SoColors.tone(context, color)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: EzyTextStyles.caption.copyWith(
              fontSize: 11,
              color: SoColors.tone(context, color),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón principal de guardado con relieve 3D (`btn-tactile-3d`) del prototipo.
///
/// Degradado vertical de tres caras, bisel físico, sombra de marca y hundido de
/// 4 px al pulsar. Deshabilitado baja a 40 % de opacidad y no responde al toque.
class SoPrimaryButton extends StatefulWidget {
  const SoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.loadingLabel = 'Guardando…',
    this.height = 48,
    this.baseColor = SoColors.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final String loadingLabel;
  final double height;

  /// Acento del botón: el naranja de marca por defecto, verde al dar de alta un
  /// cliente desde el selector.
  final Color baseColor;

  @override
  State<SoPrimaryButton> createState() => _SoPrimaryButtonState();
}

class _SoPrimaryButtonState extends State<SoPrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  /// Degradado de tres caras: los valores exactos del prototipo para el naranja
  /// de marca y derivados del acento para el resto de variantes.
  List<Color> get _gradient => widget.baseColor == SoColors.primary
      ? const <Color>[Color(0xFFFB9E2E), SoColors.primary, Color(0xFFC95B00)]
      : <Color>[
          Color.lerp(widget.baseColor, const Color(0xFFFFFFFF), 0.22)!,
          widget.baseColor,
          Color.lerp(widget.baseColor, const Color(0xFF000000), 0.28)!,
        ];

  /// Canto inferior que da el volumen del bisel.
  Color get _bottomBorder => widget.baseColor == SoColors.primary
      ? const Color(0xFF8F3E00)
      : Color.lerp(widget.baseColor, const Color(0xFF000000), 0.42)!;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    return Opacity(
      opacity: enabled || widget.isLoading ? 1 : 0.4,
      child: GestureDetector(
        onTapDown: enabled ? (details) => _setPressed(true) : null,
        onTapUp: enabled ? (details) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          height: widget.height,
          transform: Matrix4.translationValues(
            0,
            _pressed && enabled ? 4 : 0,
            0,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _gradient,
              stops: const <double>[0, 0.52, 1],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: widget.baseColor.withValues(alpha: 0.28),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: const BorderSide(color: Color(0x59FFFFFF)),
                  bottom: BorderSide(color: _bottomBorder, width: 2.5),
                ),
              ),
              child: Center(child: _content()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    const style = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);

    if (widget.isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.loadingLabel,
            style: style.copyWith(color: const Color(0xFFFFFFFF)),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          Icon(widget.icon, size: 18, color: const Color(0xFFFFFFFF)),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: style.copyWith(color: const Color(0xFFFFFFFF)),
        ),
      ],
    );
  }
}

/// Botón de acción secundaria tipo contorno (`Del catálogo`, `Tomar foto`).
class SoOutlineButton extends StatelessWidget {
  const SoOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 44,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: SoColors.inner(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SoColors.structuralBorder(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 18, color: SoColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: EzyTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: SoColors.textPrimary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enlace de acción de sección con icono (`Editar conceptos`, `Cambiar`).
class SoTextAction extends StatelessWidget {
  const SoTextAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 18, color: SoColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: EzyTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: SoColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Switch táctil con el naranja de marca (`Asignar técnico`).
class SoSwitch extends StatelessWidget {
  const SoSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final off = SoColors.isDark(context)
        ? const Color(0xFF4A4A4A)
        : const Color(0xFFD1D5DB);

    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: SoColors.primary,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: off,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Control segmentado pill del design system (riel de 10 px y opción activa en
/// naranja con sombra de marca).
class ServiceOrderSegmentedControl<T> extends StatelessWidget {
  const ServiceOrderSegmentedControl({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: SoColors.inner(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: SoColors.structuralBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          for (final value in values)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelected(value),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == selected
                        ? SoColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: value == selected
                        ? const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x33F68C0F),
                              offset: Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labelOf(value),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: EzyTextStyles.caption.copyWith(
                      fontSize: 12,
                      fontWeight: value == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: value == selected
                          ? const Color(0xFFFFFFFF)
                          : SoColors.textMuted(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


/// Card del prototipo: radio 24, borde estructural y micro-título opcional.
class SoCard extends StatelessWidget {
  const SoCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: SoColors.card(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SoColors.structuralBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null) ...<Widget>[
            SoMicroLabel(title!, trailing: trailing),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Renglón `etiqueta / valor` de los resúmenes de totales y del cliente.
class SoInfoRow extends StatelessWidget {
  const SoInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasized = false,
    this.color,
  });

  final String label;
  final String value;
  final bool emphasized;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: EzyTextStyles.caption.copyWith(
              fontSize: emphasized ? 13 : 12,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
              color: SoColors.textMuted(context),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: EzyTextStyles.caption.copyWith(
            fontSize: emphasized ? 14 : 12,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            color: color ?? SoColors.textPrimary(context),
          ),
        ),
      ],
    );
  }
}

