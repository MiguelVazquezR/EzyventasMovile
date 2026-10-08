import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/section_card.dart';
import '../../data/models/custom_field_definition.dart';
import '../../data/models/custom_field_normalizers.dart';
import '../../data/models/custom_field_value.dart';
import 'pattern_input.dart';

/// Sección «Detalles adicionales» de la vista de una orden (doc 04 §9.2 y §9.3).
///
/// Recorre las definiciones **en el orden recibido** y pinta cada fila con su
/// `name`; al final agrega las claves huérfanas (sin definición) como texto
/// plano. Nunca se muestra el JSON crudo: cada tipo tiene su lectura y el valor
/// vacío se rotula `N/A`. Si `custom_fields` no tiene ninguna clave, no se pinta
/// nada.
class CustomFieldsReadCard extends StatelessWidget {
  const CustomFieldsReadCard({
    super.key,
    required this.definitions,
    required this.values,
  });

  final List<CustomFieldDefinition> definitions;
  final Map<String, dynamic> values;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = <Widget>[];

    for (final definition in definitions) {
      entries.add(
        _ReadRow(
          label: definition.name.isEmpty
              ? labelFromKey(definition.key)
              : definition.name,
          child: _readValue(
            context,
            definition,
            parseCustomFieldValue(definition.type, values[definition.key]),
          ),
        ),
      );
    }

    final known = <String>{
      for (final definition in definitions) definition.key,
    };

    for (final entry in values.entries) {
      if (known.contains(entry.key)) {
        continue;
      }

      entries.add(
        _ReadRow(
          label: labelFromKey(entry.key),
          child: _orphanValue(context, entry.value),
        ),
      );
    }

    return SectionCard(
      title: 'Detalles adicionales',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Información personalizada del servicio',
            style: EzyTextStyles.caption.copyWith(
              color: context.surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < entries.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: 14),
            entries[index],
          ],
        ],
      ),
    );
  }

  /// Lectura por tipo (§9.2). El tipo lo dicta la definición, no el valor.
  Widget _readValue(
    BuildContext context,
    CustomFieldDefinition definition,
    CustomFieldValue value,
  ) {
    if (value is PatternValue) {
      return _PatternRead(value: value);
    }

    if (value is MultiOptionValue) {
      return _OptionsRead(
        options: definition.options.isEmpty
            ? value.options
            : <String>[
                ...definition.options,
                ...value.options.where(
                  (option) => !definition.options.contains(option),
                ),
              ],
        selected: value.options,
      );
    }

    return _plainText(context, value);
  }

  /// Clave sin definición: se muestra su valor normalizado como texto plano.
  Widget _orphanValue(BuildContext context, Object? raw) {
    if (raw is Map && (raw['type'] == 'pattern' || raw['type'] == 'password')) {
      return _PatternRead(value: normalizePattern(raw));
    }

    if (raw is List) {
      return _plainText(context, MultiOptionValue(normalizeList(raw)));
    }

    if (raw is Map) {
      final values = raw.values.map((item) => item.toString()).toList();

      return _plainText(context, TextValue(values.join(', ')));
    }

    return _plainText(context, TextValue(raw?.toString() ?? ''));
  }

  Widget _plainText(BuildContext context, CustomFieldValue value) {
    if (value is BoolValue) {
      return _ValueText(value.value ? 'Sí' : 'No');
    }

    if (value.isBlank) {
      return _ValueText(notSetLabel, muted: true);
    }

    return _ValueText(
      value is MultiOptionValue
          ? value.options.join(', ')
          : value.toJson().toString(),
    );
  }
}

/// Fila de lectura: rótulo arriba y valor debajo (el patrón y las opciones
/// necesitan el ancho completo).
class _ReadRow extends StatelessWidget {
  const _ReadRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: EzyTextStyles.caption.copyWith(
            color: context.surfaces.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

/// Valor simple; en gris cuando el campo está vacío (`N/A`).
class _ValueText extends StatelessWidget {
  const _ValueText(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: EzyTextStyles.body.copyWith(
        color: muted ? context.surfaces.textMuted : context.surfaces.textPrimary,
      ),
    );
  }
}

/// `checkbox`: **todas** las opciones listadas — las seleccionadas con palomita
/// verde y en negritas, las demás en gris y tachadas (§9.2).
class _OptionsRead extends StatelessWidget {
  const _OptionsRead({required this.options, required this.selected});

  final List<String> options;
  final List<String> selected;

  @override
  Widget build(BuildContext context) {
    final success = StatusPalette.text(context, EzySeverity.success);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < options.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  selected.contains(options[index])
                      ? Icons.check_circle
                      : Icons.remove_circle_outline,
                  size: 16,
                  color: selected.contains(options[index])
                      ? success
                      : context.surfaces.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    options[index],
                    style: EzyTextStyles.body.copyWith(
                      fontWeight: selected.contains(options[index])
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected.contains(options[index])
                          ? context.surfaces.textPrimary
                          : context.surfaces.textMuted,
                      decoration: selected.contains(options[index])
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// `pattern`: tablero dibujado de solo lectura, contraseña enmascarada o `N/A`.
class _PatternRead extends StatelessWidget {
  const _PatternRead({required this.value});

  final PatternValue value;

  @override
  Widget build(BuildContext context) {
    if (value.isBlank) {
      return const _ValueText(notSetLabel, muted: true);
    }

    if (value.mode == 'password') {
      return _PasswordRead(password: value.password);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surfaces.panelInner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.surfaces.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          PatternInput(
            points: value.points,
            readOnly: true,
            side: 200,
          ),
          const SizedBox(height: 8),
          Text(
            'Puntos en orden: ${value.points.join(' → ')}',
            style: EzyTextStyles.caption.copyWith(
              color: context.surfaces.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Contraseña de desbloqueo: siempre enmascarada hasta que se pide verla (§8.1).
class _PasswordRead extends StatefulWidget {
  const _PasswordRead({required this.password});

  final String password;

  @override
  State<_PasswordRead> createState() => _PasswordReadState();
}

class _PasswordReadState extends State<_PasswordRead> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final masked = List<String>.filled(
      widget.password.length.clamp(1, 12),
      '•',
    ).join();

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            _revealed ? widget.password : masked,
            style: EzyTextStyles.bodyStrong.copyWith(
              color: context.surfaces.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => setState(() => _revealed = !_revealed),
          behavior: HitTestBehavior.opaque,
          child: Text(
            _revealed ? 'Ocultar' : 'Ver contraseña',
            style: EzyTextStyles.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: EzyColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
