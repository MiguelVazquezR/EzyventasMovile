import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/evidence_image.dart';
import '../../../core/widgets/ezy_bottom_sheet.dart';
import '../../../core/widgets/ezy_list_tile.dart';
import '../../../core/widgets/notice_banner.dart';
import '../application/profile_controller.dart';
import '../data/models/user_profile.dart';
import 'account_labels.dart';
import 'widgets/account_scaffold.dart';
import 'widgets/profile_cards.dart';

/// Perfil del usuario (`GET|PUT /profile`, `DELETE /profile/photo`,
/// `PUT /profile/password` y `POST /profile/logout-other-devices`).
///
/// Tres bloques iguales a los de la web: Información personal, Seguridad y
/// Sesiones activas. Todos los errores se muestran con el `message`/`errors` del
/// servidor (p. ej. `422 invalid_current_password`).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  /// Foto elegida y todavía no guardada (se envía con "Guardar cambios").
  EvidenceImage? _pendingPhoto;

  /// Id del usuario con el que se rellenaron los campos.
  int? _prefilledUserId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final state = ref.watch(profileControllerProvider);

    return AccountScaffold(
      title: AccountLabels.profileTitle,
      onRefresh: () async => ref.invalidate(profileProvider),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            ErrorNotice(
              message: error is ApiException
                  ? error.message
                  : 'No pudimos cargar tu perfil.',
              onRetry: () => ref.invalidate(profileProvider),
            ),
          ],
        ),
        data: (user) {
          _prefill(user);

          return _body(user, state);
        },
      ),
    );
  }

  /// Rellena los campos una sola vez por usuario cargado.
  void _prefill(UserProfile user) {
    if (_prefilledUserId == user.id) {
      return;
    }

    _prefilledUserId = user.id;
    _nameController.text = user.name;
    _emailController.text = user.email;
  }

  Widget _body(UserProfile user, ProfileState state) {
    final controller = ref.read(profileControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        if (state.errorMessage != null) ...<Widget>[
          ErrorNotice(
            message: state.errorMessage!,
            onRetry: controller.consumeError,
          ),
          const SizedBox(height: 12),
        ],
        if (state.notice != null) ...<Widget>[
          NoticeBanner(
            message: state.notice!,
            tone: EzySeverity.success,
            actionLabel: 'Ocultar',
            onAction: controller.consumeNotice,
          ),
          const SizedBox(height: 12),
        ],
        PersonalInfoCard(
          user: user,
          state: state,
          nameController: _nameController,
          emailController: _emailController,
          pendingPhoto: _pendingPhoto,
          onPickPhoto: _choosePhotoSource,
          onDeletePhoto: _confirmDeletePhoto,
          onSave: _saveProfile,
        ),
        const SizedBox(height: 12),
        SecurityCard(
          state: state,
          currentPasswordController: _currentPasswordController,
          newPasswordController: _newPasswordController,
          confirmPasswordController: _confirmPasswordController,
          onSubmit: _updatePassword,
        ),
        const SizedBox(height: 12),
        SessionsCard(
          state: state,
          onLogoutOthers: _confirmLogoutOtherDevices,
        ),
      ],
    );
  }

  /// Guarda nombre, correo y (si se eligió) la foto nueva.
  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty || email.isEmpty) {
      return;
    }

    final saved = await ref
        .read(profileControllerProvider.notifier)
        .save(name: name, email: email, photo: _pendingPhoto);

    if (saved && mounted) {
      setState(() => _pendingPhoto = null);
    }
  }

  /// Cambia la contraseña (valida la confirmación en el dispositivo y el resto
  /// en el servidor).
  Future<void> _updatePassword() async {
    final current = _currentPasswordController.text;
    final next = _newPasswordController.text;
    final confirmation = _confirmPasswordController.text;

    if (current.isEmpty || next.isEmpty || confirmation.isEmpty) {
      return;
    }

    final updated = await ref
        .read(profileControllerProvider.notifier)
        .changePassword(
          currentPassword: current,
          password: next,
          confirmation: confirmation,
        );

    if (updated && mounted) {
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    }
  }

  /// Cámara o galería para la foto de perfil (máx. 1 MB, contrato §11b.4).
  Future<void> _choosePhotoSource() async {
    final source = await EzyBottomSheet.show<ImageSource>(
      context,
      title: 'Foto de perfil',
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          EzyListTile(
            icon: Icons.photo_camera_outlined,
            title: 'Tomar foto',
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
          ),
          EzyListTile(
            icon: Icons.photo_library_outlined,
            title: 'Elegir de galería',
            showDivider: false,
            onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
          ),
        ],
      ),
    );

    if (source == null) {
      return;
    }

    EvidencePickResult result;

    try {
      result = source == ImageSource.camera
          ? await EvidencePicker.pickFromCamera(
              maxKb: AppConfig.maxProfilePhotoKb,
            )
          : await EvidencePicker.pickFromGallery(
              limit: 1,
              maxKb: AppConfig.maxProfilePhotoKb,
            );
    } on PlatformException {
      result = const EvidencePickResult.empty();
    }

    final image = result.images.isEmpty ? null : result.images.first;

    if (!mounted) {
      return;
    }

    if (image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AccountLabels.photoFailed)),
      );

      return;
    }

    setState(() => _pendingPhoto = image);
  }

  /// Elimina la foto de perfil (`DELETE /profile/photo`).
  Future<void> _confirmDeletePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AccountLabels.deletePhoto),
        content: const Text(
          'Se quitará tu foto de perfil. Puedes subir otra cuando quieras.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AccountLabels.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AccountLabels.deletePhoto),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false)) {
      return;
    }

    final deleted = await ref
        .read(profileControllerProvider.notifier)
        .deletePhoto();

    if (deleted && mounted) {
      setState(() => _pendingPhoto = null);
    }
  }

  /// "Cerrar otras sesiones": pide la contraseña en un diálogo y confirma.
  Future<void> _confirmLogoutOtherDevices() async {
    final passwordController = TextEditingController();

    try {
      final entered = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text(AccountLabels.confirmClose),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(AccountLabels.confirmCloseMessage),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: AccountLabels.password,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(AccountLabels.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(passwordController.text),
              child: const Text(AccountLabels.logoutOtherDevices),
            ),
          ],
        ),
      );

      final password = (entered ?? '').trim();

      if (password.isEmpty) {
        return;
      }

      await ref
          .read(profileControllerProvider.notifier)
          .logoutOtherDevices(password);
    } finally {
      passwordController.dispose();
    }
  }
}


