import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/evidence_image.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../application/service_orders_controller.dart';
import '../../data/models/service_order_detail.dart';
import 'evidence_photo_strip.dart';
import 'evidence_picker_row.dart';
import 'service_order_labels.dart';

/// Sugerencias de redacción del diagnóstico (§D del rediseño).
///
/// Se ofrecen mientras el campo está en blanco —con el técnico escribiendo,
/// estorban— y se insertan enteras: el técnico después las ajusta.
const List<String> _diagnosisTemplates = <String>[
  'Se reemplaza la pieza dañada',
  'Batería con desgaste, se reemplaza',
  'Equipo sin daño por humedad',
  'Se limpia y se prueba el funcionamiento',
];

/// Diagnóstico del técnico con evidencias de cierre
/// (`POST /service-orders/{id}/diagnosis`, multipart).
///
/// Reglas del contrato que la UI respeta: el máximo es de 5 fotos **por
/// petición**, las fotos se agregan a `closing-service-order-evidence` (el
/// servidor no borra: la hoja tampoco) y un diagnóstico vacío **borra** el
/// texto anterior.
Future<void> showServiceOrderDiagnosisSheet(
  BuildContext context, {
  required ServiceOrderDetail detail,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ServiceOrderDiagnosisSheet(detail: detail),
  );
}

class _ServiceOrderDiagnosisSheet extends ConsumerStatefulWidget {
  const _ServiceOrderDiagnosisSheet({required this.detail});

  final ServiceOrderDetail detail;

  @override
  ConsumerState<_ServiceOrderDiagnosisSheet> createState() =>
      _ServiceOrderDiagnosisSheetState();
}

