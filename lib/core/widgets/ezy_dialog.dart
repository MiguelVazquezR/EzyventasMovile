import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'ezy_button.dart';
import 'ezy_text_field.dart';

/// Diálogo del design system (§4).
///
/// Sustituye a los `AlertDialog` sueltos: mismo panel, mismo radio 24 y mismo
/// borde de 1 px que las tarjetas y las hojas, y las acciones con los botones
/// del sistema. Casi siempre conviene usar [showEzyConfirmDialog] o
/// [showEzyPromptDialog]; [EzyDialog] se reserva para los casos con contenido
/// propio (el diálogo que pide un dato, por ejemplo).
class EzyDialog extends StatelessWidget {
  const EzyDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.actions = const <Widget>[],
  });

  final String title;

  /// Cuerpo del diálogo: el `message` del servidor o el microcopy aprobado.
  final String? message;

  /// Contenido propio bajo el mensaje (campos, importes…).
  final Widget? content;

  /// Botonera al pie; se reparte a lo ancho igual que en las hojas.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final hasBody = message != null || content != null;

    return Dialog(
      backgroundColor: surfaces.panel,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: surfaces.border),
      ),
      // El cuerpo se desplaza: con el teclado abierto o con texto grande el
      // diálogo nunca se sale de la pantalla.
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                title,
                style: EzyTextStyles.screenTitle.copyWith(
                  fontSize: 20,
                  color: surfaces.textPrimary,
                ),
              ),
              if (hasBody) const SizedBox(height: 10),
              if (message != null)
                Text(
                  message!,
                  style: EzyTextStyles.body.copyWith(color: surfaces.textBody),
                ),
              if (message != null && content != null)
                const SizedBox(height: 16),
              ?content,
              if (actions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 20),
                if (actions.length == 1)
                  actions.first
                else
                  Row(
                    children: <Widget>[
                      for (int i = 0; i < actions.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 12),
                        Expanded(child: actions[i]),
                      ],
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmación de dos botones.
///
/// Devuelve `true` **solo** si se confirmó (cerrar tocando fuera o "Cancelar"
/// devuelve `false`), así ninguna pantalla repite el `showDialog<bool>` con su
/// propio `AlertDialog`. Con [isDestructive] la acción principal va en rojo.
Future<bool> showEzyConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => EzyDialog(
      title: title,
      message: message,
      actions: <Widget>[
        EzyButton(
          label: cancelLabel,
          variant: EzyButtonVariant.outline,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        EzyButton(
          label: confirmLabel,
          variant: isDestructive
              ? EzyButtonVariant.danger
              : EzyButtonVariant.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

/// Pide un dato en un diálogo (la contraseña de "Cerrar otras sesiones", por
/// ejemplo) y devuelve el texto capturado, o `null` si se canceló.
///
/// El botón de confirmar **se habilita al escribir**: antes el diálogo se podía
/// cerrar con el campo vacío y la acción se descartaba en silencio.
Future<String?> showEzyPromptDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String fieldLabel,
  required String confirmLabel,
  String cancelLabel = 'Cancelar',
  String? hint,
  bool obscureText = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _EzyPromptDialog(
      title: title,
      message: message,
      fieldLabel: fieldLabel,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      hint: hint,
      obscureText: obscureText,
    ),
  );
}

class _EzyPromptDialog extends StatefulWidget {
  const _EzyPromptDialog({
    required this.title,
    required this.message,
    required this.fieldLabel,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.hint,
    required this.obscureText,
  });

  final String title;
  final String message;
  final String fieldLabel;
  final String confirmLabel;
  final String cancelLabel;
  final String? hint;
  final bool obscureText;

  @override
  State<_EzyPromptDialog> createState() => _EzyPromptDialogState();
}

class _EzyPromptDialogState extends State<_EzyPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _canSubmit = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }

    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return EzyDialog(
      title: widget.title,
      message: widget.message,
      actions: <Widget>[
        EzyButton(
          label: widget.cancelLabel,
          variant: EzyButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        EzyButton(
          label: widget.confirmLabel,
          onPressed: _canSubmit ? _submit : null,
        ),
      ],
      content: EzyTextField(
        label: widget.fieldLabel,
        controller: _controller,
        hint: widget.hint,
        obscureText: widget.obscureText,
        autofocus: true,
        isRequired: true,
        textInputAction: TextInputAction.done,
        onChanged: (value) =>
            setState(() => _canSubmit = value.trim().isNotEmpty),
        onSubmitted: (_) => _submit(),
      ),
    );
  }
}
