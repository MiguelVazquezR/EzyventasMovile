import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../data/whatsapp_message_builder.dart';

/// Previsualización del mensaje de WhatsApp antes de abrirlo.
///
/// El texto ya viene formateado (lo arma el servidor para ventas, abonos y
/// pedidos, o [WhatsAppMessageBuilder] para el corte de caja); aquí solo se
/// muestra, se copia y se abre `wa.me`.
///
/// La hoja es de **altura fija** (85 % de la pantalla, con el tope del 96 % que
/// pone [EzyBottomSheet]): el asa, la cabecera y la barra de acciones no se
/// mueven y solo el ticket hace scroll. El asa y los dos botones se pintan a
/// mano porque el rediseño pide un relieve físico en el CTA verde y una
/// cabecera con el teléfono resaltado que [EzySheetHeader] no cubre.
Future<void> showWhatsAppMessageSheet(
  BuildContext context, {
  required String message,
  String? phone,
  String? title,
  String? subtitle,
}) {
  return EzyBottomSheet.show<void>(
    context,
    // La hoja se apoya en su propio panel (`#232323`), no en el lienzo gris de
    // las hojas del POS.
    backgroundColor: context.surfaces.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    // El asa la pinta la hoja (40 × 5 px, con su color por modo).
    showDragHandle: false,
    // El alto de trabajo es el 85 % de la pantalla; el tope del 96 % lo acota
    // la propia hoja, que es quien conoce el alto real de la superficie.
    maxHeightFactor: 0.96,
    builder: (sheetContext) => _WhatsAppMessageSheet(
      message: message,
      phone: phone,
      title: title ?? 'Enviar por WhatsApp',
      subtitle: subtitle,
    ),
  );
}

class _WhatsAppMessageSheet extends StatefulWidget {
  const _WhatsAppMessageSheet({
    required this.message,
    required this.phone,
    required this.title,
    required this.subtitle,
  });

  final String message;
  final String? phone;
  final String title;
  final String? subtitle;

  @override
  State<_WhatsAppMessageSheet> createState() => _WhatsAppMessageSheetState();
}

class _WhatsAppMessageSheetState extends State<_WhatsAppMessageSheet> {
  /// El lanzamiento falló: el banner no lleva el error crudo de la plataforma,
  /// así que basta con saber que hay que mostrarlo.
  bool _openFailed = false;

  @override
  Widget build(BuildContext context) {
    final phone = (widget.phone ?? '').trim();

    return SizedBox(
      width: double.infinity,
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: <Widget>[
          const _SheetDragHandle(),
          _SheetHeader(
            title: widget.title,
            documentSubtitle: widget.subtitle,
            phone: phone.isEmpty ? null : phone,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_openFailed) ...<Widget>[
                    _OpenErrorBanner(onDismiss: _dismissError),
                    const SizedBox(height: 12),
                  ],
                  _MessageCard(message: widget.message),
                ],
              ),
            ),
          ),
          _SheetActionBar(onOpen: _openWhatsApp, onCopy: _copyMessage),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final link = WhatsAppMessageBuilder.link(
      phone: widget.phone,
      message: widget.message,
    );

    try {
      final opened = await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _showError();
      }
    } on Object {
      _showError();
    }
  }

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: widget.message));

    if (!mounted) {
      return;
    }

    final surfaces = context.surfaces;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: surfaces.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: surfaces.borderStrong),
        ),
        content: Row(
          children: <Widget>[
            const Icon(Icons.check_circle, size: 16, color: EzyColors.success),
            const SizedBox(width: 8),
            Text(
              'Mensaje copiado.',
              style: TextStyle(
                fontFamily: EzyTextStyles.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: surfaces.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError() {
    if (mounted) {
      setState(() => _openFailed = true);
    }
  }

  void _dismissError() {
    setState(() => _openFailed = false);
  }
}

/// Asa de arrastre de la hoja: píldora de 40 × 5 px, centrada.
class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 40,
      height: 5,
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? EzyColors.gray77 : EzyColors.gray9A,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/// Cabecera: título, a quién se le abrirá WhatsApp y el documento de origen.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.documentSubtitle,
    required this.phone,
  });

  final String title;

  /// Micro-etiqueta del documento que se envía (`Folio: #F-10482 · Transacción
  /// liquidada`, `Corte de caja #C-004 · Turno cerrado`).
  final String? documentSubtitle;

  /// Teléfono del cliente; `null` cuando no tiene.
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final subtitle = documentSubtitle;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: surfaces.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: EzyTextStyles.fontFamily,
                    fontSize: 17.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    color: surfaces.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                _RecipientLine(phone: phone),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: EzyTextStyles.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                      color: surfaces.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          EzyIconButton(
            icon: Icons.close,
            tooltip: 'Cerrar',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Línea del destinatario: con teléfono lo nombra (resaltado en verde) y sin él
/// avisa de que WhatsApp pedirá elegir el contacto.
class _RecipientLine extends StatelessWidget {
  const _RecipientLine({required this.phone});

  final String? phone;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final base = TextStyle(
      fontFamily: EzyTextStyles.fontFamily,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: surfaces.textSecondary,
    );
    final phone = this.phone;

    if (phone == null) {
      return Text(
        'El cliente no tiene teléfono: se abrirá WhatsApp para que elijas el '
        'contacto',
        style: base,
      );
    }

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          const TextSpan(text: 'Se abrirá WhatsApp con el mensaje listo para '),
          TextSpan(
            text: phone,
            style: base.copyWith(
              fontWeight: FontWeight.w800,
              color: EzyColors.success,
            ),
          ),
        ],
      ),
      style: base,
    );
  }
}


