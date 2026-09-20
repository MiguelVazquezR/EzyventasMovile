import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Logotipo de EzyVentas (`assets/images/`).
///
/// El tema oscuro (predeterminado) usa la versión blanca del logotipo y el
/// tema claro la negra, de modo que la marca siempre tenga contraste. Si el
/// asset no llega al bundle, el `errorBuilder` dibuja el wordmark de texto
/// para no dejar la cabecera vacía.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 80});

  /// Logotipo para fondos oscuros (letras blancas).
  static const String onDarkAsset = 'assets/images/white_logo.png';

  /// Logotipo para fondos claros (letras negras).
  static const String onLightAsset = 'assets/images/black_logo.png';

  /// Texto accesible y de respaldo de la marca.
  static const String label = 'EzyVentas';

  /// Alto del logotipo en píxeles lógicos; el ancho sale de la proporción
  /// original (734 x 335), así que no hace falta fijarlo.
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Image.asset(
      isDark ? onDarkAsset : onLightAsset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: label,
      errorBuilder: (context, error, stackTrace) => _Wordmark(height: height),
    );
  }
}

/// Wordmark de reserva: el nombre de la marca con la tipografía del design
/// system, por si el PNG no está disponible.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Text(
      BrandLogo.label,
      textAlign: TextAlign.center,
      style: EzyTextStyles.screenTitle.copyWith(
        fontSize: height * 0.36,
        color: context.surfaces.textPrimary,
      ),
    );
  }
}
