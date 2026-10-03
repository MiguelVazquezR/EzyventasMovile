import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/app_formatters.dart';
import '../../../../core/utils/external_links.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../printing/data/whatsapp_message_builder.dart';
import '../../data/models/service_order_detail.dart';
import 'service_order_labels.dart';

/// Datos del cliente y del equipo recibido.
///
/// El bloque del cliente cierra con las acciones de contacto (llamar / abrir
/// WhatsApp) y la ficha del equipo va detrás de un separador con micro-título:
/// así el técnico encuentra el teléfono sin recorrer toda la card.
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
          if (detail.customer?.phone != null) ...<Widget>[
            const SizedBox(height: 14),
            ServiceOrderContactActions(detail: detail),
          ],
          const SizedBox(height: 18),
          const _SectionDivider(label: 'FICHA DEL EQUIPO'),
          const SizedBox(height: 6),
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

/// Separador con micro-título: parte dos bloques de una misma card sin abrir
/// otra tarjeta.
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Row(
      children: <Widget>[
        Expanded(child: Divider(height: 1, color: surfaces.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: EzyTextStyles.microLabel.copyWith(color: surfaces.textMuted),
          ),
        ),
        Expanded(child: Divider(height: 1, color: surfaces.border)),
      ],
    );
  }
}

/// Acciones de contacto del cliente: llamar y abrir WhatsApp con el mensaje
/// listo.
///
/// La app arma estas dos URLs con los helpers del proyecto (`tel:` y
/// `WhatsAppMessageBuilder.link`, el mismo del ticket) porque el teléfono es
/// un dato del cliente, no una URL de negocio del servidor. Sin teléfono, el
/// bloque no se pinta (devuelve un `SizedBox` vacío).
class ServiceOrderContactActions extends StatelessWidget {
  const ServiceOrderContactActions({super.key, required this.detail});

  final ServiceOrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final phone = detail.customer?.phone?.trim();

    if (phone == null || phone.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: _ContactButton(
            icon: Icons.call_outlined,
            label: 'Llamar',
            tone: EzyColors.primary,
            onTap: () => ExternalLinks.open(
              context,
              Uri(scheme: 'tel', path: phone).toString(),
              failureMessage: 'No se pudo abrir el marcador del teléfono.',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ContactButton(
            icon: Icons.chat_bubble_outline,
            label: 'WhatsApp',
            tone: EzyColors.whatsApp,
            onTap: () => ExternalLinks.open(
              context,
              WhatsAppMessageBuilder.link(
                phone: phone,
                message:
                    'Hola, te contacto por la orden de servicio '
                    '${detail.folio}.',
              ),
              failureMessage: 'No se pudo abrir WhatsApp en este teléfono.',
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón de contacto: outline de 44 px con el cuadro del icono teñido, el
/// mismo par que usan los canales de soporte (`support_channels_card.dart`)
/// para que las dos pantallas se lean igual.
class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: surfaces.border),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: tone.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, size: 15, color: tone),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EzyTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: surfaces.textPrimary,
                ),
              ),
            ),
          ],
        ),
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
