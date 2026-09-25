import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Imagen descargada del servidor (`Image.network` con el túnel de desarrollo).
///
/// Los medios llegan como URL absoluta al host del servidor
/// (`https://ezyventas2.test/storage/…`); en el teléfono físico ese dominio no
/// resuelve, así que [AppConfig.mediaRequests] devuelve los orígenes que sí son
/// alcanzables (el de la API con el `Host` de Herd cuando la app corre por el
/// túnel USB) y este widget los prueba **en orden**: `Image.network` no
/// reintenta por su cuenta y una imagen que falla se quedaba en el marcador.
///
/// [fallbackUrl] añade un medio alternativo (p. ej. la evidencia original
/// cuando la miniatura ya no existe en el servidor).
///
/// Se usa en lugar de `Image.network` para no repetir esa lógica en cada
/// pantalla: catálogo, detalle de producto, evidencias de órdenes y foto de perfil.
class ServerImage extends StatefulWidget {
  const ServerImage(
    this.url, {
    super.key,
    this.fallbackUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  /// URL tal como la devuelve la API (`null` o vacía = sin imagen).
  final String? url;

  /// Medio alternativo si [url] no carga (`null` = ninguno).
  final String? fallbackUrl;

  final BoxFit fit;
  final double? width;
  final double? height;

  /// Marcador de la pantalla cuando la imagen no carga (o no hay URL).
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<ServerImage> createState() => _ServerImageState();
}

class _ServerImageState extends State<ServerImage> {
  late List<MediaRequest> _requests;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _requests = _resolveRequests();
  }

  @override
  void didUpdateWidget(covariant ServerImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.url != widget.url ||
        oldWidget.fallbackUrl != widget.fallbackUrl) {
      _requests = _resolveRequests();
      _index = 0;
    }
  }

  List<MediaRequest> _resolveRequests() {
    final requests = <MediaRequest>[
      ...AppConfig.mediaRequests(widget.url),
    ];

    final fallback = widget.fallbackUrl?.trim() ?? '';

    if (fallback.isNotEmpty && fallback != (widget.url?.trim() ?? '')) {
      requests.addAll(AppConfig.mediaRequests(fallback));
    }

    return requests;
  }

  @override
  Widget build(BuildContext context) {
    if (_requests.isEmpty) {
      return _placeholder(ArgumentError('URL de imagen vacía'));
    }

    final request = _requests[_index];

    return Image.network(
      request.uri.toString(),
      headers: request.headers.isEmpty ? null : request.headers,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      errorBuilder: (context, error, stackTrace) {
        if (_index + 1 < _requests.length) {
          // El siguiente origen se intenta en el frame siguiente: cambiar el
          // estado durante el `build` del `Image` no es válido.
          Future<void>.microtask(() {
            if (mounted) {
              setState(() => _index++);
            }
          });

          return const SizedBox.shrink();
        }

        return _placeholder(error);
      },
    );
  }

  Widget _placeholder(Object error) =>
      widget.errorBuilder?.call(context, error, StackTrace.current) ??
      const SizedBox.shrink();
}

