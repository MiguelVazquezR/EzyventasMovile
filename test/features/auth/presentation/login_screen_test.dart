import 'package:ezyventas_app/core/api/api_client.dart';
import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:ezyventas_app/core/auth/session_store.dart';
import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/brand_logo.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/auth/data/auth_repository.dart';
import 'package:ezyventas_app/features/auth/data/models/auth_session.dart';
import 'package:ezyventas_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio falso: no toca red ni almacenamiento seguro.
class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({this.failure, this.session})
    : super(api: ApiClient(), sessionStore: SessionStore());

  final ApiException? failure;
  final AuthSession? session;

  String? lastEmail;
  String? lastPassword;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;

    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }

    return session!;
  }

  @override
  Future<AuthSession?> readStoredSession() async => null;

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> saveSession(AuthSession session) async {}
}

Widget _wrap(AuthRepository repository) => ProviderScope(
  overrides: [authRepositoryProvider.overrideWithValue(repository)],
  child: MaterialApp(theme: EzyTheme.dark(), home: const LoginScreen()),
);

void main() {
  testWidgets('muestra el mensaje del servidor cuando el login falla', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      failure: ApiException.fromResponse(422, <String, dynamic>{
        'message': 'Las credenciales no coinciden con nuestros registros.',
        'errors': <String, dynamic>{
          'email': <String>[
            'Las credenciales no coinciden con nuestros registros.',
          ],
        },
      }),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'maria@negocio.com');
    await tester.enterText(find.byType(TextField).last, 'incorrecta');
    await tester.pump();

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(
      find.text('Las credenciales no coinciden con nuestros registros.'),
      findsWidgets,
    );
    expect(repository.lastEmail, 'maria@negocio.com');
    expect(repository.lastPassword, 'incorrecta');
  });

  testWidgets('el botón se habilita solo con correo y contraseña', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    FilledButton submitButton() =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    expect(submitButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'maria@negocio.com');
    await tester.pump();
    expect(submitButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'secreto');
    await tester.pump();
    expect(submitButton().onPressed, isNotNull);
  });

  testWidgets('un login exitoso deja la sesión iniciada', (tester) async {
    final repository = _FakeAuthRepository(
      session: AuthSession.fromJson(<String, dynamic>{
        'token': '5|abc',
        'user': <String, dynamic>{'id': 7, 'name': 'María López'},
        'module_keys': <String>['module_pos'],
      }),
    );

    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: EzyTheme.dark(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'MARIA@negocio.com');
    await tester.enterText(find.byType(TextField).last, 'secreto');
    await tester.pump();

    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();

    final state = container.read(authControllerProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.user?.name, 'María López');
    expect(
      container.read(permissionsProvider).can('pos.access'),
      isFalse,
      reason: 'los permisos los decide el servidor, no la pantalla',
    );
  });

  testWidgets('la cabecera muestra el logotipo de la marca', (tester) async {
    await tester.pumpWidget(_wrap(_FakeAuthRepository()));
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.descendant(of: find.byType(BrandLogo), matching: find.byType(Image)),
    );

    expect(
      (image.image as AssetImage).assetName,
      BrandLogo.onDarkAsset,
      reason: 'el login usa el tema oscuro: toca el logotipo blanco',
    );
  });
}
