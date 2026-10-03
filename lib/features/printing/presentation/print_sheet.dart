import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/ezy_icon_button.dart';
import '../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../application/printing_providers.dart';
import '../application/printer_controller.dart';
import '../data/models/print_document.dart';
import '../data/models/print_template.dart';
import '../data/whatsapp_message_builder.dart';
import 'widgets/print_template_picker.dart';
import 'widgets/printer_status_card.dart';
import 'widgets/whatsapp_ticket_sheet.dart';

/// Acción que se ejecuta al abrir la hoja.
enum PrintSheetAction {
  /// Solo muestra las opciones (impresión y WhatsApp).
  print,

  /// Abre directamente la previsualización de WhatsApp.
  whatsApp,
}

/// Imprime o envía por WhatsApp un documento ya registrado en el servidor.
///
/// Se ofrece al cobrar, al abonar, al cerrar caja y desde el detalle de venta,
/// pedido y orden de servicio. La plantilla la elige el usuario una sola vez:
/// se guarda por tipo para la próxima impresión.
Future<void> showPrintSheet(
  BuildContext context, {
  required PrintDocument document,
  bool allowLabels = false,
  PrintSheetAction initialAction = PrintSheetAction.print,
}) {
  if (!document.isValid) {
    return Future<void>.value();
  }

  return EzyBottomSheet.show<void>(
    context,
    // La hoja es larga (impresora, plantillas, cajón y etiqueta): se acota al
    // 96 % para que el pie con el CTA siga a la vista. El asa, el panel de fondo
    // y las esquinas las pinta el tema.
    maxHeightFactor: 0.96,
    builder: (sheetContext) => PrintSheet(
      document: document,
      allowLabels: allowLabels,
      initialAction: initialAction,
    ),
  );
}

class PrintSheet extends ConsumerStatefulWidget {
  const PrintSheet({
    super.key,
    required this.document,
    this.allowLabels = false,
    this.initialAction = PrintSheetAction.print,
  });

  final PrintDocument document;

  /// Ofrece la impresión de etiqueta (TSPL) además del ticket.
  final bool allowLabels;

  /// Acción que se dispara al abrir (p. ej. WhatsApp desde el detalle de venta).
  final PrintSheetAction initialAction;

  @override
  ConsumerState<PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends ConsumerState<PrintSheet> {
  int? _selectedTemplateId;
  int? _savedTemplateId;
  int? _selectedLabelTemplateId;
  int? _savedLabelTemplateId;
  bool _openDrawer = false;

  /// El servidor no generó el ticket de WhatsApp para este documento.
  String? _whatsAppNotice;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restorePreferences);