/// Banner de error de `launchUrl`: solo se pinta cuando WhatsApp no se abrió.
class _OpenErrorBanner extends StatelessWidget {
  const _OpenErrorBanner({required this.onDismiss});

  final VoidCallback onDismiss;

  /// El aviso lo fija el design system, no el error crudo de la plataforma.
  static const String title = 'No se pudo abrir WhatsApp';
  static const String help =
      'Verifica que WhatsApp esté instalado en tu dispositivo o copia el '
      'mensaje manualmente.';

  @override
  Widget build(BuildContext context) {
    // El tono legible de la severidad sobre el fondo al 12 % (`StatusPalette`).
    final color = StatusPalette.text(context, EzySeverity.danger);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StatusPalette.soft(EzySeverity.danger),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: StatusPalette.border(EzySeverity.danger)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(help, style: EzyTextStyles.caption.copyWith(color: color)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'Ocultar',
              style: EzyTextStyles.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
                decoration: TextDecoration.underline,
                decorationColor: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card plana con el ticket tal cual se va a enviar.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: surfaces.border),
        // Plana a propósito (`boxShadow: null`): el ticket no compite con el
        // fondo de la hoja.
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: surfaces.border)),
            ),
            child: Row(
              children: <Widget>[
                // El punto de vista previa es fijo a propósito: el latido sin
                // fin impediría que `pumpAndSettle` de los tests llegue a
                // asentarse. El estado «vivo» lo comunica el propio texto.
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: EzyColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'VISTA PREVIA DEL TICKET',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: EzyTextStyles.fontFamily,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: surfaces.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Texto seleccionable',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: EzyTextStyles.fontFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: surfaces.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              message,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.35,
                color: surfaces.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Barra de acciones fija al pie de la hoja (fuera del scroll).
class _SheetActionBar extends StatelessWidget {
  const _SheetActionBar({required this.onOpen, required this.onCopy});

  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: surfaces.panel,
        border: Border(top: BorderSide(color: surfaces.border)),
      ),
      child: Column(
        children: <Widget>[
          _WhatsAppCta(onPressed: onOpen),
          const SizedBox(height: 10),
          _CopyMessageButton(onPressed: onCopy),
        ],
      ),
    );
  }
}

/// CTA verde de WhatsApp con relieve físico (bisel de tres caras y doble sombra).
class _WhatsAppCta extends StatefulWidget {
  const _WhatsAppCta({required this.onPressed});

  final VoidCallback onPressed;

  /// Radio de las esquinas del CTA.
  static const double radius = 16;

  /// Alto del botón (el rediseño pide 44–48 px para el CTA de la hoja).
  static const double height = 46;

  /// Caras del degradado: filo iluminado, verde oficial y base con profundidad.
  static const List<Color> gradientColors = <Color>[
    Color(0xFF32E773),
    EzyColors.whatsApp, // Verde oficial de WhatsApp (#25D366)
    Color(0xFF1EB855),
  ];

  /// Bisel: filo blanco al 45 % arriba, base oscura de 2 px abajo y canto tenue
  /// a los lados (`Colors.white` al 12 %).
  static const Border bevel = Border(
    top: BorderSide(color: Color(0x73FFFFFF)),
    bottom: BorderSide(color: Color(0xFF14803A), width: 2),
    left: BorderSide(color: Color(0x1FFFFFFF)),
    right: BorderSide(color: Color(0x1FFFFFFF)),
  );

  /// Relieve: base sólida pegada al borde inferior y glow del verde de marca
  /// (`#25D366` al 35 %).
  static const List<BoxShadow> relief = <BoxShadow>[
    BoxShadow(color: Color(0xFF137434), offset: Offset(0, 3)),
    BoxShadow(color: Color(0x5925D366), offset: Offset(0, 6), blurRadius: 18),
  ];

  @override
  State<_WhatsAppCta> createState() => _WhatsAppCtaState();
}

class _WhatsAppCtaState extends State<_WhatsAppCta> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _setPressed(true),
      onTapUp: (details) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        width: double.infinity,
        height: _WhatsAppCta.height,
        // El botón se hunde 3 px: la sombra sólida queda a ras de la hoja.
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _WhatsAppCta.gradientColors,
            stops: <double>[0.0, 0.52, 1.0],
          ),
          borderRadius: BorderRadius.circular(_WhatsAppCta.radius),
          boxShadow: _pressed ? null : _WhatsAppCta.relief,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_WhatsAppCta.radius),
          // El bisel va en una caja interior sin radio: un borde de colores
          // distintos dentro de una caja con `borderRadius` dispara la aserción
          // «A borderRadius can only be given on borders with uniform colors.»,
          // que además corta el `paint` antes de dibujar la etiqueta.
          child: const DecoratedBox(
            decoration: BoxDecoration(border: _WhatsAppCta.bevel),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.chat, size: 18, color: EzyColors.black1),
                  SizedBox(width: 8),
                  Text(
                    'Abrir WhatsApp',
                    style: TextStyle(
                      fontFamily: EzyTextStyles.fontFamily,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: EzyColors.black1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }
}

/// Variante outline neutra: copia el mensaje completo al portapapeles.
class _CopyMessageButton extends StatelessWidget {
  const _CopyMessageButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: surfaces.textPrimary,
          side: BorderSide(color: surfaces.borderStrong),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.copy_outlined, size: 16, color: EzyColors.primary),
            const SizedBox(width: 8),
            Text(
              'Copiar mensaje',
              style: TextStyle(
                fontFamily: EzyTextStyles.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: surfaces.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

