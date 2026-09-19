import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Pantalla de arranque: se muestra mientras se decide si hay sesión guardada.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: EzyColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: EzyColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: EzyColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'EzyVentas',
              style: EzyTextStyles.screenTitle.copyWith(
                color: surfaces.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Punto de venta y órdenes de servicio',
              style: EzyTextStyles.secondary.copyWith(
                color: surfaces.textSecondary,
              ),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
