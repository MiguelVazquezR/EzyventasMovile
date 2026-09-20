import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Imagen descargada del servidor (`Image.network` con el túnel de desarrollo).
///
/// Los medios llegan como URL absoluta al host del servidor
/// (`https://ezyventas2.test/storage/…`); en el teléfono físico ese dominio no
/// resuelve, así que [AppConfig.mediaUri] reescribe el origen al de la API y
/// [AppConfig.mediaHeaders] manda el `Host` de Herd cuando la app corre por el
/// túnel USB (en producción no cambia nada).
///
/// Se usa en lugar de `Image.network` para no repetir esa lógica en cada
/// pantalla: catálogo, detalle de producto, evidencias de órdenes y foto de perfil.
class ServerImage extends StatelessWidget {
  const ServerImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  /// URL tal como la devuelve la API (`null` o vacía = sin imagen).
  final String? url;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Marcador de la pantalla cuando la imagen no carga (o no hay URL).
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final uri = AppConfig.mediaUri(url);

    if (uri == null) {
      return errorBuilder?.call(
            context,
            ArgumentError('URL de imagen vacía'),
            StackTrace.current,
          ) ??
          const SizedBox.shrink();
    }

    final headers = AppConfig.mediaHeaders;

    return Image.network(
      uri.toString(),
      headers: headers.isEmpty ? null : headers,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );
  }
}
