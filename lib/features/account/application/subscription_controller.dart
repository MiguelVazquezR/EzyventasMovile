import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/evidence_image.dart';
import 'account_providers.dart';
import '../data/models/subscription_overview.dart';
import '../data/models/user_profile.dart';

/// Suscripción del negocio (`GET /subscription`, solo propietario).
final subscriptionProvider = FutureProvider<SubscriptionOverview>(
  (ref) => ref.watch(accountRepositoryProvider).fetchSubscription(),
);

/// Estado de las operaciones de la suscripción.
class SubscriptionState {
  const SubscriptionState({
    this.isSubmitting = false,
    this.errorMessage,
    this.notice,
    this.errorFields = const <String, List<String>>{},
  });

  final bool isSubmitting;

  /// `message` del servidor (nunca un texto inventado).
  final String? errorMessage;

  /// Confirmación con el `message` del servidor.
  final String? notice;

  final Map<String, List<String>> errorFields;

  SubscriptionState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    String? notice,
    Map<String, List<String>>? errorFields,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return SubscriptionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      errorFields: clearError
          ? const <String, List<String>>{}
          : (errorFields ?? this.errorFields),
    );
  }
}

/// Edición de la suscripción (solo propietario).
///
/// Renovar o mejorar el plan **no** se reimplementa: el checkout de Mercado Pago
/// vive en la web y la app solo abre el navegador externo (contrato §11b.5).
class SubscriptionController extends Notifier<SubscriptionState> {
  @override
  SubscriptionState build() => const SubscriptionState();

  /// `PUT /subscription` — datos generales del negocio.
  Future<bool> saveGeneralData({
    required String commercialName,
    String? businessName,
    String? contactPhone,
    String? address,
  }) => _run(
    () => ref.read(accountRepositoryProvider).updateSubscription(
      <String, dynamic>{
        'commercial_name': commercialName.trim(),
        'business_name': _nullable(businessName),
        'contact_phone': _nullable(contactPhone),
        'address': _nullable(address),
      },
    ),
  );

  /// `POST /subscription/documents` (multipart) — constancia fiscal.
  Future<bool> uploadFiscalDocument(EvidenceImage document) => _run(
    () => ref.read(accountRepositoryProvider).uploadFiscalDocument(document),
  );

  /// `POST /subscription/payments/{paymentId}/request-invoice`.
  Future<bool> requestInvoice(int paymentId) =>
      _run(() => ref.read(accountRepositoryProvider).requestInvoice(paymentId));

  /// Ejecuta una operación, publica `message`/`errors` y refresca la vista.
  Future<bool> _run(Future<AccountMessageResult> Function() request) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await request();

      state = state.copyWith(
        isSubmitting: false,
        notice: result.message,
        clearNotice: result.message.isEmpty,
      );

      ref.invalidate(subscriptionProvider);

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
        errorFields: error.errors,
      );

      return false;
    }
  }

  static String? _nullable(String? value) {
    final trimmed = value?.trim() ?? '';

    return trimmed.isEmpty ? null : trimmed;
  }

  void consumeNotice() {
    if (state.notice != null) {
      state = state.copyWith(clearNotice: true);
    }
  }

  void consumeError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, SubscriptionState>(
      SubscriptionController.new,
    );