class _ServiceOrderDiagnosisSheetState
    extends ConsumerState<_ServiceOrderDiagnosisSheet> {
  late final TextEditingController _diagnosisController = TextEditingController(
    text: widget.detail.technicianDiagnosis ?? '',
  );

  final List<EvidenceImage> _photos = <EvidenceImage>[];
  bool _isPicking = false;

  /// Diagnóstico que ya tenía la orden al abrir la hoja: mientras exista se
  /// avisa que guardar en blanco lo borra (`diagnosis: ''` del contrato §9).
  late final String _savedDiagnosis = (widget.detail.technicianDiagnosis ?? '')
      .trim();

  /// Fotos que todavía acepta esta petición (las del servidor no cuentan: la
  /// hoja solo envía las nuevas).
  int get _remaining => AppConfig.maxEvidenceImages - _photos.length;

  /// El contador de fotos y el aviso de borrado dependen de lo escrito, así que
  /// la hoja se reconstruye con cada tecla del diagnóstico.
  bool get _showTemplates => _diagnosisController.text.trim().isEmpty;

  @override
  void initState() {
    super.initState();
    _diagnosisController.addListener(_onDiagnosisChanged);
  }

  @override
  void dispose() {
    _diagnosisController.removeListener(_onDiagnosisChanged);
    _diagnosisController.dispose();
    super.dispose();
  }

  void _onDiagnosisChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _isPicking = true);

    final picked = await captureEvidence(
      context,
      source: source,
      remaining: _remaining,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _photos.addAll(picked);
      _isPicking = false;
    });
  }

  /// Insertar la sugerencia entera y dejar el cursor al final para editarla.
  void _applyTemplate(String template) {
    _diagnosisController.value = TextEditingValue(
      text: template,
      selection: TextSelection.collapsed(offset: template.length),
    );
  }

  Future<void> _submit() async {
    // El aviso de éxito lo muestra la pantalla que abrió la hoja: el
    // `ScaffoldMessenger` se toma antes de cerrarla, cuando el contexto de la
    // hoja todavía puede resolverlo.
    final messenger = ScaffoldMessenger.of(context);

    final saved = await ref
        .read(serviceOrderDetailControllerProvider.notifier)
        .saveDiagnosis(
          diagnosis: _diagnosisController.text.trim(),
          images: _photos,
        );

    if (!mounted || !saved) {
      return;
    }

    final notice = ref.read(serviceOrderDetailControllerProvider).notice;

    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        // Verde de confirmación con texto oscuro: mismo relleno pleno que el
        // botón de WhatsApp y el contraste que exige el §13.
        backgroundColor: StatusPalette.base(EzySeverity.success),
        content: Text(
          notice ?? 'Diagnóstico y evidencias guardados correctamente.',
          style: EzyTextStyles.body.copyWith(color: EzyColors.black1),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final state = ref.watch(serviceOrderDetailControllerProvider);
    // El detalle del controlador se usa solo si es de **esta** orden: una hoja
    // abierta antes de cargar el detalle no puede pintar datos de otra orden.
    final detail = state.belongsTo(widget.detail.id)
        ? (state.detail ?? widget.detail)
        : widget.detail;
    final hadDiagnosis = _savedDiagnosis.isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
          _DiagnosisEyebrow(technician: detail.technicianName),
          const SizedBox(height: 6),
          EzySheetHeader(
            title: 'Diagnóstico',
            subtitle:
                'Folio ${widget.detail.folio} · '
                '${widget.detail.itemDescription}',
            trailing: EzyIconButton(
              icon: Icons.close,
              tooltip: 'Cerrar',
              onTap: () => Navigator.of(context).pop(),
            ),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          if (state.errorMessage != null) ...<Widget>[
            NoticeBanner(
              message: state.errorMessage!,
              actionLabel: 'Ocultar',
              onAction: ref
                  .read(serviceOrderDetailControllerProvider.notifier)
                  .consumeError,
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: 'Diagnóstico del técnico',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                EzyTextField(
                  label: 'Diagnóstico',
                  controller: _diagnosisController,
                  maxLines: 5,
                  maxLength: 1000,
                  hint: 'Ej. Display dañado y batería al 62 %.',
                  helperText: hadDiagnosis
                      ? 'Si lo dejas vacío, el diagnóstico anterior se '
                            'borrará.'
                      : null,
                ),
                if (_showTemplates) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    'Sugerencias',
                    style: EzyTextStyles.microLabel.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Filas de ancho completo en lugar de chips: una frase entera
                  // se desborda dentro de un chip cuando el ancho de la letra
                  // crece (`textScale` grande) y el texto de un chip no es
                  // flex.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final template in _diagnosisTemplates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DiagnosisSuggestionRow(
                            label: template,
                            onTap: () => _applyTemplate(template),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Evidencias de cierre',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (detail.closingEvidence.isNotEmpty) ...<Widget>[
                  Text(
                    'Ya guardadas '
                    '(${ServiceOrderLabels.photos(detail.closingEvidence.length)})',
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  EvidenceMediaStrip(items: detail.closingEvidence),
                  const SizedBox(height: 6),
                  Text(
                    'Solo lectura: el servidor solo agrega evidencias, no las '
                    'borra.',
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_photos.isNotEmpty) ...<Widget>[
                  DraftEvidenceStrip(
                    images: _photos,
                    onRemove: (index) =>
                        setState(() => _photos.removeAt(index)),
                  ),
                  const SizedBox(height: 16),
                ],
                EvidencePickerRow(
                  remaining: _remaining,
                  isBusy: _isPicking,
                  onCamera: () => _pick(ImageSource.camera),
                  onGallery: () => _pick(ImageSource.gallery),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          EzyButton(
            label: 'Guardar diagnóstico',
            icon: Icons.save_outlined,
            isLoading: state.isSubmitting,
            onPressed: state.isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

/// Sugerencia de redacción del diagnóstico: fila de ancho completo.
///
/// No es un chip a propósito: el texto de un chip no es flex y una frase entera
/// se desborda en cuanto el ancho de la letra crece (`textScale` grande).
class _DiagnosisSuggestionRow extends StatelessWidget {
  const _DiagnosisSuggestionRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surfaces.panelInner,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surfaces.border),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.add, size: 16, color: EzyColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: EzyTextStyles.body.copyWith(color: surfaces.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renglón de contexto de la hoja: de quién es el diagnóstico que se edita.
class _DiagnosisEyebrow extends StatelessWidget {
  const _DiagnosisEyebrow({required this.technician});

  final String? technician;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final name = (technician ?? '').trim();

    return Row(
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: EzyColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            name.isEmpty
                ? 'SIN TÉCNICO ASIGNADO'
                : 'TÉCNICO · ${name.toUpperCase()}',
            overflow: TextOverflow.ellipsis,
            style: EzyTextStyles.microLabel.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
