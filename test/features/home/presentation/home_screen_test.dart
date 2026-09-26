import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/features/auth/application/auth_controller.dart';
import 'package:ezyventas_app/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../core/auth/auth_harness.dart';

/// Monta la pestaña Inicio con los permisos y módulos indicados.
///
/// No se concede `transactions.access` a propósito: sin ese permiso la cabecera
/// no pinta la campana y la prueba no depende de `GET /notifications`.
Future<void> _pumpHome(
  WidgetTester tester, {
  required List<String> permissions,
  required List<String> modules,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(
            session: fakeSession(permissions: permissions, modules: modules),
          ),
        ),
      ],
      child: MaterialApp(theme: EzyTheme.dark(), home: const HomeScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('bienvenida con el nombre del usuario y sus accesos', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      permissions: <String>['pos.access'],
      modules: <String>['module_pos'],
    );

    expect(find.text('¡Bienvenido!'), findsOneWidget);
    expect(find.text('Hola, Miguel Osvaldo'), findsOneWidget);
    expect(find.textContaining('Estamos preparando el resumen'), findsOneWidget);

    // Las pistas son las del usuario: POS y Caja, pero no Órdenes ni Ventas.
    expect(find.text('Vender'), findsOneWidget);
    expect(find.text('Caja'), findsOneWidget);
    expect(find.text('Órdenes de servicio'), findsNothing);
    expect(find.text('Ventas'), findsNothing);
  });

  testWidgets('sin módulos contratados avisa y no ofrece atajos', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      permissions: <String>[],
      modules: <String>[],
    );

    expect(
      find.textContaining('Tu suscripción no tiene módulos activos'),
      findsOneWidget,
    );
    expect(find.text('Vender'), findsNothing);
    expect(find.text('Caja'), findsNothing);
    expect(find.text('¡Bienvenido!'), findsOneWidget);
  });
}
