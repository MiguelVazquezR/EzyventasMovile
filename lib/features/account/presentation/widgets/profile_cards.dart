import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/status_palette.dart';
import '../../../../core/utils/evidence_image.dart';
import '../../../../core/widgets/ezy_button.dart';
import '../../../../core/widgets/ezy_text_field.dart';
import '../../../../core/widgets/notice_banner.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../application/profile_controller.dart';
import '../../data/models/user_profile.dart';
import '../account_labels.dart';

/// Primer mensaje del `422` para un campo (`errors.name[0]`).
String? _fieldError(Map<String, List<String>> errors, String field) {
  final messages = errors[field];

  if (messages == null || messages.isEmpty) {
    return null;
  }

  return messages.first;
}

/// Bloque "Información personal": foto, nombre y correo (§14.3).
class PersonalInfoCard extends StatelessWidget {
  const PersonalInfoCard({
    super.key,
    required this.user,
    required this.state,
    required this.nameController,
    required this.emailController,
    required this.pendingPhoto,
    required this.onPickPhoto,
    required this.onDeletePhoto,
    required this.onSave,
  });

  final UserProfile user;
  final ProfileState state;
  final TextEditingController nameController;
  final TextEditingController emailController;

  /// Foto elegida y todavía no guardada (se previsualiza).
  final EvidenceImage? pendingPhoto;

  final VoidCallback onPickPhoto;
  final VoidCallback onDeletePhoto;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final photo = pendingPhoto;

    return SectionCard(
      title: AccountLabels.personalInfo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (photo != null)
                ClipOval(
                  child: Image.memory(
                    photo.bytes,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                )
              else
                UserAvatar(
                  name: user.name,
                  photoUrl: user.realPhotoUrl,
                  size: 64,
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      photo == null
                          ? (user.hasPhoto
                                ? AccountLabels.changePhoto
                                : AccountLabels.noPhoto)
                          : 'Foto lista para guardar (${photo.sizeLabel}).',
                      style: EzyTextStyles.caption.copyWith(
                        color: surfaces.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        EzyButton(
                          label: AccountLabels.changePhoto,
                          icon: Icons.photo_camera_outlined,
                          variant: EzyButtonVariant.outline,
                          expand: false,
                          onPressed: state.isSubmitting ? null : onPickPhoto,
                        ),
                        if (user.hasPhoto)
                          EzyButton(
                            label: AccountLabels.deletePhoto,
                            variant: EzyButtonVariant.text,
                            expand: false,
                            onPressed: state.isSubmitting ? null : onDeletePhoto,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!user.isEmailVerified) ...<Widget>[
            const SizedBox(height: 14),
            const NoticeBanner(
              message: 'Tu correo todavía no está verificado.',
              tone: EzySeverity.warn,
            ),
          ],
          const SizedBox(height: 18),
          EzyTextField(
            label: AccountLabels.name,
            controller: nameController,
            isRequired: true,
            textInputAction: TextInputAction.next,
            errorText: _fieldError(state.errorFields, 'name'),
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: AccountLabels.email,
            controller: emailController,
            isRequired: true,
            keyboardType: TextInputType.emailAddress,
            errorText: _fieldError(state.errorFields, 'email'),
          ),
          if (state.errorFields['photo'] != null) ...<Widget>[
            const SizedBox(height: 8),
            FieldErrorText(message: state.errorFields['photo']!.first),
          ],
          const SizedBox(height: 20),
          EzyButton(
            label: AccountLabels.saveChanges,
            icon: Icons.save_outlined,
            isLoading: state.isSubmitting,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}

/// Bloque "Seguridad": cambio de contraseña (§14.3).
///
/// La contraseña actual la valida el servidor: si no coincide responde
/// `422 invalid_current_password` y ese `message` se muestra en el aviso de la
/// pantalla.
class SecurityCard extends StatelessWidget {
  const SecurityCard({
    super.key,
    required this.state,
    required this.currentPasswordController,
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.onSubmit,
  });

  final ProfileState state;
  final TextEditingController currentPasswordController;
  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AccountLabels.security,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          EzyTextField(
            label: AccountLabels.currentPassword,
            controller: currentPasswordController,
            obscureText: true,
            isRequired: true,
            errorText: _fieldError(state.errorFields, 'current_password'),
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: AccountLabels.newPassword,
            controller: newPasswordController,
            obscureText: true,
            isRequired: true,
            errorText: _fieldError(state.errorFields, 'password'),
          ),
          const SizedBox(height: 16),
          EzyTextField(
            label: AccountLabels.confirmPassword,
            controller: confirmPasswordController,
            obscureText: true,
            isRequired: true,
          ),
          const SizedBox(height: 20),
          EzyButton(
            label: AccountLabels.updatePassword,
            icon: Icons.lock_outline,
            isLoading: state.isSubmitting,
            onPressed: onSubmit,
          ),
        ],
      ),
    );
  }
}

/// Bloque "Sesiones activas": cierra los demás dispositivos y las sesiones web.
class SessionsCard extends StatelessWidget {
  const SessionsCard({
    super.key,
    required this.state,
    required this.onLogoutOthers,
  });

  final ProfileState state;
  final VoidCallback onLogoutOthers;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: AccountLabels.activeSessions,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AccountLabels.activeSessionsMessage,
            style: EzyTextStyles.body.copyWith(
              color: context.surfaces.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'La lista de dispositivos con su token llegará en una entrega '
            'posterior.',
            style: EzyTextStyles.caption.copyWith(
              color: context.surfaces.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          EzyButton(
            label: AccountLabels.logoutOtherDevices,
            icon: Icons.devices_other,
            variant: EzyButtonVariant.outline,
            isLoading: state.isSubmitting,
            onPressed: onLogoutOthers,
          ),
        ],
      ),
    );
  }
}
