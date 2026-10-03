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

  /// El usuario ya tocó el nombre comercial: a partir de ahí se valida en línea.
  bool _commercialNameEdited = false;

  @override
  void dispose() {
    _commercialNameController.dispose();
    _businessNameController.dispose();
    _contactPhoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// El nombre comercial es obligatorio (`*`): sin texto no se guarda.
  bool get _hasCommercialName =>
      _commercialNameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final subscription = ref.watch(subscriptionProvider);
    final state = ref.watch(subscriptionControllerProvider);

    return AccountScaffold(
      title: AccountMoreLabels.subscriptionTitle,
      subtitle: AccountMoreLabels.subscriptionSubtitle,
      compact: true,
      onRefresh: _reload,
      body: subscription.when(
        loading: () => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: const <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
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

  /// Estado de la suscripción (pastilla con el texto del servidor) + renovación.
  Widget _statusCard(SubscriptionOverview overview) {
    final surfaces = context.surfaces;
    final severity = _severity(overview);
    final status = overview.statusData;
    final label = status.label.isEmpty
        ? AccountMoreLabels.subscriptionTitle
        : status.label;
    final activeModules = overview.plan.modules
        .where((module) => module.isActive)
        .length;

    return SectionCard(
      title: AccountMoreLabels.subscriptionPlanStatus,
      trailing: _StatusPill(label: label, severity: severity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionCard(
            inner: true,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      AccountMoreLabels.subscriptionBusiness.toUpperCase(),
                      style: EzyTextStyles.microLabel.copyWith(
                        color: surfaces.textMuted,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: surfaces.panel,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: surfaces.border),
                      ),
                      child: Text(
                        AccountMoreLabels.subscriptionActiveModules(
                          activeModules,
                        ),
                        style: EzyTextStyles.badge.copyWith(
                          color: surfaces.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  overview.subscription.commercialName,
                  style: EzyTextStyles.bodyStrong.copyWith(
                    fontWeight: FontWeight.w800,
                    color: surfaces.textPrimary,
                  ),
                ),
                if (status.expiresAt != null) ...<Widget>[
                  const SizedBox(height: 6),
                  _ExpiryRow(
                    label: status.expiresLabel ?? '',
                    highlight: status.isWarning,
                  ),
                ],
              ],
            ),
          ),
          if (status.warning != null) ...<Widget>[
            const SizedBox(height: 12),
            NoticeBanner(message: status.warning!, tone: EzySeverity.warn),
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
            textAlign: TextAlign.center,
            style: EzyTextStyles.caption.copyWith(
              fontSize: 11,
              color: surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          _Ezy3dPillButton(
            label: AccountMoreLabels.subscriptionRenew,
            icon: Icons.open_in_new,
            onPressed: () =>
                ExternalLinks.open(context, AppConfig.subscriptionManageUrl),
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
    final serverError = _fieldError(state.errorFields, 'commercial_name');
    final commercialError = !_hasCommercialName && _commercialNameEdited
        ? AccountMoreLabels.subscriptionRequiredCommercialName
        : serverError;

    return SectionCard(
      title: AccountMoreLabels.subscriptionGeneralData,
      trailing: Text(
        AccountMoreLabels.subscriptionRequiredLegend,
        style: EzyTextStyles.caption.copyWith(
          fontSize: 11,
          color: EzyColors.primary300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EzyTextField(
            label: AccountMoreLabels.subscriptionCommercialName,
            controller: _commercialNameController,
            isRequired: true,
            errorText: commercialError,
            requiredMarkColor: EzyColors.danger,
            onChanged: (_) => setState(() => _commercialNameEdited = true),
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
            keyboardType: TextInputType.streetAddress,
            maxLines: 2,
          ),
          if (overview.subscription.taxId != null &&
              overview.subscription.taxId!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            SectionCard(
              inner: true,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    AccountMoreLabels.subscriptionTaxId.toUpperCase(),
                    style: EzyTextStyles.microLabel.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      overview.subscription.taxId!,
                      textAlign: TextAlign.right,
                      style: EzyTextStyles.bodyStrong.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: surfaces.textPrimary,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          _Ezy3dPillButton(
            label: AccountLabels.saveChanges,
            icon: Icons.save_outlined,
            isLoading: state.isSubmitting,
            onPressed: _hasCommercialName
                ? () => ref
                      .read(subscriptionControllerProvider.notifier)
                      .saveGeneralData(
                        commercialName: _commercialNameController.text,
                        businessName: _businessNameController.text,
                        contactPhone: _contactPhoneController.text,
                        address: _addressController.text,
                      )
                : null,
          ),
        ],
      ),
    );
  }

  /// Plan contratado: módulos y límites con su consumo.
  Widget _planCard(SubscriptionOverview overview) {
    final surfaces = context.surfaces;
    final modules = overview.plan.modules;
    final limits = overview.plan.limits;

    return SectionCard(
      title: AccountMoreLabels.subscriptionPlan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AccountMoreLabels.subscriptionModules.toUpperCase(),
            style: EzyTextStyles.microLabel.copyWith(
              fontWeight: FontWeight.w800,
              color: surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          if (modules.isEmpty)
            Text(
              AccountLabels.modulesEmpty,
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textSecondary,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final module in modules) _ModulePill(module: module),
              ],
            ),
          if (limits.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: surfaces.border),
            const SizedBox(height: 16),
            Text(
              AccountMoreLabels.subscriptionLimits.toUpperCase(),
              style: EzyTextStyles.microLabel.copyWith(
                fontWeight: FontWeight.w800,
                color: surfaces.textMuted,
              ),
            ),
            for (final limit in limits) _LimitRow(limit: limit),
          ],
        ],
      ),
    );
  }

  /// Uso actual de la suscripción (solo lectura, números del servidor).
  Widget _usageCard(SubscriptionOverview overview) {
    final surfaces = context.surfaces;

    return SectionCard(
      title: AccountMoreLabels.subscriptionUsage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AccountMoreLabels.subscriptionUsageServerTitle.toUpperCase(),
            style: EzyTextStyles.microLabel.copyWith(
              fontWeight: FontWeight.w800,
              color: surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          SectionCard(
            inner: true,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final row in overview.usage.rows)
                  SectionRow(label: row.$1, value: '${row.$2}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Historial de versiones del plan con su pago.
  Widget _historyCard(SubscriptionOverview overview, SubscriptionState state) {
    final surfaces = context.surfaces;
    final controller = ref.read(subscriptionControllerProvider.notifier);

    return SectionCard(
      title: AccountMoreLabels.subscriptionHistory,
      trailing: _CountBadge(count: overview.history.length),
      child: overview.history.isEmpty
          ? Text(
              AccountMoreLabels.subscriptionNoPayments,
              textAlign: TextAlign.center,
              style: EzyTextStyles.caption.copyWith(
                color: surfaces.textSecondary,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final entry in overview.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SectionCard(
                      inner: true,
                      padding: const EdgeInsets.all(14),
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
                                    fontWeight: FontWeight.w800,
                                    color: surfaces.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                entry.amountLabel,
                                style: EzyTextStyles.moneyList.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: surfaces.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (entry.payment != null) ...<Widget>[
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: StatusPalette.text(
                                      context,
                                      _paymentSeverity(entry.payment!.status),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${entry.payment!.status.label}'
                                    '${entry.payment!.folio == null ? '' : ' · ${entry.payment!.folio}'}',
                                    style: EzyTextStyles.caption.copyWith(
                                      color: surfaces.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: entry.payment?.isInvoiceRequestable ?? false
                                ? EzyButton(
                                    label: AccountMoreLabels
                                        .subscriptionRequestInvoice,
                                    variant: EzyButtonVariant.text,
                                    expand: false,
                                    isLoading: state.isSubmitting,
                                    onPressed: () => controller.requestInvoice(
                                      entry.payment!.id!,
                                    ),
                                  )
                                : Text(
                                    AccountMoreLabels
                                        .subscriptionInvoiceUnavailable,
                                    style: EzyTextStyles.caption.copyWith(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: surfaces.textMuted,
                                    ),
                                  ),
                          ),
                        ],
                      ),
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
    final hasDocument = overview.hasFiscalDocument;
    final fileName = hasDocument ? _documentFileName(documentUrl!) : null;

    return SectionCard(
      title: AccountMoreLabels.subscriptionDocuments,
      trailing: _StatusChip(
        label: hasDocument
            ? AccountMoreLabels.subscriptionDocumentLoaded
            : AccountMoreLabels.subscriptionDocumentPending,
        severity: hasDocument ? EzySeverity.success : EzySeverity.warn,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionCard(
            inner: true,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  hasDocument
                      ? Icons.verified_outlined
                      : Icons.description_outlined,
                  size: 20,
                  color: hasDocument
                      ? StatusPalette.text(context, EzySeverity.success)
                      : surfaces.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        hasDocument
                            ? AccountMoreLabels.subscriptionDocumentLoaded
                            : AccountMoreLabels.subscriptionNoDocument,
                        style: EzyTextStyles.bodyStrong.copyWith(
                          fontWeight: FontWeight.w700,
                          color: surfaces.textPrimary,
                        ),
                      ),
                      if (fileName != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          fileName,
                          style: EzyTextStyles.caption.copyWith(
                            color: surfaces.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (documentUrl != null)
            Row(
              children: <Widget>[
                Expanded(
                  child: EzyButton(
                    label: AccountMoreLabels.subscriptionViewDocument,
                    icon: Icons.open_in_new,
                    variant: EzyButtonVariant.outline,
                    height: 40,
                    onPressed: () => ExternalLinks.open(context, documentUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EzyButton(
                    label: AccountMoreLabels.subscriptionUploadDocument,
                    icon: Icons.upload_file_outlined,
                    variant: EzyButtonVariant.outline,
                    height: 40,
                    isLoading: state.isSubmitting,
                    onPressed: () => _uploadDocument(),
                  ),
                ),
              ],
            )
          else
            EzyButton(
              label: AccountMoreLabels.subscriptionUploadDocument,
              icon: Icons.upload_file_outlined,
              variant: EzyButtonVariant.outline,
              height: 40,
              isLoading: state.isSubmitting,
              onPressed: () => _uploadDocument(),
            ),
          const SizedBox(height: 12),
          Text(
            AccountMoreLabels.subscriptionDocumentNote,
            textAlign: TextAlign.center,
            style: EzyTextStyles.caption.copyWith(
              fontSize: 10,
              color: surfaces.textMuted,
            ),
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

  /// Severidad del pago para el punto indicador del historial.
  EzySeverity _paymentSeverity(SubscriptionPaymentStatus status) =>
      switch (status) {
        SubscriptionPaymentStatus.approved => EzySeverity.success,
        SubscriptionPaymentStatus.pending => EzySeverity.warn,
        SubscriptionPaymentStatus.rejected => EzySeverity.danger,
        SubscriptionPaymentStatus.unknown => EzySeverity.neutral,
      };

  /// Último segmento de la URL del documento, si el servidor la expone.
  String? _documentFileName(String url) {
    final segments = Uri.tryParse(url)?.pathSegments;

    if (segments == null || segments.isEmpty) {
      return null;
    }

    final name = segments.last;

    return name.isEmpty ? null : name;
  }
}

/// Línea de vencimiento con icono de calendario y tono ámbar si está por vencer.
class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({required this.label, required this.highlight});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final color = highlight
        ? StatusPalette.text(context, EzySeverity.warn)
        : surfaces.textSecondary;

    return Row(
      children: <Widget>[
        Icon(Icons.calendar_today_outlined, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: EzyTextStyles.caption.copyWith(color: color))),
      ],
    );
  }
}

/// Pastilla de estado de la suscripción con el texto del servidor.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.severity});

  final String label;
  final EzySeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, severity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: StatusPalette.soft(severity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(severity)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: EzyTextStyles.badge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Chip de estado de una card (documento cargado / pendiente).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.severity});

  final String label;
  final EzySeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = StatusPalette.text(context, severity);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: StatusPalette.soft(severity),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: StatusPalette.border(severity)),
      ),
      child: Text(
        label.toUpperCase(),
        style: EzyTextStyles.badge.copyWith(color: color),
      ),
    );
  }
}

/// Contador numérico de una card (nº de versiones del historial).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: surfaces.panelInner,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: surfaces.border),
      ),
      child: Text(
        '$count',
        style: EzyTextStyles.badge.copyWith(color: surfaces.textSecondary),
      ),
    );
  }
}

/// Pastilla de un módulo del plan: verde con palomita si está activo.
class _ModulePill extends StatelessWidget {
  const _ModulePill({required this.module});

  final SubscriptionModule module;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final isActive = module.isActive;
    final color = isActive
        ? StatusPalette.text(context, EzySeverity.success)
        : surfaces.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? StatusPalette.soft(EzySeverity.success)
            : surfaces.panelInner,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? StatusPalette.border(EzySeverity.success)
              : surfaces.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isActive) ...<Widget>[
            Icon(Icons.check, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            module.name,
            style: EzyTextStyles.caption.copyWith(
              color: isActive ? color : surfaces.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de un límite del plan con su barra de consumo (4 px).
class _LimitRow extends StatelessWidget {
  const _LimitRow({required this.limit});

  final SubscriptionLimit limit;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final atTop = limit.isAtLimit || limit.usageRatio >= 0.95;
    final value = limit.usageLabel ?? '${limit.limit}';

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
              const SizedBox(width: 12),
              Text(
                atTop
                    ? '$value ${AccountMoreLabels.subscriptionLimitAtTop}'
                    : value,
                style: EzyTextStyles.moneyList.copyWith(
                  fontSize: 12,
                  color: atTop
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
                color: atTop ? EzyColors.warning : EzyColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// CTA 3D táctil en pastilla de 48 px: degradado vertical, bisel físico y base
/// sólida pegada al borde inferior. Al pulsarlo se hunde 4 px.
///
/// Se pinta a mano (no `FilledButton`) porque el diseño pide el bisel de tres
/// caras y una base sólida que un `ButtonStyle` no dibuja; el radio es la
/// pastilla completa (`999`) que la pieza compartida del cobro no ofrece.
class _Ezy3dPillButton extends StatefulWidget {
  const _Ezy3dPillButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  static const double height = 48;

  static const LinearGradient _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFFFB9E2E), EzyColors.primary, Color(0xFFE07804)],
    stops: <double>[0.0, 0.45, 1.0],
  );

  static const List<BoxShadow> _relief = <BoxShadow>[
    BoxShadow(color: Color(0xFF9E4600), offset: Offset(0, 4)),
  ];

  @override
  State<_Ezy3dPillButton> createState() => _Ezy3dPillButtonState();
}

class _Ezy3dPillButtonState extends State<_Ezy3dPillButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final enabled = widget.onPressed != null && !widget.isLoading;
    final branded = enabled || widget.isLoading;

    return GestureDetector(
      onTapDown: enabled ? (details) => _setPressed(true) : null,
      onTapUp: enabled ? (details) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        height: _Ezy3dPillButton.height,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          gradient: branded ? _Ezy3dPillButton._gradient : null,
          color: branded ? null : surfaces.panelInner,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: branded ? const Color(0xFFFFBA66) : surfaces.border,
          ),
          boxShadow: branded && !_pressed ? _Ezy3dPillButton._relief : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Center(child: _content(surfaces, branded)),
        ),
      ),
    );
  }

  Widget _content(EzySurfaces surfaces, bool branded) {
    if (widget.isLoading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2.2,
          color: EzyColors.white,
        ),
      );
    }

    final color = branded ? EzyColors.white : surfaces.textMuted;
    final icon = widget.icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label.toUpperCase(),
          style: EzyTextStyles.button.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
      ],
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









