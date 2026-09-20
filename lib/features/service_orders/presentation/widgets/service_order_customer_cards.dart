import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/section_card.dart';
import '../../data/models/service_order_detail.dart';
import 'service_order_labels.dart';

/// Datos del cliente y del equipo recibido.
class ServiceOrderCustomerCard extends StatelessWidget {
  const ServiceOrderCustomerCard({
    super.key,
    required this.detail,
    required this.canSeeCustomerInfo,
  });

  final ServiceOrderDetail detail;
  final bool canSeeCustomerInfo;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final customer = detail.customer;

    return SectionCard(
      title: 'Cliente y equipo',
      child: Column(
        children: <Widget>[
          SectionRow(label: 'Cliente', value: detail.customerLabel),
          if (detail.customer?.phone != null)
            SectionRow(label: 'Teléfono', value: detail.customer!.phone!),
          if (detail.customerEmail != null)
            SectionRow(label: 'Correo', value: detail.customerEmail!),
          if (detail.customerAddress?.label != null)
            SectionRow(
              label: 'Dirección',
              value: detail.customerAddress!.label!,
            ),
          if (canSeeCustomerInfo && customer != null)
            SectionRow(
              label: customer.hasBalanceInFavor
                  ? 'Saldo a favor del cliente'
                  : 'Saldo del cliente',
              value: Money.format(customer.balance),
              valueStyle: EzyTextStyles.moneyList.copyWith(
                color: customer.hasBalanceInFavor
                    ? StatusPalette.text(context, EzySeverity.success)
                    : surfaces.textPrimary,
              ),
            ),
          const Divider(height: 24),
          SectionRow(label: 'Equipo', value: detail.itemDescription),
          SectionRow(
            label: 'Recibido',
            value: AppFormatters.dateTime(detail.receivedAt),
          ),
          if (detail.promisedAt != null)
            SectionRow(
              label: 'Entrega prometida',
              value: ServiceOrderLabels.promised(
                detail.promisedAt,
                detail.promiseDaysLeft,
              ),
            ),
          if (detail.hasTechnician) ...<Widget>[
            SectionRow(label: 'Técnico', value: detail.technicianName!),
            SectionRow(
              label: 'Comisión',
              value: ServiceOrderLabels.commission(
                type: detail.technicianCommissionType,
                value: detail.technicianCommissionValue,
              ),
            ),
          ],
          SectionRow(
            label: 'Fallas reportadas',
            value: detail.reportedProblems.isEmpty
                ? '—'
                : detail.reportedProblems,
          ),
        ],
      ),
    );
  }
}

/// Diagnóstico del técnico (puede venir vacío).
class ServiceOrderDiagnosisCard extends StatelessWidget {
  const ServiceOrderDiagnosisCard({
    super.key,
    required this.diagnosis,
    this.onEdit,
  });

  final String? diagnosis;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final hasDiagnosis = (diagnosis ?? '').trim().isNotEmpty;

    return SectionCard(
      title: 'Diagnóstico',
      trailing: onEdit == null
          ? null
          : TextButton(
              onPressed: onEdit,
              child: Text(hasDiagnosis ? 'Actualizar' : 'Capturar'),
            ),
      child: Text(
        hasDiagnosis ? diagnosis! : 'Aún no hay diagnóstico del técnico.',
        style: EzyTextStyles.body.copyWith(
          color: hasDiagnosis ? surfaces.textBody : surfaces.textMuted,
        ),
      ),
    );
  }
}
