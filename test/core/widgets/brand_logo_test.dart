import 'package:ezyventas_app/core/theme/app_theme.dart';
import 'package:ezyventas_app/core/widgets/brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asset que esta pintando el logotipo.
String _assetOf(WidgetTester tester) {
  final image = tester.widget<Image>(
    find.descendant(of: find.byType(BrandLogo), matching: find.byType(Image)),
  );

  return (image.image as AssetImage).assetName;
}

Widget _wrap(ThemeData theme, {double height = 80}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: BrandLogo(height: height))),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('usa el logotipo blanco sobre el tema oscuro', (tester) async {
    await tester.pumpWidget(_wrap(EzyTheme.dark()));
    await tester.pump();

    expect(_assetOf(tester), BrandLogo.onDarkAsset);
  });

  testWidgets('usa el logotipo negro sobre el tema claro', (tester) async {
    await tester.pumpWidget(_wrap(EzyTheme.light()));
    await tester.pump();

    expect(_assetOf(tester), BrandLogo.onLightAsset);
  });

  testWidgets('respeta el alto pedido y se anuncia como EzyVentas', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(EzyTheme.dark(), height: 96));
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.height, 96);
    expect(image.fit, BoxFit.contain);
    expect(image.semanticLabel, BrandLogo.label);
    expect(find.bySemanticsLabel(BrandLogo.label), findsOneWidget);
  });

  test('los PNG del logotipo viajan en el bundle de assets', () async {
    for (final asset in <String>[
      BrandLogo.onDarkAsset,
      BrandLogo.onLightAsset,
    ]) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });
}
