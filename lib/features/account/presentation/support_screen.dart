import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/ezy_icon_button.dart';
import '../../../core/widgets/notice_banner.dart';
import '../application/account_providers.dart';
import '../data/models/support_content.dart';
import 'account_labels.dart';
import 'widgets/account_scaffold.dart';
import 'widgets/support_channels_card.dart';
import 'widgets/support_help_center_card.dart';
import 'widgets/support_schedule_card.dart';
import 'widgets/support_welcome_card.dart';

/// Centro de soporte (`GET /support`, contrato §11b.3).
///
/// Todo el contenido (bienvenida, horario, canales y temas) viene del servidor:
/// cambiarlo en `config/support.php` no requiere publicar una versión nueva de la
/// app. Los canales se abren con el manejador del sistema.
///
/// El Centro de ayuda aún no está disponible: se muestra con la pastilla ámbar
/// «Viene pronto» y el botón de acceso deshabilitado.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final support = ref.watch(supportProvider);
    final data = support.value;

    void refresh() => ref.invalidate(supportProvider);

    final Widget body;
    if (support.isLoading && data == null) {
      body = const _SupportLoading();
    } else if (data != null) {
      body = _SupportBody(
        content: data,
        errorMessage: support.hasError ? _errorMessage(support.error) : null,
        onRetry: refresh,
      );
    } else {
      body = _SupportError(
        message: _errorMessage(support.error),
        onRetry: refresh,
      );
    }

    return AccountScaffold(
      title: AccountMoreLabels.supportTitle,
      subtitle: AccountMoreLabels.supportSubtitle,
      onRefresh: () async => refresh(),
      actions: <Widget>[
        EzyIconButton(
          icon: Icons.refresh,
          tooltip: AccountMoreLabels.supportRefresh,
          onTap: refresh,
        ),
      ],
      body: body,
    );
  }

  static String _errorMessage(Object? error) =>
      error is ApiException && error.message.isNotEmpty
      ? error.message
      : AccountMoreLabels.supportErrorSubtitle;
}

/// Estado de carga inicial: spinner de marca y leyenda.
class _SupportLoading extends StatelessWidget {
  const _SupportLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(color: EzyColors.primary),
          const SizedBox(height: 16),
          Text(
            AccountMoreLabels.supportLoading,
            style: EzyTextStyles.caption.copyWith(
              color: context.surfaces.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Error de red sin datos cacheados: banner rojo con «Reintentar».
class _SupportError extends StatelessWidget {
  const _SupportError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        ErrorNotice(
          title: AccountMoreLabels.supportErrorTitle,
          message: message,
          onRetry: onRetry,
        ),
      ],
    );
  }
}

/// Contenido dinámico: bienvenida, horario, canales y centro de ayuda.
class _SupportBody extends StatelessWidget {
  const _SupportBody({
    required this.content,
    this.errorMessage,
    this.onRetry,
  });

  final SupportContent content;

  /// Aviso de error cuando falla un refresco pero aún hay datos previos.
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      if (content.hasWelcome) SupportWelcomeCard(welcome: content),
      if (content.hasSchedule) SupportScheduleCard(rows: content.schedule),
      if (content.hasChannels) SupportChannelsCard(channels: content.channels),
      SupportHelpCenterCard(topics: content.helpTopics),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        if (errorMessage != null) ...<Widget>[
          ErrorNotice(
            title: AccountMoreLabels.supportErrorTitle,
            message: errorMessage!,
            onRetry: onRetry,
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < cards.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: 12),
          cards[i],
        ],
      ],
    );
  }
}