    if (widget.initialAction == PrintSheetAction.whatsApp) {
      Future<void>.microtask(_sendWhatsApp);
    }
  }

  /// Recuerda la plantilla usada la última vez para este tipo de documento.
  Future<void> _restorePreferences() async {
    final preferences = ref.read(printerPreferencesProvider);

    final saved = await preferences.readTemplateId(
      widget.document.templateType.wire,
    );
    final savedLabel = widget.allowLabels
        ? await preferences.readTemplateId(PrintTemplateType.label.wire)
        : null;

    if (!mounted) {
      return;
    }

    setState(() {
      _savedTemplateId = saved;
      _savedLabelTemplateId = savedLabel;
    });
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final job = ref.watch(printJobProvider);
    final printer = ref.watch(printerControllerProvider);

    final templatesAsync = ref.watch(
      printTemplatesProvider(widget.document.templateType),
    );

    final labelTemplatesAsync = widget.allowLabels
        ? ref.watch(printTemplatesProvider(PrintTemplateType.label))
        : null;

    // La API solo filtra por un contexto: el conjunto de contextos válidos lo
    // aplica el documento (igual que la web).
    final templates = widget.document.selectTemplates(
      templatesAsync.asData?.value ?? const <PrintTemplate>[],
    );
    final labelValues = labelTemplatesAsync?.asData?.value;
    final labelTemplates = labelValues == null
        ? const <PrintTemplate>[]
        : widget.document.selectLabelTemplates(labelValues);

    final templateId = resolvePrintTemplateId(
      templates,
      _selectedTemplateId,
      _savedTemplateId,
    );
    final labelTemplateId = resolvePrintTemplateId(
      labelTemplates,
      _selectedLabelTemplateId,
      _savedLabelTemplateId,
    );

    // Sin plantilla, sin Bluetooth o con un trabajo en curso no hay nada que
    // enviar: el CTA queda apagado y el pie lo deja ver.
    final canSubmit = printer.isAdapterOn && templateId != null && !job.isBusy;
    final canSubmitLabel =
        printer.isAdapterOn && labelTemplateId != null && !job.isBusy;
    final isLabel = widget.document.templateType == PrintTemplateType.label;

    return SizedBox(
      // La hoja ocupa el 85 % de la pantalla: el resto se toca para cerrarla.
      // El contenido se desplaza por dentro, así que el pie nunca se mueve.
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: <Widget>[
          EzySheetHeader(
            title: 'Imprimir y compartir',
            subtitle: <String>[
              widget.document.title,
              if (widget.document.subtitle.isNotEmpty) widget.document.subtitle,
            ].join(' · '),
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 14),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _FeedbackSection(
                    job: job,
                    printer: printer,
                    extraMessage: _whatsAppNotice,
                  ),
                  // El estado de la impresora va primero: sin ella no hay nada
                  // que enviar. Es contenido plano, la caja la pone la card.
                  SectionCard(
                    inner: true,
                    padding: const EdgeInsets.all(14),
                    title: 'Impresora',
                    child: const PrinterStatusCard(),
                  ),
                  const SizedBox(height: 12),
                  // La lista de plantillas no lleva card: cada fila del design
                  // system ya es una tarjeta con su contenedor y su borde.
                  templatesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (error, _) => ErrorNotice(
                      message: error is ApiException
                          ? error.message
                          : 'No se pudieron cargar las plantillas de '
                                'impresión.',
                      onRetry: () => ref.invalidate(
                        printTemplatesProvider(widget.document.templateType),
                      ),
                    ),
                    data: (_) => PrintTemplatePicker(
                      templates: templates,
                      selectedId: templateId,
                      onSelected: _selectTemplate,
                      title: isLabel
                          ? 'PLANTILLA DE ETIQUETA'
                          : 'PLANTILLA DE IMPRESIÓN',
                      emptyMessage:
                          'El negocio no tiene una plantilla de '
                          '${widget.document.templateType.displayName.toLowerCase()} '
                          'para este documento. Se configura en la web.',
                    ),
                  ),
                  if (templates.isNotEmpty &&
                      widget.document.templateType ==
                          PrintTemplateType.saleTicket) ...<Widget>[
                    const SizedBox(height: 12),
                    SectionCard(
                      inner: true,
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                      title: 'Cajón de dinero',
                      child: Row(
                        children: <Widget>[
                          // Cuadro del icono (gaveta), como en las filas del
                          // design system: identifica la sección de un vistazo.
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: surfaces.panel,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: surfaces.border),
                            ),
                            child: Icon(
                              Icons.point_of_sale_outlined,
                              size: 17,
                              color: surfaces.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Abrir el cajón al imprimir',
                                  style: EzyTextStyles.bodyStrong.copyWith(
                                    color: surfaces.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Envía el pulso de apertura junto con el '
                                  'ticket.',
                                  style: EzyTextStyles.caption.copyWith(
                                    color: surfaces.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Switch(
                            value: _openDrawer,
                            // El interruptor se enciende con el naranja de
                            // marca: es la acción destacada de la card.
                            activeThumbColor: Colors.white,
                            activeTrackColor: EzyColors.primary,
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: surfaces.borderStrong,
                            onChanged: (value) =>
                                setState(() => _openDrawer = value),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (widget.allowLabels &&
                      labelTemplates.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 12),
                    SectionCard(
                      inner: true,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // Cabecera propia: el título de card no admite ni el
                          // sello QR ni el badge del material.
                          const _LabelSectionHeader(),
                          const SizedBox(height: 12),
                          // Las etiquetas viven dentro de su card: filas
                          // compactas para no anidar contenedores.
                          PrintTemplatePicker(
                            templates: labelTemplates,
                            selectedId: labelTemplateId,
                            onSelected: _selectLabelTemplate,
                            title: null,
                            compact: true,
                          ),
                          const SizedBox(height: 6),
                          EzyButton(
                            label: 'Imprimir etiqueta QR',
                            icon: Icons.qr_code_2_outlined,
                            variant: EzyButtonVariant.outline,
                            isLoading: job.isSubmitting,
                            onPressed: canSubmitLabel
                                ? () => _printLabel(labelTemplateId)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _SheetActionBar(
            label: isLabel ? 'Imprimir etiqueta' : 'Imprimir ticket',
            isPrinting: job.isSubmitting,
            onPrint: canSubmit ? () => _printTicket(templateId) : null,
            isSendingWhatsApp: job.isFetchingWhatsApp,
            onWhatsApp: job.isBusy ? null : _sendWhatsApp,
          ),
        ],
      ),
    );
  }

  /// Guarda la plantilla elegida para la próxima impresión del mismo tipo.
  void _selectTemplate(PrintTemplate template) {
    setState(() => _selectedTemplateId = template.id);

    ref
        .read(printerPreferencesProvider)
        .saveTemplateId(widget.document.templateType.wire, template.id);
  }

  void _selectLabelTemplate(PrintTemplate template) {
    setState(() => _selectedLabelTemplateId = template.id);

    ref
        .read(printerPreferencesProvider)
        .saveTemplateId(PrintTemplateType.label.wire, template.id);
  }

  Future<void> _printTicket(int templateId) async {
    final printed = await ref
        .read(printJobProvider.notifier)
        .printDocument(
          document: widget.document,
          templateId: templateId,
          openDrawer: _openDrawer,
        );

    if (printed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket enviado a la impresora.')),
      );
    }
  }

  Future<void> _printLabel(int templateId) async {
    final printed = await ref
        .read(printJobProvider.notifier)
        .printLabel(document: widget.document, templateId: templateId);

    if (!printed || !mounted) {
      return;
    }

    final warning = ref.read(printJobProvider).warningMessage;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(warning ?? 'Etiqueta enviada a la impresora.')),
    );
  }

  /// Pide el ticket al servidor y abre la previsualización de WhatsApp.
  Future<void> _sendWhatsApp() async {
    setState(() => _whatsAppNotice = null);

    final result = await ref
        .read(printJobProvider.notifier)
        .loadWhatsAppTicket(document: widget.document);

    if (result == null || !mounted) {
      return;
    }

    if (result.isEmpty) {
      setState(
        () => _whatsAppNotice =
            'El servidor no generó el ticket de WhatsApp para este documento. '
            'Puedes imprimirlo desde esta misma hoja.',
      );

      return;
    }

    await showWhatsAppMessageSheet(
      context,
      message: WhatsAppMessageBuilder.build(result.ticket!),
      phone: result.customerPhone,
      subtitle: widget.document.subtitle.isEmpty
          ? null
          : widget.document.subtitle,
    );
  }
}

/// Plantilla implícita: la elegida, la guardada o la predeterminada del negocio.
int? resolvePrintTemplateId(
  List<PrintTemplate> templates,
  int? selectedId,
  int? savedId,
) {
  if (templates.isEmpty) {
    return null;
  }

  for (final candidate in <int?>[selectedId, savedId]) {
    if (candidate == null) {
      continue;
    }

    for (final template in templates) {
      if (template.id == candidate) {
        return candidate;
      }
    }
  }

  for (final template in templates) {
    if (template.isDefault) {
      return template.id;
    }
  }

  return templates.first.id;
}

/// Avisos del trabajo de impresión y de la impresora.
///
/// Van arriba del todo, cuando los hay: es lo único que el usuario tiene que
/// leer antes de volver a pulsar el CTA. Sin avisos no ocupa nada.
class _FeedbackSection extends ConsumerWidget {
  const _FeedbackSection({
    required this.job,
    required this.printer,
    this.extraMessage,
  });

  final PrintJobState job;
  final PrinterState printer;
  final String? extraMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobController = ref.read(printJobProvider.notifier);
    final printerController = ref.read(printerControllerProvider.notifier);

    final messages = <Widget>[];

    // Un aviso tras otro con su aire, sin depender de que sean uno o varios.
    void add(Widget banner) {
      if (messages.isNotEmpty) {
        messages.add(const SizedBox(height: 12));
      }
      messages.add(banner);
    }

    if (extraMessage != null) {
      add(NoticeBanner(message: extraMessage!, tone: EzySeverity.info));
    }

    if (job.notice != null) {
      add(
        NoticeBanner(
          message: job.notice!,
          tone: EzySeverity.success,
          icon: Icons.check_circle_outline,
          actionLabel: 'Ocultar',
          onAction: jobController.consumeNotice,
        ),
      );
    }

    if (job.warningMessage != null) {
      add(
        NoticeBanner(
          message: job.warningMessage!,
          tone: EzySeverity.warn,
          actionLabel: 'Ocultar',
          onAction: jobController.consumeWarning,
        ),
      );
    }

    if (job.errorMessage != null) {
      add(
        NoticeBanner(
          message: job.errorMessage!,
          actionLabel: 'Ocultar',
          onAction: jobController.consumeError,
        ),
      );
    }

    if (printer.errorMessage != null) {
      add(
        NoticeBanner(
          message: printer.errorMessage!,
          actionLabel: 'Ocultar',
          onAction: printerController.consumeError,
        ),
      );
    }

    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    // El bloque se separa él solo de la primera tarjeta de la hoja.
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: messages,
      ),
    );
  }
}

