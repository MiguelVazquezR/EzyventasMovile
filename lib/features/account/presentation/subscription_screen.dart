import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/app_formatters.dart';
import '../../../core/utils/evidence_image.dart';
import '../../../core/utils/external_links.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/ezy_text_field.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../application/subscription_controller.dart';
import '../data/models/subscription_overview.dart';
import 'account_labels.dart';
import 'widgets/account_scaffold.dart';

/// "Mi suscripción" (contrato §11b.5, solo propietario).
///
/// Estado, datos generales editables, plan con su consumo, uso, historial de
/// pagos con solicitud de factura y documento fiscal. Renovar o mejorar el plan
/// **no** se reimplementa: abre el checkout de la web en el navegador externo.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final TextEditingController _commercialNameController =
      TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  /// Id de la suscripción con la que se rellenaron los campos.
  int? _prefilledSubscriptionId;

  @override
  void dispose() {
    _commercialNameController.dispose();
    _businessNameController.dispose();
    _contactPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionProvider);
    final state = ref.watch(subscriptionControllerProvider);

    return AccountScaffold(
      title: AccountMoreLabels.subscriptionTitle,
      onRefresh: _reload,
      body: subscription.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            ErrorNotice(
              message: error is ApiException
                  ? error.message
                  : AccountMoreLabels.subscriptionOwnerOnly,
              onRetry: () => ref.invalidate(subscriptionProvider),
            ),
          ],
        ),
        data: (overview) {
          _prefill(overview);

          return _body(overview, state);
        },
      ),
    );
  }

  Future<void> _reload() async => ref.invalidate(subscriptionProvider);

  /// Rellena el formulario una sola vez por suscripción cargada.
  void _prefill(SubscriptionOverview overview) {
    final id = overview.subscription.id;

    if (_prefilledSubscriptionId == id) {
      return;
    }

    _prefilledSubscriptionId = id;
    _commercialNameController.text = overview.subscription.commercialName;
    _businessNameController.text = overview.subscription.businessName ?? '';
    _contactPhoneController.text = overview.subscription.contactPhone ?? '';
    _addressController.text = overview.subscription.address ?? '';
  }

  Widget _body(SubscriptionOverview overview, SubscriptionState state) {
    final controller = ref.read(subscriptionControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        if (state.errorMessage != null) ...<Widget>[
          ErrorNotice(
            message: state.errorMessage!,
            onRetry: controller.consumeError,
          ),
          const SizedBox(height: 12),
        ],
        if (state.notice != null) ...<Widget>[
          NoticeBanner(
            message: state.notice!,
            tone: EzySeverity.success,
            actionLabel: 'Ocultar',
            onAction: controller.consumeNotice,
          ),
          const SizedBox(height: 12),
        ],
        _statusCard(overview),
        const SizedBox(height: 12),
        _generalDataCard(overview, state),
        const SizedBox(height: 12),
        _planCard(overview),
        const SizedBox(height: 12),
        _usageCard(overview),
        const SizedBox(height: 12),
        _historyCard(overview, state),
        const SizedBox(height: 12),
        _documentsCard(overview, state),
      ],
    );
  }

  /// Estado de la suscripción + banner del servidor + renovar plan.
  Widget _statusCard(SubscriptionOverview overview) {
    final surfaces = context.surfaces;
    final severity = _severity(overview);
    final status = overview.statusData;
    final label = status.label.isEmpty ? 'Suscripción' : status.label;

    return SectionCard(
      title: AccountMoreLabels.subscriptionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: StatusPalette.soft(severity),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: StatusPalette.border(severity)),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: EzyTextStyles.badge.copyWith(
                    color: StatusPalette.text(context, severity),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  overview.subscription.commercialName,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    color: surfaces.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (status.expiresLabel != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              status.expiresLabel!,
              style: EzyTextStyles.body.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ],
          if (status.warning != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(
              message: status.warning!,
              tone: EzySeverity.warn,
            ),
          ],
          if (overview.pendingPayment != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(
              message:
                  'Tienes un pago pendiente de '
                  '${overview.pendingPayment!.amountLabel} '
                  '(${overview.pendingPayment!.status.label}).',
              tone: EzySeverity.info,
            ),
          ],
          if (overview.lastRejectedPayment != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(
              message:
                  'Tu último pago de '
                  '${overview.lastRejectedPayment!.amountLabel} '
                  'fue rechazado. Intenta de nuevo desde la web.',
              tone: EzySeverity.danger,
            ),
          ],
          const SizedBox(height: 18),
          Text(
            AccountMoreLabels.subscriptionRenewMessage,
            style: EzyTextStyles.caption.copyWith(
              color: surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          EzyButton(
            label: AccountMoreLabels.subscriptionRenew,
            icon: Icons.open_in_new,
            onPressed: () => ExternalLinks.open(
              context,
              AppConfig.subscriptionManageUrl,
            ),
          ),
        ],
      ),
    );
  }

  /// Datos generales editables (`PUT /subscription`, solo propietario).
  Widget _generalDataCard(
    SubscriptionOverview overview,
    SubscriptionState state,
  ) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: AccountMoreLabels.subscriptionGeneralData,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EzyTextField(
            label: AccountMoreLabels.subscriptionCommercialName,
            controller: _commercialNameController,
            isRequired: true,
            errorText: _fieldError(state.errorFields, 'commercial_name'),
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: AccountMoreLabels.subscriptionBusinessName,
            controller: _businessNameController,
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: AccountMoreLabels.subscriptionContactPhone,
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: AccountMoreLabels.subscriptionAddress,
            controller: _addressController,
            maxLines: 2,
          ),
          if (overview.subscription.taxId != null &&
              overview.subscription.taxId!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'RFC: ${overview.subscription.taxId}',
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 20),
          EzyButton(
            label: AccountLabels.saveChanges,
            icon: Icons.save_outlined,
            isLoading: state.isSubmitting,
            onPressed: () => ref
                .read(subscriptionControllerProvider.notifier)
                .saveGeneralData(
                  commercialName: _commercialNameController.text,
                  businessName: _businessNameController.text,
                  contactPhone: _contactPhoneController.text,
                  address: _addressController.text,
                ),
          ),
        ],
      ),
    );
  }

  /// Plan contratado: módulos y límites con su consumo.
  Widget _planCard(SubscriptionOverview overview) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: AccountMoreLabels.subscriptionPlan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AccountMoreLabels.subscriptionModules.toUpperCase(),
            style: EzyTextStyles.microLabel.copyWith(
              color: surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final module in overview.plan.modules)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: module.isActive
                        ? StatusPalette.soft(EzySeverity.success)
                        : surfaces.panelInner,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: module.isActive
                          ? StatusPalette.border(EzySeverity.success)
                          : surfaces.border,
                    ),
                  ),
                  child: Text(
                    module.name,
                    style: EzyTextStyles.caption.copyWith(
                      color: module.isActive
                          ? StatusPalette.text(context, EzySeverity.success)
                          : surfaces.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          if (overview.plan.limits.isNotEmpty) ...<Widget>[
            const SizedBox(height: 18),
            Text(
              AccountMoreLabels.subscriptionLimits.toUpperCase(),
              style: EzyTextStyles.microLabel.copyWith(
                color: surfaces.textMuted,
              ),
            ),
            for (final limit in overview.plan.limits)
              _LimitRow(limit: limit),
          ],
        ],
      ),
    );
  }

  /// Uso actual de la suscripción (solo lectura, números del servidor).
  Widget _usageCard(SubscriptionOverview overview) {
    return SectionCard(
      title: AccountMoreLabels.subscriptionUsage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final row in overview.usage.rows)
            SectionRow(label: row.$1, value: '${row.$2}'),
        ],
      ),
    );
  }

  /// Historial de versiones del plan con su pago.
  Widget _historyCard(SubscriptionOverview overview, SubscriptionState state) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: AccountMoreLabels.subscriptionHistory,
      child: overview.history.isEmpty
          ? Text(
              AccountMoreLabels.subscriptionNoPayments,
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textSecondary,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final entry in overview.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                'Versión ${entry.version} · '
                                '${AppFormatters.date(entry.createdAt)}',
                                style: EzyTextStyles.bodyStrong.copyWith(
                                  color: surfaces.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              entry.amountLabel,
                              style: EzyTextStyles.moneyList.copyWith(
                                color: surfaces.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            if (entry.payment != null)
                              Text(
                                '${entry.payment!.status.label}'
                                '${entry.payment!.folio == null ? '' : ' · ${entry.payment!.folio}'}',
                                style: EzyTextStyles.caption.copyWith(
                                  color: surfaces.textSecondary,
                                ),
                              ),
                            const Spacer(),
                            if (entry.payment?.isInvoiceRequestable ?? false)
                              EzyButton(
                                label:
                                    AccountMoreLabels.subscriptionRequestInvoice,
                                variant: EzyButtonVariant.text,
                                expand: false,
                                isLoading: state.isSubmitting,
                                onPressed: () => ref
                                    .read(
                                      subscriptionControllerProvider.notifier,
                                    )
                                    .requestInvoice(entry.payment!.id!),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                if (overview.history.any(
                  (entry) =>
                      entry.canRequestInvoice &&
                      !(entry.payment?.isInvoiceRequestable ?? false),
                ))
                  Text(
                    AccountMoreLabels.subscriptionInvoiceUnavailable,
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
              ],
            ),
    );
  }

  /// Documento fiscal (`POST /subscription/documents`).
  Widget _documentsCard(SubscriptionOverview overview, SubscriptionState state) {
    final surfaces = context.surfaces;
    final documentUrl = overview.fiscalDocumentUrl;

    return SectionCard(
      title: AccountMoreLabels.subscriptionDocuments,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            overview.hasFiscalDocument
                ? 'Tu constancia está cargada.'
                : AccountMoreLabels.subscriptionNoDocument,
            style: EzyTextStyles.body.copyWith(
              color: surfaces.textBody,
            ),
          ),
          if (documentUrl != null) ...<Widget>[
            const SizedBox(height: 10),
            EzyButton(
              label: 'Ver documento',
              icon: Icons.open_in_new,
              variant: EzyButtonVariant.outline,
              onPressed: () => ExternalLinks.open(context, documentUrl),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            AccountMoreLabels.subscriptionDocumentImageOnly,
            style: EzyTextStyles.caption.copyWith(
              color: surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          EzyButton(
            label: AccountMoreLabels.subscriptionUploadDocument,
            icon: Icons.upload_file_outlined,
            variant: EzyButtonVariant.outline,
            isLoading: state.isSubmitting,
            onPressed: () => _uploadDocument(),
          ),
        ],
      ),
    );
  }

  /// Sube la constancia fiscal como imagen (cámara o galería, máx. 2 MB).
  Future<void> _uploadDocument() async {
    EvidencePickResult result;

    try {
      result = await EvidencePicker.pickFromGallery(
        limit: 1,
        maxKb: AppConfig.maxEvidenceImageKb,
      );
    } on PlatformException {
      result = const EvidencePickResult.empty();
    }

    if (!mounted) {
      return;
    }

    final document = result.images.isEmpty ? null : result.images.first;

    if (document == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No pudimos preparar el documento. Intenta con otra imagen.',
          ),
        ),
      );

      return;
    }

    await ref
        .read(subscriptionControllerProvider.notifier)
        .uploadFiscalDocument(document);
  }

  /// Severidad del estado: expirada o suspendida (rojo), por vencer (ámbar),
  /// activa (verde). Se calcula con los datos del servidor, nunca con texto
  /// inventado.
  EzySeverity _severity(SubscriptionOverview overview) {
    if (overview.statusData.isExpired ||
        overview.subscription.status == SubscriptionStatus.suspended) {
      return EzySeverity.danger;
    }

    if (overview.statusData.isExpiringSoon) {
      return EzySeverity.warn;
    }

    return EzySeverity.success;
  }
}

/// Fila de un límite del plan con su barra de consumo.
class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.limit});

  final SubscriptionLimit limit;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  limit.name,
                  style: EzyTextStyles.body.copyWith(
                    color: surfaces.textBody,
                  ),
                ),
              ),
              Text(
                limit.usageLabel ?? '${limit.limit}',
                style: EzyTextStyles.caption.copyWith(
                  color: limit.isAtLimit
                      ? StatusPalette.text(context, EzySeverity.warn)
                      : surfaces.textSecondary,
                ),
              ),
            ],
          ),
          if (limit.used != null) ...<Widget>[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: limit.usageRatio,
                minHeight: 4,
                backgroundColor: surfaces.panelInner,
                color: limit.isAtLimit ? EzyColors.warning : EzyColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Primer mensaje del `422` para un campo (`errors.campo[0]`).
String? _fieldError(Map<String, List<String>> errors, String field) {
  final messages = errors[field];

  if (messages == null || messages.isEmpty) {
    return null;
  }

  return messages.first;
}
