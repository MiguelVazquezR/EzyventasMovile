import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_formatters.dart';
import 'server_image.dart';

/// Avatar del usuario: foto del servidor (`profile_photo_url`) o iniciales.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 44,
    this.onBrand = false,
  });

  final String name;
  final String? photoUrl;
  final double size;

  /// `true` cuando el avatar va sobre la banda naranja de marca (cabecera del
  /// POS y del menú lateral).
  ///
  /// El servidor manda un `profile_photo_url` generado (`ui-avatars.com`) aunque
  /// el usuario no tenga foto, así que lo normal es ver las iniciales: sobre el
  /// naranja hay que pintarlas oscuras y sobre un degradado blanco → gris, o el
  /// naranja sobre naranja no se lee.
  final bool onBrand;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: ServerImage(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _initials(),
        ),
      );
    }

    return _initials();
  }

  Widget _initials() {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Sobre la banda de marca el relleno es claro para que las iniciales se
        // lean; fuera de ella se mantiene el tinte naranja de siempre.
        color: onBrand ? null : EzyColors.primary.withValues(alpha: 0.14),
        gradient: onBrand
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[EzyColors.white, EzyColors.grayD9],
              )
            : null,
        shape: BoxShape.circle,
        border: Border.all(
          color: onBrand
              ? EzyColors.white.withValues(alpha: 0.85)
              : EzyColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        AppFormatters.initials(name),
        style: EzyTextStyles.bodyStrong.copyWith(
          color: onBrand ? EzyColors.gray37 : EzyColors.primary,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
