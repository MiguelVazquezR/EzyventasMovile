import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/status_palette.dart';
import '../../../core/utils/external_links.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/ezy_button.dart';
import '../../../core/widgets/ezy_primary_3d_button.dart';
import '../../../core/widgets/ezy_text_field.dart';
import '../../../core/widgets/notice_banner.dart';
import '../../../core/widgets/section_card.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../application/biometrics_service.dart';
import 'widgets/biometric_login_tile.dart';

/// Inicio de sesión (`POST /auth/login`) con acceso biométrico opcional.
///
/// Los errores se muestran **con el mensaje del servidor**: credenciales
/// incorrectas, usuario desactivado, suscripción expirada o límite de intentos.
/// La biometría (huella / Face ID) solo **reanuda** una sesión que ya se guardó
/// cifrada en este teléfono tras un login real; nunca se guardan contraseñas.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  bool _obscurePassword = true;

  /// Deja la sesión abierta en este teléfono (marcado por defecto).
  bool _keepSession = true;

  /// El banner de error del servidor se puede ocultar sin perder su texto.
  bool _errorHidden = false;

  /// Hay sensor biométrico configurado y activo en el teléfono.
  bool _biometricsAvailable = false;

  /// Hay una sesión previa cifrada para entrar con biometría.
  bool _hasBiometricCredentials = false;

  /// La biometría inscrita es de rostro (Face ID) y no de huella.
  bool _biometricIsFace = false;

  /// El prompt biométrico está en curso.
  bool _biometricBusy = false;

  /// Se pidió el ingreso biométrico sin credenciales guardadas: se explica cómo
  /// activarlo en vez de dejar el botón sin respuesta.
  bool _biometricHintVisible = false;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  /// Pregunta al hardware si hay biometría activa y si ya hay credenciales
  /// cifradas de un login previo; solo entonces se muestra la tarjeta.
  Future<void> _initBiometrics() async {
    final service = ref.read(biometricsServiceProvider);

    final available = await service.checkBiometricsAvailable();
    if (!mounted) {
      return;
    }

    if (!available) {
      setState(() => _biometricsAvailable = false);
      return;
    }

    final hasCredentials = await service.hasStoredCredentials();
    final isFace = await service.hasFaceBiometrics();
    if (!mounted) {
      return;
    }

    setState(() {
      _biometricsAvailable = true;
      _hasBiometricCredentials = hasCredentials;
      _biometricIsFace = isFace;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_canSubmit) {
      return;
    }

    if (_errorHidden) {
      setState(() => _errorHidden = false);
    }

    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(
          email: _emailController.text,
          password: _passwordController.text,
          keepSession: _keepSession,
        );

    if (ok) {
      await _rememberBiometrics();
    }
  }

  /// Tras un login real, guarda la sesión cifrada para el acceso biométrico.
  Future<void> _rememberBiometrics() async {
    if (!_biometricsAvailable) {
      return;
    }

    final session = ref.read(authControllerProvider).session;
    if (session == null) {
      return;
    }

    await ref.read(biometricsServiceProvider).saveSession(session);

    if (!mounted) {
      return;
    }

    setState(() {
      _hasBiometricCredentials = true;
      _biometricHintVisible = false;
    });
  }

  /// Autentica con el sensor y, si coincide, reanuda la sesión guardada.
  Future<void> _submitBiometric() async {
    if (_biometricBusy || !_biometricsAvailable) {
      return;
    }

    FocusScope.of(context).unfocus();

    // Sin credenciales guardadas no hay sesión que reanudar: se explica cómo
    // activar el ingreso rápido en vez de dejar el botón sin respuesta.
    if (!_hasBiometricCredentials) {
      setState(() => _biometricHintVisible = true);
      _emailFocusNode.requestFocus();

      return;
    }

    final service = ref.read(biometricsServiceProvider);
    final didAuthenticate = await service.authenticateWithBiometrics();
    if (!didAuthenticate || !mounted) {
      return;
    }

    setState(() => _biometricBusy = true);
    try {
      final stored = await service.readStoredSession();
      if (stored == null) {
        await service.clearCredentials();
        if (mounted) {
          setState(() => _hasBiometricCredentials = false);
        }
        return;
      }

      // La sesión cifrada entra al almacén de la app y se confirma con
      // `GET /auth/me`; si el token ya no sirve, el flujo de `401` limpia todo.
      await ref.read(authRepositoryProvider).saveSession(stored);
      await ref.read(authControllerProvider.notifier).restoreSession();

      // Si el token guardado ya no vale, se olvidan las credenciales para no
      // repetir el prompt contra una sesión muerta.
      if (mounted &&
          ref.read(authControllerProvider).status != AuthStatus.authenticated) {
        await service.clearCredentials();
        if (mounted) {
          setState(() {
            _hasBiometricCredentials = false;
            _biometricHintVisible = true;
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _biometricBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;
    final state = ref.watch(authControllerProvider);
    final showBiometricTile = _biometricsAvailable;

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
                          if (state.errorMessage != null &&
                              !_errorHidden) ...<Widget>[
                            NoticeBanner(
                              message: state.errorMessage!,
                              tone: EzySeverity.danger,
                              icon: Icons.warning_amber_rounded,
                              actionLabel: 'Ocultar',
                              onAction: () =>
                                  setState(() => _errorHidden = true),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (_biometricHintVisible) ...<Widget>[
                            const NoticeBanner(
                              message:
                                  'Ingresa tu correo y contraseña una vez para '
                                  'activar el ingreso rápido con huella o '
                                  'Face ID.',
                              tone: EzySeverity.info,
                              icon: Icons.fingerprint,
                            ),
                            const SizedBox(height: 16),
                          ],
                          const _SecurityBanner(),
                          const SizedBox(height: 16),
                          _buildFields(state),
                          if (showBiometricTile) ...<Widget>[
                            const SizedBox(height: 16),
                            BiometricLoginTile(
                              icon: _biometricIsFace
                                  ? Icons.face
                                  : Icons.fingerprint,
                              enabled: !state.isSubmitting,
                              isBusy: _biometricBusy,
                              onPressed: _submitBiometric,
                            ),
                          ],
                          const SizedBox(height: 16),
                          _buildKeepSession(state),
                          const SizedBox(height: 20),
                          EzyPrimary3dButton(
                            label: 'Iniciar sesión',
                            icon: Icons.login,
                            isLoading: state.isSubmitting,
                            maxWidth: 460,
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
                  const _WebsiteLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Correo y contraseña: radios de 16 px, errores del `422` bajo el input y el
  /// sufijo del ojo («ver contraseña») que no roba el foco del campo.
  Widget _buildFields(AuthState state) {
    final surfaces = context.surfaces;
    final emailError = state.errorFields['email'];
    final passwordError = state.errorFields['password'];

    // Al ocultar la contraseña se muestran puntos monoespaciados y separados,
    // para que se lean como una clave y no como un texto cualquiera.
    final dots = EzyTextStyles.fieldValue.copyWith(
      fontFamily: _obscurePassword ? 'monospace' : EzyTextStyles.fontFamily,
      letterSpacing: _obscurePassword ? 2 : 0,
      color: surfaces.textPrimary,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        EzyTextField(
          label: 'Correo electrónico',
          isRequired: true,
          controller: _emailController,
          focusNode: _emailFocusNode,
          hint: 'usuario@negocio.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofocus: true,
          prefixIcon: Icons.alternate_email,
          borderRadius: 16,
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
          borderRadius: 16,
          textStyle: dots,
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
              color: _obscurePassword ? surfaces.textMuted : EzyColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// «Mantener la sesión abierta»: toda la fila es tocable. Sin marcar, la
  /// sesión vive solo en memoria y al cerrar la app hay que volver a entrar.
  Widget _buildKeepSession(AuthState state) {
    final surfaces = context.surfaces;
    final locked = state.isSubmitting;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: locked
            ? null
            : () => setState(() => _keepSession = !_keepSession),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 40,
              height: 40,
              child: Checkbox(
                value: _keepSession,
                onChanged: locked
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
      ),
    );
  }
}

/// Encabezado de marca: logotipo centrado y el rol de la app.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Column(
      children: <Widget>[
        const BrandLogo(height: 76),
        const SizedBox(height: 12),
        Text(
          'Punto de venta móvil',
          textAlign: TextAlign.center,
          style: EzyTextStyles.secondary.copyWith(color: surfaces.textMuted),
        ),
      ],
    );
  }
}

/// Aviso fijo de seguridad: la sesión viaja cifrada de extremo a extremo.
class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner();

  @override
  Widget build(BuildContext context) {
    return const NoticeBanner(
      message: 'Acceso seguro cifrado con TLS 1.3 · 256-BIT',
      tone: EzySeverity.info,
      icon: Icons.verified_user_outlined,
    );
  }
}

/// Enlace al login de la web, que se abre en el navegador externo.
///
/// Va con el `EzyButton` de variante `text` (§4) en el tono apagado de la
/// superficie: es un enlace secundario y no puede competir con el naranja del
/// CTA ni con el de los avisos.
class _WebsiteLink extends StatelessWidget {
  const _WebsiteLink();

  @override
  Widget build(BuildContext context) {
    final surfaces = context.surfaces;

    return Center(
      child: EzyButton(
        label: AppConfig.websiteUrl.replaceFirst('https://', ''),
        icon: Icons.public,
        variant: EzyButtonVariant.text,
        textColor: surfaces.textSecondary,
        expand: false,
        onPressed: () => ExternalLinks.open(
          context,
          AppConfig.webLoginUrl,
          failureMessage: 'No se pudo abrir el navegador en este teléfono.',
        ),
      ),
    );
  }
}
