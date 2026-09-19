import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/app_formatters.dart';

/// Avatar del usuario: foto del servidor (`profile_photo_url`) o iniciales.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 44,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;

    if (url != null && url.isNotEmpty) {
      return ClipOval(
        child: Image.network(
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
        color: EzyColors.primary.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: EzyColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        AppFormatters.initials(name),
        style: EzyTextStyles.bodyStrong.copyWith(
          color: EzyColors.primary,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
