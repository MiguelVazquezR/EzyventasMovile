import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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

/// Diagnóstico del técnico con evidencias de cierre
/// (`POST /service-orders/{id}/diagnosis`, multipart).
///
/// Reglas del contrato que la UI respeta: el máximo es de 5 fotos **por
/// petición**, las fotos se agregan a `closing-service-order-evidence` (no se
/// borran desde aquí) y un diagnóstico vacío **borra** el texto anterior.
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

  int get _remaining => AppConfig.maxEvidenceImages - _photos.length;

  @override
  void dispose() {
    _diagnosisController.dispose();
    super.dispose();
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

  Future<void> _submit() async {
    final saved = await ref
        .read(serviceOrderDetailControllerProvider.notifier)
        .saveDiagnosis(
          diagnosis: _diagnosisController.text.trim(),
          images: _photos,
        );

    if (!mounted || !saved) {
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ref.read(serviceOrderDetailControllerProvider).notice ??
              'Diagnóstico y evidencias guardados correctamente.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final state = ref.watch(serviceOrderDetailControllerProvider);
    final detail = state.detail ?? widget.detail;
    final hadDiagnosis = (detail.technicianDiagnosis ?? '').trim().isNotEmpty;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          const SizedBox(height: 8),
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
                    'Ya guardadas (${ServiceOrderLabels.photos(detail.closingEvidence.length)})',
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  EvidenceMediaStrip(items: detail.closingEvidence),
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
