import 'package:ezyventas_app/core/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiException.fromResponse', () {
    test('422 de credenciales: mensaje y errores por campo', () {
      final error = ApiException.fromResponse(422, <String, dynamic>{
        'message': 'Las credenciales no coinciden con nuestros registros.',
        'errors': <String, dynamic>{
          'email': <String>['Las credenciales no coinciden con nuestros registros.'],
        },
      });

      expect(error.statusCode, 422);
      expect(
        error.message,
        'Las credenciales no coinciden con nuestros registros.',
      );
      expect(error.isValidation, isTrue);
      expect(error.errorFor('email'), contains('credenciales'));
      expect(error.hasFieldErrors, isTrue);
    });

    test('422 de negocio: conserva el código para decidir el flujo', () {
      final error = ApiException.fromResponse(422, <String, dynamic>{
        'code': 'cash_register_in_use',
        'message': 'La terminal ya está en uso por otro usuario.',
      });

      expect(error.code, 'cash_register_in_use');
      expect(error.message, 'La terminal ya está en uso por otro usuario.');
    });

    test('403 sin cuerpo usa el mensaje por defecto del servidor', () {
      final error = ApiException.fromResponse(403, null);

      expect(error.isForbidden, isTrue);
      expect(error.message, 'Tu usuario no tiene permiso para esta acción.');
    });

    test('401 y 404 usan los textos del backend', () {
      expect(
        ApiException.fromResponse(401, null).message,
        'No autenticado.',
      );
      expect(
        ApiException.fromResponse(404, null).message,
        'Recurso no encontrado.',
      );
      expect(ApiException.fromResponse(401, null).isUnauthorized, isTrue);
      expect(ApiException.fromResponse(404, null).isNotFound, isTrue);
    });

    test('decodifica un cuerpo que llega como texto JSON', () {
      final error = ApiException.fromResponse(
        422,
        '{"message":"El fondo de caja inicial es obligatorio."}',
      );

      expect(error.message, 'El fondo de caja inicial es obligatorio.');
    });

    test('cuerpo ilegible no rompe: cae al texto por defecto', () {
      final error = ApiException.fromResponse(500, '<html>error</html>');

      expect(error.message, 'Ocurrió un error en el servidor. Inténtalo de nuevo.');
    });

    test('errors.status[0] queda accesible (cambio de estatus)', () {
      final error = ApiException.fromResponse(422, <String, dynamic>{
        'message': 'El estatus ya fue registrado.',
        'errors': <String, dynamic>{
          'status': <String>['El estatus ya fue registrado.'],
        },
      });

      expect(error.errorFor('status'), 'El estatus ya fue registrado.');
      expect(error.errorFor('desconocido'), isNull);
    });
  });

  group('ApiException de red', () {
    test('usa el microcopy aprobado y marca el fallo de conexión', () {
      final error = ApiException.network();

      expect(error.isNetworkError, isTrue);
      expect(
        error.message,
        'No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
      expect(error.statusCode, isNull);
    });
  });
}
