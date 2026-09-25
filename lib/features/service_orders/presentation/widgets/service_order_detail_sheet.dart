import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../../core/widgets/ezy_icon_button.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/service_orders_controller.dart';
import '../../data/models/service_order_detail.dart';
import 'evidence_photo_strip.dart';
import 'service_order_actions.dart';
import 'service_order_amounts_card.dart';
import 'service_order_customer_cards.dart';
import 'service_order_diagnosis_sheet.dart';
import 'service_order_items_card.dart';
import 'service_order_print_bar.dart';
import 'service_order_status_stepper.dart';

/// Detalle completo de una orden: estatus, cliente, conceptos, evidencias,
/// anticipos, historial y acciones.
Future<void> showServiceOrderDetailSheet(
  BuildContext context, {
  required int serviceOrderId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) =>
        _ServiceOrderDetailSheet(serviceOrderId: serviceOrderId),
  );
}

class _ServiceOrderDetailSheet extends ConsumerStatefulWidget {
  const _ServiceOrderDetailSheet({required this.serviceOrderId});

  final int serviceOrderId;

  @override
  ConsumerState<_ServiceOrderDetailSheet> createState() =>
      _ServiceOrderDetailSheetState();
}

class _ServiceOrderDetailSheetState
    extends ConsumerState<_ServiceOrderDetailSheet> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref
          .read(serviceOrderDetailControllerProvider.notifier)
          .load(widget.serviceOrderId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceOrderDetailControllerProvider);
    final controller = ref.read(serviceOrderDetailControllerProvider.notifier);
    final permissions = ref.watch(permissionsProvider);
    final detail = state.belongsTo(widget.serviceOrderId) ? state.detail : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      maxChildSize: 0.96,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: <Widget>[
          if (detail == null)
            ..._loadingChildren(state.errorMessage, controller)
          else ...<Widget>[
            _SheetHeader(
              detail: detail,
              onRefresh: controller.refresh,
              onClose: () => Navigator.of(context).pop(),
            ),
            if (state.notice != null) ...<Widget>[
              const SizedBox(height: 12),
              NoticeBanner(
                message: state.notice!,
                tone: EzySeverity.success,
                icon: Icons.check_circle_outline,
                actionLabel: 'Ocultar',
                onAction: controller.consumeNotice,
              ),
            ],
            if (state.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              NoticeBanner(
                message: state.errorMessage!,
                actionLabel: 'Ocultar',
                onAction: controller.consumeError,
              ),
            ],
            const SizedBox(height: 16),
            ServiceOrderStatusStepper(status: detail.status),
            const SizedBox(height: 16),
            ServiceOrderActionBar(detail: detail),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Impresión',
              child: ServiceOrderPrintBar(detail: detail),
            ),
            const SizedBox(height: 16),
            ServiceOrderCustomerCard(
              detail: detail,
              canSeeCustomerInfo: permissions.can(
                'services.orders.see_customer_info',
              ),
            ),
            const SizedBox(height: 12),
            ServiceOrderDiagnosisCard(
              diagnosis: detail.technicianDiagnosis,
              onEdit:
                  permissions.can('services.orders.edit') && detail.isEditable
                  ? () =>
                        showServiceOrderDiagnosisSheet(context, detail: detail)
                  : null,
            ),
            const SizedBox(height: 12),
            ServiceOrderItemsCard(items: detail.items),
            const SizedBox(height: 12),
            ServiceOrderAmountsCard(
              detail: detail,
              canSeeFinancialInfo: permissions.can(
                'services.orders.see_financial_info',
              ),
            ),
            const SizedBox(height: 12),
            ServiceOrderPaymentsCard(detail: detail),
            if (detail.initialEvidence.isNotEmpty ||
                detail.closingEvidence.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _EvidenceCard(detail: detail),
            ],
            if (detail.customFields.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _CustomFieldsCard(detail: detail),
            ],
            if (detail.activities.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              _ActivitiesCard(activities: detail.activities),
            ],
          ],
        ],
      ),
    );
  }

  /// Estado de carga: spinner y, si falló, el `message` del servidor.
  List<Widget> _loadingChildren(
    String? errorMessage,
    ServiceOrderDetailController controller,
  ) {
    return <Widget>[
      const SizedBox(height: 48),
      const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      if (errorMessage != null) ...<Widget>[
        const SizedBox(height: 20),
        ErrorNotice(message: errorMessage, onRetry: controller.refresh),
      ],
    ];
  }
}

/// Cabecera del detalle: folio, equipo, estatus y acciones de refresco.
///
/// El folio va como título de hoja (el mismo `EzySheetHeader` que las demás
/// hojas del design system), el equipo debajo, el estatus con `StatusBadge` y
/// las dos acciones (`Actualizar` y `Cerrar`) como `EzyIconButton`.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.detail,
    required this.onRefresh,
    required this.onClose,
  });

  final ServiceOrderDetail detail;
  final VoidCallback onRefresh;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 8),
        EzySheetHeader(
          title: detail.folio,
          subtitle: detail.itemDescription,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              EzyIconButton(
                icon: Icons.refresh,
                tooltip: 'Actualizar',
                onTap: onRefresh,
              ),
              const SizedBox(width: 8),
              EzyIconButton(
                icon: Icons.close,
                tooltip: 'Cerrar',
                onTap: onClose,
              ),
            ],
          ),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        StatusBadge.serviceOrder(
          detail.status,
          showDot: detail.status == 'en_progreso',
        ),
      ],
    );
  }
}

/// Evidencias de la orden: las iniciales y las del cierre (solo lectura aquí).
class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.detail});

  final ServiceOrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Evidencias',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (detail.initialEvidence.isNotEmpty) ...<Widget>[
            Text(
              'Recepción',
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            EvidenceMediaStrip(items: detail.initialEvidence),
            const SizedBox(height: 16),
          ],
          if (detail.closingEvidence.isNotEmpty) ...<Widget>[
            Text(
              'Diagnóstico y cierre',
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            EvidenceMediaStrip(items: detail.closingEvidence),
          ],
        ],
      ),
    );
  }
}

/// Campos personalizados capturados en la orden.
class _CustomFieldsCard extends StatelessWidget {
  const _CustomFieldsCard({required this.detail});

  final ServiceOrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final names = <String, String>{
      for (final definition in detail.customFieldDefinitions)
        definition.key: definition.name,
    };

    return SectionCard(
      title: 'Campos personalizados',
      child: Column(
        children: <Widget>[
          for (final entry in detail.customFields.entries)
            SectionRow(
              label: names[entry.key] ?? entry.key,
              value: _value(entry.value),
            ),
        ],
      ),
    );
  }

  /// Los `switch` se guardan como `1`/`0` o `true`/`false` según el cliente.
  static String _value(Object? value) {
    if (value is bool) {
      return value ? 'Sí' : 'No';
    }

    final text = value?.toString() ?? '—';

    return switch (text) {
      'true' || '1' => 'Sí',
      'false' || '0' => 'No',
      _ => text,
    };
  }
}

/// Historial de cambios de la orden (últimos 20 eventos).
class _ActivitiesCard extends StatelessWidget {
  const _ActivitiesCard({required this.activities});

  final List<ServiceOrderActivity> activities;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: 'Historial',
      child: Column(
        children: <Widget>[
          for (var index = 0; index < activities.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == activities.length - 1 ? 0 : 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    activities[index].description,
                    style: EzyTextStyles.body.copyWith(
                      color: surfaces.textBody,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      AppFormatters.dateTime(activities[index].createdAt),
                      if (activities[index].causerName != null)
                        activities[index].causerName!,
                    ].join(' · '),
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
