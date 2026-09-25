import 'package:ezyventas_app/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AppConfig.mediaUri` / `mediaHeaders`: la reescritura del túnel USB.
///
/// En las pruebas no hay `API_HOST_HEADER` (se pasa por parámetro), así que las
/// dos ramas —con túnel y sin túnel— se comprueban aquí.
void main() {
  group('AppConfig.mediaUri sin túnel (release o dominio real)', () {
    test('deja la URL del servidor tal cual', () {
      final uri = AppConfig.mediaUri('https://ezyventas2.test/storage/6/x.png');

      expect(uri.toString(), 'https://ezyventas2.test/storage/6/x.png');
    });

    test('los headers de medios van vacíos', () {
      expect(AppConfig.mediaHeaders, isEmpty);
    });
  });

  group('AppConfig.mediaUri con el túnel USB', () {
    test('reescribe el host de los medios del servidor al de la API', () {
      final uri = AppConfig.mediaUri(
        'https://ezyventas2.test/storage/6/iphone.png',
        hostHeader: 'ezyventas2.test',
        apiBaseUrlOverride: 'https://127.0.0.1:8443/api/v1',
      );

      expect(uri.toString(), 'https://127.0.0.1:8443/storage/6/iphone.png');
    });

    test('conserva la ruta, la consulta y el puerto del medio', () {
      final uri = AppConfig.mediaUri(
        'https://ezyventas2.test/storage/6/iphone.png?v=2',
        hostHeader: 'ezyventas2.test',
        apiBaseUrlOverride: 'https://127.0.0.1:8443/api/v1',
      );

      expect(uri!.path, '/storage/6/iphone.png');
      expect(uri.query, 'v=2');
      expect(uri.port, 8443);
    });

    test('no toca los hosts externos (avatares, marcadores)', () {
      final uri = AppConfig.mediaUri(
        'https://ui-avatars.com/api/?name=J+A',
        hostHeader: 'ezyventas2.test',
        apiBaseUrlOverride: 'https://127.0.0.1:8443/api/v1',
      );

      expect(uri!.host, 'ui-avatars.com');
    });
  });

  group('AppConfig.mediaRequests (intentos en orden)', () {
    test('sin túnel solo intenta la URL del servidor', () {
      final requests = AppConfig.mediaRequests(
        'https://ezyventas2.test/storage/6/iphone.png',
        hostHeader: '',
        apiBaseUrlOverride: 'https://ezyventas2.test/api/v1',
      );

      expect(requests.length, 1);
      expect(
        requests.single.uri.toString(),
        'https://ezyventas2.test/storage/6/iphone.png',
      );
      expect(requests.single.headers, isEmpty);
    });

    test('con túnel intenta el origen de la API y manda el Host de Herd', () {
      final requests = AppConfig.mediaRequests(
        'https://ezyventas2.test/storage/6/iphone.png',
        hostHeader: 'ezyventas2.test',
        apiBaseUrlOverride: 'https://127.0.0.1:8443/api/v1',
      );

      expect(
        requests.first.uri.toString(),
        'https://127.0.0.1:8443/storage/6/iphone.png',
      );
      expect(requests.first.headers['Host'], 'ezyventas2.test');
      // Segundo intento: la URL original (por si el host resuelve en la red).
      expect(requests.last.uri.host, 'ezyventas2.test');
      expect(requests.last.headers, isEmpty);
    });

    test('los hosts externos (marcadores, avatares) nunca se reescriben', () {
      final requests = AppConfig.mediaRequests(
        'https://placehold.co/400x400/EBF8FF/3182CE?text=Iphone+20',
        hostHeader: 'ezyventas2.test',
        apiBaseUrlOverride: 'https://127.0.0.1:8443/api/v1',
      );

      expect(requests.length, 1);
      expect(requests.single.uri.host, 'placehold.co');
    });

    test('una ruta relativa del servidor se resuelve contra la API', () {
      final requests = AppConfig.mediaRequests(
        '/storage/6/iphone.png',
        hostHeader: '',
        apiBaseUrlOverride: 'https://app.ezyventas.com/api/v1',
      );

      expect(
        requests.single.uri.toString(),
        'https://app.ezyventas.com/storage/6/iphone.png',
      );
    });

    test('sin URL (o en blanco) no hay intentos', () {
      expect(AppConfig.mediaRequests(null), isEmpty);
      expect(AppConfig.mediaRequests('   '), isEmpty);
    });
  });

  group('AppConfig.mediaUri entradas no utilizables', () {
    test('sin URL o en blanco devuelve null', () {
      expect(AppConfig.mediaUri(null), isNull);
      expect(AppConfig.mediaUri('   '), isNull);
    });

    test('una ruta relativa no es una URL de medio', () {
      expect(AppConfig.mediaUri('/storage/6/x.png'), isNull);
    });
  });
}
