import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Apertura de enlaces con el manejador del sistema (navegador, correo,
/// WhatsApp).
///
/// La app **nunca** arma ni reescribe las URLs de negocio: las recibe del
/// servidor (`GET /support`) o de la configuración de entorno
/// (`AppConfig.subscriptionManageUrl`).
class ExternalLinks {
  const ExternalLinks._();

  /// Abre [url] fuera de la app y avisa si el teléfono no puede abrirla.
  ///
  /// El `ScaffoldMessenger` se captura **antes** de esperar la apertura, así que
  /// no se usa el `BuildContext` después de un `await`.
  static Future<bool> open(
    BuildContext context,
    String? url, {
    String failureMessage = 'No se pudo abrir el enlace en este teléfono.',
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final target = url?.trim() ?? '';

    if (target.isEmpty) {
      _notify(messenger, failureMessage);

      return false;
    }

    try {
      final opened = await launchUrl(
        Uri.parse(target),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        _notify(messenger, failureMessage);
      }

      return opened;
    } on Object {
      _notify(messenger, failureMessage);

      return false;
    }
  }

  static void _notify(ScaffoldMessengerState? messenger, String message) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
