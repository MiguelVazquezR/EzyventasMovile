import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/widgets/empty_state.dart';
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
import 'service_order_form_controls.dart';
import 'service_order_items_card.dart';
import 'service_order_print_bar.dart';
import 'service_order_status_stepper.dart';

/// Detalle completo de una orden: estatus, cliente, conceptos, evidencias,
/// anticipos, historial y acciones.
///
/// La hoja ocupa el 94 % del alto (§12) con las esquinas superiores
/// redondeadas a 24 px y una barra de arrastre de 40×4 px. El fondo del modal
/// va transparente a propósito: las esquinas las pinta la propia hoja, si no
/// el lienzo del `showModalBottomSheet` taparía el redondeo con un cuadrado.
Future<void> showServiceOrderDetailSheet(
  BuildContext context, {
  required int serviceOrderId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
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
  /// Pestaña activa del documento (`Orden` por defecto: es lo que el técnico
  /// busca al abrir la hoja).
  _DetailTab _tab = _DetailTab.order;

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
    // El stepper solo es táctil con permiso de cambio de estatus: sin él la
    // hoja vuelve a ser un documento de solo lectura.
    final canChangeStatus = permissions.can('services.orders.change_status');
    final detail = state.belongsTo(widget.serviceOrderId) ? state.detail : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.94,
      maxChildSize: 0.94,
      builder: (context, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ColoredBox(
          color: context.surfaces.panel,
          child: Column(
            children: <Widget>[
              // El documento con su propio scroll: el dock vive **fuera** de
              // esta lista, pegado al borde inferior (§12), así las acciones
              // nunca quedan a un scroll de distancia.
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: <Widget>[
                    const _DragHandle(),
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
                      // El `422` del estatus llega por `errors.status[0]`: sin
                      // este aviso, avanzar un paso que el servidor rechaza (la
                      // orden ya cambió en otra caja) quedaría en silencio.
                      if (state.statusMessage != null) ...<Widget>[
                        const SizedBox(height: 12),
                        NoticeBanner(
                          message: state.statusMessage!,
                          tone: EzySeverity.warn,
                          actionLabel: 'Ocultar',
                          onAction: controller.consumeStatusMessage,
                        ),
                      ],
                      const SizedBox(height: 16),
                      // El stepper es táctil con permiso: el estatus se mueve
                      // sin abrir una segunda hoja y, al pasar a `entregado` con
                      // saldo pendiente, el cobro se encadena solo.
                      ServiceOrderStatusStepper(
                        status: detail.status,
                        isSubmitting: state.isSubmitting,
                        onStatusSelected: canChangeStatus
                            ? (next) => ServiceOrderStatusFlow.apply(
                                context,
                                ref,
                                detail: detail,
                                next: next,
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                      // Tres bloques en vez de nueve tarjetas apiladas: el
                      // documento del taller, el dinero y el historial.
                      ServiceOrderSegmentedControl<_DetailTab>(
                        values: _DetailTab.values,
                        selected: _tab,
                        labelOf: (tab) => tab.label,
                        onSelected: (tab) => setState(() => _tab = tab),
                      ),
                      const SizedBox(height: 16),
                      ..._tabChildren(detail),
                    ],
                  ],
                ),
              ),
              // El dock reacciona a lo que se debe y a la etapa de la orden.
              if (detail != null) ServiceOrderHeroDock(detail: detail),
            ],
          ),
        ),
      ),
    );
  }

  /// Contenido de la pestaña activa.
  ///
  /// Los permisos se releen aquí (y no se pasan por parámetro) para que cada
  /// bloque se pinte con la misma regla que el resto de la hoja: sin
  /// `see_financial_info` no hay comisión ni utilidad, sin `edit` no hay lápiz
  /// en el diagnóstico.
  List<Widget> _tabChildren(ServiceOrderDetail detail) {
    final permissions = ref.read(permissionsProvider);

    return switch (_tab) {
      _DetailTab.order => <Widget>[
        ServiceOrderDiagnosisCard(
          diagnosis: detail.technicianDiagnosis,
          onEdit: permissions.can('services.orders.edit') && detail.isEditable
              ? () => showServiceOrderDiagnosisSheet(context, detail: detail)
              : null,
        ),
        const SizedBox(height: 12),
        ServiceOrderItemsCard(items: detail.items),
        if (detail.initialEvidence.isNotEmpty ||
            detail.closingEvidence.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _EvidenceCard(detail: detail),
        ],
        if (detail.customFields.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _CustomFieldsCard(detail: detail),
        ],
      ],
      _DetailTab.payments => <Widget>[
        ServiceOrderAmountsCard(
          detail: detail,
          canSeeFinancialInfo: permissions.can(
            'services.orders.see_financial_info',
          ),
        ),
        const SizedBox(height: 12),
        ServiceOrderPaymentsCard(detail: detail),
      ],
      _DetailTab.history => <Widget>[
        if (detail.activities.isEmpty)
          const EmptyState(
            icon: Icons.history,
            title: 'Sin movimientos todavía',
            message: 'El historial se llena con cada cambio de la orden.',
            compact: true,
          )
        else
          _ActivitiesCard(activities: detail.activities),
      ],
    };
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

/// Barra de arrastre de la hoja (40×4 px, §12).
///
/// Va como primera pieza del `ListView` para que acompañe al contenido y deje
/// libres las esquinas redondeadas de 24 px.
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.surfaces.borderStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
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
        const _OrdenEyebrow(),
        const SizedBox(height: 6),
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

/// Micro-etiqueta de la hoja: recuerda que esto es una orden de servicio y no
/// una venta (las dos hojas se parecen mucho a primera vista).
class _OrdenEyebrow extends StatelessWidget {
  const _OrdenEyebrow();

  @override
  Widget build(BuildContext context) {
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
        Text(
          'ORDEN DE SERVICIO',
          style: EzyTextStyles.microLabel.copyWith(
            color: context.surfaces.textSecondary,
          ),
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

/// Pestañas del detalle: parten el documento en tres bloques para que la hoja
/// no sea un scroll único de nueve tarjetas.
enum _DetailTab {
  order('Orden'),
  payments('Cobros'),
  history('Historial');

  const _DetailTab(this.label);

  /// Etiqueta del control segmentado.
  final String label;
}
