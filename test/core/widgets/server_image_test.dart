import 'package:ezyventas_app/core/widgets/server_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `ServerImage`: marcador cuando no hay URL y `Image.network` con la URL que
/// resuelve `AppConfig.mediaUri` (en las pruebas, sin túnel, la misma).
void main() {
  testWidgets('sin URL pinta el marcador de la pantalla', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ServerImage(
          null,
          errorBuilder: (context, error, stackTrace) => const Text('sin foto'),
        ),
      ),
    );

    expect(find.text('sin foto'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('con URL pinta la imagen del servidor', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ServerImage(
          'https://ezyventas2.test/storage/6/iphone.png',
          width: 84,
          height: 66,
          errorBuilder: (context, error, stackTrace) => const Text('sin foto'),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as NetworkImage;

    // Sin `API_HOST_HEADER` (como en las pruebas) la URL no se reescribe.
    expect(provider.url, 'https://ezyventas2.test/storage/6/iphone.png');
    expect(image.width, 84);
    expect(image.height, 66);
  });
}
