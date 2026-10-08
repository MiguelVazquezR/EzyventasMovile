import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_chip.dart';
import '../../../../core/widgets/ezy_selectable_tile.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/field_label.dart';
import '../../data/models/custom_field_definition.dart';
import '../../data/models/custom_field_normalizers.dart';
import '../../data/models/custom_field_value.dart';
import 'pattern_input.dart';
import 'service_order_form_controls.dart';

/// Editor de un campo personalizado según el **tipo de su definición**
/// (doc 04 §9.1): un solo punto de decisión para el alta y la edición.
///
/// Contrato del valor que emite [onChanged]:
///
/// | tipo | valor |
/// |---|---|
/// | `text`, `textarea`, desconocido | `String` |
/// | `number` | `num?` (`null` si se vacía) |
/// | `boolean` | `bool` real |
/// | `select` | `String` |
/// | `checkbox` | `List<String>` |
/// | `pattern` | `{'type':…,'value':…}`, **nunca** `null` |
Widget buildCustomFieldEditor(
  CustomFieldDefinition definition,
  Object? rawValue,
  ValueChanged<Object?> onChanged,
) {
  final label = definition.name.isEmpty
      ? labelFromKey(definition.key)
      : definition.name;

  return switch (definition.type) {
    CustomFieldTypes.textarea => _TextEditor(
      label: label,
      definition: definition,
      value: rawValue,
      maxLines: 4,
      maxLength: 1000,
      onChanged: onChanged,
    ),
    CustomFieldTypes.number => _TextEditor(
      label: label,
      definition: definition,
      value: rawValue,
      numeric: true,
      maxLength: 32,
      onChanged: onChanged,
    ),
    CustomFieldTypes.boolean => _BooleanEditor(
      label: label,
      value: normalizeBool(rawValue),
      onChanged: onChanged,
    ),
    CustomFieldTypes.select => _SelectEditor(
      label: label,
      definition: definition,
      value: rawValue?.toString() ?? '',
      onChanged: onChanged,
    ),
    CustomFieldTypes.checkbox => _MultiChoiceEditor(
      label: label,
      definition: definition,
      value: normalizeList(rawValue),
      onChanged: onChanged,
    ),
    CustomFieldTypes.pattern => _PatternEditor(
      label: label,
      definition: definition,
      value: normalizePattern(rawValue),
      onChanged: onChanged,
    ),
    // `text` y cualquier tipo nuevo del backend: se degrada a texto, nunca se
    // rompe el formulario (§9.1 y §11).
    _ => _TextEditor(
      label: label,
      definition: definition,
      value: rawValue,
      maxLength: 255,
      onChanged: onChanged,
    ),
  };
}

/// `text`, `textarea`, `number` y tipos desconocidos: caja de texto.
///
/// Con `numeric` el campo teclea números y emite `num?` (nunca el string `"12"`,
/// que el servidor guardaría degradado, §4).
class _TextEditor extends StatefulWidget {
  const _TextEditor({
    required this.label,
    required this.definition,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
    this.maxLength = 255,
    this.numeric = false,
  });

  final String label;
  final CustomFieldDefinition definition;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final int maxLines;
  final int maxLength;
  final bool numeric;

  @override
  State<_TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<_TextEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: _displayValue,
  );

  String get _displayValue {
    final value = widget.value;

    if (value == null) {
      return '';
    }

    return value is num ? '$value' : value.toString();
  }

  @override
  void didUpdateWidget(covariant _TextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Precarga de la orden: el valor llega después del primer build.
    final incoming = _displayValue;

    if (incoming != _controller.text) {
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EzyTextField(
      label: widget.label,
      isRequired: widget.definition.isRequired,
      controller: _controller,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      showCounter: true,
      keyboardType: widget.numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : null,
      onChanged: (raw) =>
          widget.onChanged(widget.numeric ? normalizeNumber(raw) : raw),
    );
  }
}

/// `boolean`: el switch arranca apagado y emite `true`/`false` reales (§4).
class _BooleanEditor extends StatelessWidget {
  const _BooleanEditor({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<Object?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: EzyTextStyles.bodyStrong.copyWith(
              color: SoColors.textPrimary(context),
            ),
          ),
        ),
        SoSwitch(
          value: value,
          onChanged: (next) => onChanged(next),
        ),
      ],
    );
  }
}

/// Aviso de los campos que no se pueden capturar todavía (§11).
class _NoOptionsNotice extends StatelessWidget {
  const _NoOptionsNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FieldLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: SoColors.inner(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SoColors.structuralBorder(context)),
          ),
          child: Text(
            'Sin opciones configuradas',
            style: EzyTextStyles.caption.copyWith(
              color: SoColors.textMuted(context),
            ),
          ),
        ),
      ],
    );
  }
}

/// Hoja con las `options` del `select` (mismo orden que devuelve la API).
Future<String?> showCustomFieldOptionSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String selected,
}) => EzyBottomSheet.show<String>(
  context,
  title: title,
  builder: (sheetContext) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final option in options)
          EzySelectableTile(
            title: option,
            isSelected: option == selected,
            onTap: () => Navigator.of(sheetContext).pop(option),
          ),
      ],
    ),
  ),
);

