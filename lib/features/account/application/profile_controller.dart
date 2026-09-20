import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/utils/evidence_image.dart';
import '../../auth/application/auth_controller.dart';
import 'account_providers.dart';
import '../data/models/user_profile.dart';

/// Perfil del usuario (`GET /profile`).
final profileProvider = FutureProvider<UserProfile>(
  (ref) => ref.watch(accountRepositoryProvider).fetchProfile(),
);

/// Estado de las operaciones del perfil.
class ProfileState {
  const ProfileState({
    this.isSubmitting = false,
    this.errorMessage,
    this.notice,
    this.errorFields = const <String, List<String>>{},
    this.emailVerificationSent = false,
    this.photoJustDeleted = false,
  });

  /// Petición en curso (el botón muestra su spinner).
  final bool isSubmitting;

  /// `message` del servidor (nunca un texto inventado).
  final String? errorMessage;

  /// Confirmación con el `message` del servidor.
  final String? notice;

  /// `errors` del `422`, para pintarlos bajo cada campo.
  final Map<String, List<String>> errorFields;

  /// El servidor envió el código de verificación al nuevo correo.
  final bool emailVerificationSent;

  /// La última operación exitosa borró la foto.
  final bool photoJustDeleted;

  ProfileState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    String? notice,
    Map<String, List<String>>? errorFields,
    bool? emailVerificationSent,
    bool? photoJustDeleted,
    bool clearError = false,
    bool clearNotice = false,
  }) {
    return ProfileState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      notice: clearNotice ? null : (notice ?? this.notice),
      errorFields: clearError
          ? const <String, List<String>>{}
          : (errorFields ?? this.errorFields),
      emailVerificationSent:
          emailVerificationSent ?? this.emailVerificationSent,
      photoJustDeleted: photoJustDeleted ?? this.photoJustDeleted,
    );
  }
}

/// Edición del perfil: datos personales, foto, contraseña y otras sesiones.
///
/// La app no valida reglas de negocio (unicidad del correo, contraseña actual):
/// envía el formulario y muestra el `message`/`errors` del servidor.
class ProfileController extends Notifier<ProfileState> {
  @override
  ProfileState build() => const ProfileState();

  /// `PUT /profile`. Devuelve `true` si el servidor guardó los cambios.
  Future<bool> save({
    required String name,
    required String email,
    EvidenceImage? photo,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .updateProfile(name: name, email: email, photo: photo);

      state = state.copyWith(
        isSubmitting: false,
        notice: result.message,
        emailVerificationSent: result.emailVerificationSent,
        photoJustDeleted: false,
      );

      ref.invalidate(profileProvider);

      // El nombre o el correo pueden cambiar el contexto guardado
      // (`email_verified_at` vuelve a null): se refresca desde `/auth/me`.
      await ref.read(authControllerProvider.notifier).refreshContext();

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
        errorFields: error.errors,
      );

      return false;
    }
  }

  /// `DELETE /profile/photo`.
  Future<bool> deletePhoto() async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .deleteProfilePhoto();

      state = state.copyWith(
        isSubmitting: false,
        notice: result.message,
        photoJustDeleted: true,
        emailVerificationSent: false,
      );

      ref.invalidate(profileProvider);

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
        errorFields: error.errors,
      );

      return false;
    }
  }

  /// `PUT /profile/password` (bloque "Seguridad").
  ///
  /// Con la contraseña actual incorrecta el servidor responde
  /// `422 invalid_current_password` y la app muestra ese `message`.
  Future<bool> changePassword({
    required String currentPassword,
    required String password,
    required String confirmation,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .updatePassword(
            currentPassword: currentPassword,
            password: password,
            passwordConfirmation: confirmation,
          );

      state = state.copyWith(
        isSubmitting: false,
        notice: result.message,
        emailVerificationSent: false,
      );

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
        errorFields: error.errors,
      );

      return false;
    }
  }

  /// `POST /profile/logout-other-devices` (bloque "Sesiones activas").
  ///
  /// Este teléfono conserva su token; los demás dispositivos y las sesiones web
  /// se cierran.
  Future<bool> logoutOtherDevices(String password) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearNotice: true,
    );

    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .logoutOtherDevices(password);

      state = state.copyWith(
        isSubmitting: false,
        notice: result.message,
        emailVerificationSent: false,
      );

      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.message,
        errorFields: error.errors,
      );

      return false;
    }
  }

  void consumeNotice() {
    if (state.notice != null) {
      state = state.copyWith(clearNotice: true);
    }
  }

  void consumeError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);