/// Cabecera de la sección «Etiqueta»: sello QR, micro-etiqueta y badge del
/// material (adhesiva).
///
/// El título de [SectionCard] no admite iconos ni insignias, así que la fila se
/// pinta aquí y la card queda sin cabecera.
class _LabelSectionHeader extends StatelessWidget {
  const _LabelSectionHeader();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: EzyColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: EzyColors.primary.withValues(alpha: 0.3)),
          ),
          child: const Icon(
            Icons.qr_code_2_outlined,
            size: 16,
            color: EzyColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'ETIQUETA ADHESIVA',
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.microLabel.copyWith(color: surfaces.textBody),
          ),
        ),
        const SizedBox(width: 8),
        // El material no es un estado: se marca con el naranja de marca, como
        // el resto de las insignias de la hoja.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: EzyColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: EzyColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            'ADHESIVA',
            style: EzyTextStyles.badge.copyWith(color: EzyColors.primary),
          ),
        ),
      ],
    );
  }
}

/// Pie fijo de la hoja: el CTA de la impresión y el envío por WhatsApp.
///
/// No se desplaza con el contenido: con la hoja llena de plantillas el botón
/// que cierra la tarea tiene que seguir a la vista.
class _SheetActionBar extends StatelessWidget {
  const _SheetActionBar({
    required this.label,
    required this.onPrint,
    required this.isPrinting,
    required this.onWhatsApp,
    required this.isSendingWhatsApp,
  });

  final String label;
  final VoidCallback? onPrint;
  final bool isPrinting;
  final VoidCallback? onWhatsApp;
  final bool isSendingWhatsApp;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        // Panel «glass»: el pie se pega al borde inferior de la hoja dejando
        // traslucir el tono del panel que hay detrás.
        color: surfaces.panel.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: surfaces.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // El CTA de la hoja es el mismo botón con relieve del cobro, a lo
          // ancho de la hoja.
          EzyPrimary3dButton(
            label: label,
            icon: Icons.print_outlined,
            height: 56,
            maxWidth: double.infinity,
            isLoading: isPrinting,
            onPressed: onPrint,
          ),
          const SizedBox(height: 8),
          EzyButton(
            label: 'Enviar por WhatsApp',
            icon: Icons.chat_outlined,
            variant: EzyButtonVariant.whatsApp,
            isLoading: isSendingWhatsApp,
            onPressed: onWhatsApp,
          ),
        ],
      ),
    );
  }
}