/// `select`: campo de solo lectura que abre la hoja de opciones.
///
/// Si el valor guardado ya no está en `options` (cambiaron las opciones) se
/// pinta tal cual y se avisa: la app **no** lo descarta (§4).
class _SelectEditor extends StatefulWidget {
  const _SelectEditor({
    required this.label,
    required this.definition,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final CustomFieldDefinition definition;
  final String value;
  final ValueChanged<Object?> onChanged;

  @override
  State<_SelectEditor> createState() => _SelectEditorState();
}

class _SelectEditorState extends State<_SelectEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _SelectEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final picked = await showCustomFieldOptionSheet(
      context,
      title: widget.label,
      options: widget.definition.options,
      selected: _controller.text,
    );

    if (picked == null) {
      return;
    }

    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.definition.hasNoOptions) {
      return _NoOptionsNotice(label: widget.label);
    }

    final orphan =
        widget.value.isNotEmpty &&
        !widget.definition.options.contains(widget.value);

    return EzyTextField(
      label: widget.label,
      isRequired: widget.definition.isRequired,
      controller: _controller,
      readOnly: true,
      onTap: _open,
      hint: 'Seleccionar',
      helperText: orphan ? 'Ya no está entre las opciones configuradas.' : null,
      suffix: Icon(
        Icons.expand_more,
        size: 20,
        color: SoColors.textMuted(context),
      ),
    );
  }
}

/// `checkbox`: chips múltiples con **todas** las `options` en su orden.
///
/// Un valor guardado que ya no está en `options` se agrega como chip extra para
/// no perderlo, y `[]` es válido («ninguno seleccionado»).
class _MultiChoiceEditor extends StatelessWidget {
  const _MultiChoiceEditor({
    required this.label,
    required this.definition,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final CustomFieldDefinition definition;
  final List<String> value;
  final ValueChanged<Object?> onChanged;

  List<String> get _choices => <String>[
    ...definition.options,
    ...value.where((item) => !definition.options.contains(item)),
  ];

  void _toggle(String option) {
    final next = value.contains(option)
        ? value.where((item) => item != option).toList(growable: false)
        : <String>[...value, option];

    onChanged(_choices.where(next.contains).toList(growable: false));
  }

  @override
  Widget build(BuildContext context) {
    if (definition.hasNoOptions) {
      return _NoOptionsNotice(label: label);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FieldLabel(label, isRequired: definition.isRequired),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final option in _choices)
              EzyChip(
                label: option,
                inner: true,
                compact: true,
                selected: value.contains(option),
                onTap: () => _toggle(option),
              ),
          ],
        ),
      ],
    );
  }
}

/// Modos del editor de desbloqueo (los mismos rótulos que la web, §8.5.1).
enum _PatternMode {
  pattern('Patrón'),
  password('Contraseña');

  const _PatternMode(this.label);

  final String label;
}

/// `pattern`: conmutador de modo + tablero 3×3 o contraseña escrita.
///
/// Emite **siempre** el objeto completo (§8.5.4): al limpiar o al cambiar de
/// modo manda `{'type':…,'value':[] | ''}`, nunca `null`.
class _PatternEditor extends StatefulWidget {
  const _PatternEditor({
    required this.label,
    required this.definition,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final CustomFieldDefinition definition;
  final PatternValue value;
  final ValueChanged<Object?> onChanged;

  @override
  State<_PatternEditor> createState() => _PatternEditorState();
}

class _PatternEditorState extends State<_PatternEditor> {
  late final TextEditingController _passwordController =
      TextEditingController(text: widget.value.password);

  @override
  void didUpdateWidget(covariant _PatternEditor oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.value.password != _passwordController.text) {
      _passwordController.text = widget.value.password;
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _changeMode(_PatternMode mode) {
    // Cambiar de modo descarta el valor anterior (igual que la web, §8.5.5).
    widget.onChanged(
      (mode == _PatternMode.password
              ? const PatternValue.password('')
              : const PatternValue.pattern(<int>[]))
          .toJson(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPassword = widget.value.mode == 'password';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FieldLabel(widget.label, isRequired: widget.definition.isRequired),
        const SizedBox(height: 8),
        ServiceOrderSegmentedControl<_PatternMode>(
          values: _PatternMode.values,
          selected: isPassword ? _PatternMode.password : _PatternMode.pattern,
          labelOf: (mode) => mode.label,
          onSelected: _changeMode,
        ),
        const SizedBox(height: 12),
        if (isPassword)
          EzyTextField(
            label: 'Contraseña del equipo',
            controller: _passwordController,
            maxLength: 32,
            showCounter: true,
            onChanged: (raw) =>
                widget.onChanged(PatternValue.password(raw).toJson()),
          )
        else ...<Widget>[
          Center(
            child: PatternInput(
              points: widget.value.points,
              onChanged: (points) =>
                  widget.onChanged(PatternValue.pattern(points).toJson()),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.value.points.isEmpty
                      ? 'Dibuja el patrón sobre los 9 puntos.'
                      : 'Puntos en orden: '
                            '${widget.value.points.join(' → ')}',
                  style: EzyTextStyles.caption.copyWith(
                    color: SoColors.textMuted(context),
                  ),
                ),
              ),
              if (widget.value.points.isNotEmpty)
                SoTextAction(
                  label: 'Limpiar',
                  icon: Icons.backspace_outlined,
                  onPressed: () => widget.onChanged(
                    const PatternValue.pattern(<int>[]).toJson(),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
