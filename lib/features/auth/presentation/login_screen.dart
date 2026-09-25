import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/external_links.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/ezy_text_field.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

/// Inicio de sesión (`POST /auth/login`).
///
/// Los errores se muestran **con el mensaje del servidor**: credenciales
/// incorrectas, usuario desactivado, suscripción expirada o límite de intentos.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// Deja la sesión abierta en este teléfono (marcado por defecto).
  bool _keepSession = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_canSubmit) {
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
          keepSession: _keepSession,
        );
  }


  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final state = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _BrandHeader(),
                  const SizedBox(height: 24),
                  SectionCard(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          if (state.notice != null) ...<Widget>[
                            NoticeBanner(
                              message: state.notice!,
                              tone: EzySeverity.info,
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (state.errorMessage != null) ...<Widget>[
                            NoticeBanner(
                              message: state.errorMessage!,
                              tone: EzySeverity.danger,
                            ),
                            const SizedBox(height: 16),
                          ],
                          _buildFields(state),
                          const SizedBox(height: 8),
                          _buildKeepSession(state),
                          const SizedBox(height: 20),
                          EzyButton(
                            label: 'Iniciar sesión',
                            icon: Icons.login,
                            isLoading: state.isSubmitting,
                            onPressed: _canSubmit ? _submit : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Al iniciar sesión se registra este dispositivo para que '
                    'puedas cerrar su sesión por separado.',
                    textAlign: TextAlign.center,
                    style: EzyTextStyles.secondary.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _WebsiteLink(surfaces: surfaces),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Mantener la sesión abierta": sin marcar, la sesión vive solo en memoria y
  /// al cerrar la app hay que volver a iniciar sesión.
  Widget _buildKeepSession(AuthState state) {
    final surfaces = context.surfaces;

    return GestureDetector(
      onTap: state.isSubmitting
          ? null
          : () => setState(() => _keepSession = !_keepSession),
      behavior: HitTestBehavior.opaque,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 40,
            height: 40,
            child: Checkbox(
              value: _keepSession,
              onChanged: state.isSubmitting
                  ? null
                  : (value) => setState(() => _keepSession = value ?? true),
              activeColor: EzyColors.primary,
              checkColor: EzyColors.black1,
              side: BorderSide(color: surfaces.borderStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Mantener la sesión abierta',
                    style: EzyTextStyles.bodyStrong.copyWith(
                      color: surfaces.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No tendrás que escribir tus datos otra vez en este '
                    'teléfono.',
                    style: EzyTextStyles.caption.copyWith(
                      color: surfaces.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Campos del formulario. El botón permanece deshabilitado hasta que ambos
  /// tengan contenido, así no se gastan intentos del límite del servidor.
  Widget _buildFields(AuthState state) {
    final surfaces = context.surfaces;
    final emailError = state.errorFields['email'];
    final passwordError = state.errorFields['password'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EzyTextField(
          label: 'Correo electrónico',
          isRequired: true,
          controller: _emailController,
          hint: 'usuario@negocio.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofocus: true,
          prefixIcon: Icons.alternate_email,
          enabled: !state.isSubmitting,
          errorText: (emailError != null && emailError.isNotEmpty)
              ? emailError.first
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        EzyTextField(
          label: 'Contraseña',
          isRequired: true,
          controller: _passwordController,
          hint: '••••••••',
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          prefixIcon: Icons.lock_outline,
          enabled: !state.isSubmitting,
          errorText: (passwordError != null && passwordError.isNotEmpty)
              ? passwordError.first
              : null,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
          suffix: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            tooltip: _obscurePassword
                ? 'Mostrar contraseña'
                : 'Ocultar contraseña',
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: surfaces.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Enlace directo al sitio web de EzyVentas (login de la web).
///
/// Sustituye a la URL base de la API que se mostraba en modo debug: en su lugar
/// se ofrece la dirección que sí le sirve a la persona que tiene el teléfono.
class _WebsiteLink extends StatelessWidget {
  const _WebsiteLink({required this.surfaces});

  final EzySurfaces surfaces;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => ExternalLinks.open(
        context,
        AppConfig.webLoginUrl,
        failureMessage: 'No se pudo abrir el navegador en este teléfono.',
      ),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(
        AppConfig.websiteUrl.replaceFirst('https://', ''),
        style: EzyTextStyles.button.copyWith(color: surfaces.textSecondary),
      ),
      style: TextButton.styleFrom(foregroundColor: surfaces.textSecondary),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      children: <Widget>[
        const BrandLogo(height: 80),
        const SizedBox(height: 14),
        Text(
          'Punto de venta y órdenes de servicio',
          textAlign: TextAlign.center,
          style: EzyTextStyles.secondary.copyWith(
            color: surfaces.textSecondary,
          ),
        ),
      ],
    );
  }
}
