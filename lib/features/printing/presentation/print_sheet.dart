import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../application/printing_providers.dart';
import '../application/printer_controller.dart';
import '../data/models/print_document.dart';
import '../data/models/print_template.dart';
import '../data/whatsapp_message_builder.dart';
import 'widgets/print_template_picker.dart';
import 'widgets/printer_status_card.dart';
import 'widgets/ticket_html_sheet.dart';
import 'widgets/whatsapp_ticket_sheet.dart';

/// Acción que se ejecuta al abrir la hoja.
enum PrintSheetAction {
  /// Solo muestra las opciones (impresión, WhatsApp y respaldo HTML).
  print,
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

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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
    final labelTemplates =
        labelTemplatesAsync?.asData?.value == null
        ? const <PrintTemplate>[]
        : widget.document.selectLabelTemplates(
            labelTemplatesAsync!.asData!.value,
          );

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

    final canSubmit = printer.isAdapterOn && templateId != null && !job.isBusy;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'Imprimir y compartir',
            style: EzyTextStyles.screenTitle.copyWith(
              color: surfaces.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            <String>[
              widget.document.title,
              if (widget.document.subtitle.isNotEmpty) widget.document.subtitle,
            ].join(' · '),
            style: EzyTextStyles.secondary.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          _FeedbackSection(
            job: job,
            printer: printer,
            extraMessage: _whatsAppNotice,
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Impresora',
            trailing: _PrinterBadge(isConnected: printer.isConnected),
            child: const PrinterStatusCard(),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: widget.document.templateType == PrintTemplateType.label
                ? 'Plantilla de etiqueta'
                : 'Plantilla de impresión',
            child: templatesAsync.when(
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
                    : 'No se pudieron cargar las plantillas de impresión.',
                onRetry: () => ref.invalidate(
                  printTemplatesProvider(widget.document.templateType),
                ),
              ),
              data: (_) => PrintTemplatePicker(
                templates: templates,
                selectedId: templateId,
                onSelected: _selectTemplate,
                emptyMessage:
                    'El negocio no tiene una plantilla de '
                    '${widget.document.templateType.displayName.toLowerCase()} '
                    'para este documento. Se configura en la web.',
              ),
            ),
          ),
          if (templates.isNotEmpty &&
              widget.document.templateType ==
                  PrintTemplateType.saleTicket) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Cajón de dinero',
              child: Row(
                children: <Widget>[
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
                          'Envía el pulso de apertura junto con el ticket.',
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
                    onChanged: (value) => setState(() => _openDrawer = value),
                  ),
                ],
              ),
            ),
          ],
          if (widget.allowLabels && labelTemplates.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            SectionCard(
              title: 'Etiqueta',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  PrintTemplatePicker(
                    templates: labelTemplates,
                    selectedId: labelTemplateId,
                    onSelected: _selectLabelTemplate,
                  ),
                  const SizedBox(height: 12),
                  EzyButton(
                    label: 'Imprimir etiqueta',
                    icon: Icons.qr_code_2_outlined,
                    variant: EzyButtonVariant.outline,
                    isLoading: job.isSubmitting,
                    onPressed:
                        printer.isAdapterOn &&
                            labelTemplateId != null &&
                            !job.isBusy
                        ? () => _printLabel(labelTemplateId)
                        : null,
                  ),
                ],
              ),
            ),
          ],
          if (!printer.isAdapterOn) ...<Widget>[
            const SizedBox(height: 12),
            const NoticeBanner(
              message: 'Enciende el Bluetooth para imprimir el ticket.',
              tone: EzySeverity.warn,
            ),
          ],
          const SizedBox(height: 16),
          EzyButton(
            label: 'Imprimir ticket',
            icon: Icons.print_outlined,
            isLoading: job.isSubmitting,
            onPressed: canSubmit ? () => _printTicket(templateId) : null,
          ),
          const SizedBox(height: 8),
          EzyButton(
            label: 'Enviar por WhatsApp',
            icon: Icons.chat_outlined,
            variant: EzyButtonVariant.outline,
            isLoading: job.isFetchingWhatsApp,
            onPressed: job.isBusy ? null : _sendWhatsApp,
          ),
          const SizedBox(height: 8),
          EzyButton(
            label: 'Ver respaldo HTML',
            variant: EzyButtonVariant.text,
            onPressed: templateId == null || job.isBusy
                ? null
                : () => _openHtml(templateId),
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

    if (printed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Etiqueta enviada a la impresora.')),
      );
    }
  }

  Future<void> _openHtml(int templateId) async {
    final html = await ref
        .read(printJobProvider.notifier)
        .loadHtml(document: widget.document, templateId: templateId);

    if (html == null || !mounted) {
      return;
    }

    await showTicketHtmlSheet(context, html: html);
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
            'Puedes imprimirlo o usar el respaldo HTML.',
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

    if (extraMessage != null) {
      messages.add(const SizedBox(height: 12));
      messages.add(
        NoticeBanner(message: extraMessage!, tone: EzySeverity.info),
      );
    }

    if (job.notice != null) {
      messages.add(const SizedBox(height: 12));
      messages.add(
        NoticeBanner(
          message: job.notice!,
          tone: EzySeverity.success,
          icon: Icons.check_circle_outline,
          actionLabel: 'Ocultar',
          onAction: jobController.consumeNotice,
        ),
      );
    }

    if (job.errorMessage != null) {
      messages.add(const SizedBox(height: 12));
      messages.add(
        NoticeBanner(
          message: job.errorMessage!,
          actionLabel: 'Ocultar',
          onAction: jobController.consumeError,
        ),
      );
    }

    if (printer.errorMessage != null) {
      messages.add(const SizedBox(height: 12));
      messages.add(
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: messages,
    );
  }
}

/// Badge del estado de la impresora en la cabecera del panel.
class _PrinterBadge extends StatelessWidget {
  const _PrinterBadge({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) => StatusBadge(
    label: isConnected ? 'Conectada' : 'Sin conectar',
    severity: isConnected ? EzySeverity.success : EzySeverity.neutral,
  );
}

