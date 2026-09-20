import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';

/// Cliente HTTP único de la app.
///
/// Responsabilidades:
/// - URL base y timeouts desde [AppConfig] (nunca hardcodeada en widgets).
/// - `Authorization: Bearer <token>` y `Accept: application/json`.
/// - Convertir cualquier fallo en [ApiException] (con `message`, `errors` y
///   `code` del servidor).
/// - Avisar al controlador de sesión cuando el servidor responde `401`, para
///   limpiar el token y volver al login.
class ApiClient {
  ApiClient({this.readToken, String? baseUrl}) {
    dio = _buildDio(baseUrl ?? AppConfig.apiBaseUrl);
    dio.interceptors.add(
      InterceptorsWrapper(onRequest: _onRequest, onError: _onError),
    );
  }

  /// Lee el token guardado (lo implementa `SessionStore.readToken`).
  final Future<String?> Function()? readToken;

  late final Dio dio;

  /// Se invoca cuando el servidor responde `401` en un endpoint autenticado.
  void Function()? onUnauthorized;

  static Dio _buildDio(String baseUrl) {
    final client = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.connectTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: <String, dynamic>{
          Headers.acceptHeader: Headers.jsonContentType,
          // Tunel `adb reverse` hacia un vhost `.test` de Herd: el servidor
          // elige el sitio por `Host`. Vacio fuera del entorno local.
          if (AppConfig.apiHostHeader.isNotEmpty)
            'Host': AppConfig.apiHostHeader,
        },
      ),
    );

    // El servidor local usa un certificado autofirmado. Se acepta **solo en
    // modo debug**: en release el certificado se valida siempre.
    if (kDebugMode && AppConfig.allowBadCertificate) {
      final adapter = client.httpClientAdapter;
      if (adapter is IOHttpClientAdapter) {
        adapter.createHttpClient = () {
          final httpClient = HttpClient();
          httpClient.badCertificateCallback = (cert, host, port) => true;
          return httpClient;
        };
      }
    }

    if (kDebugMode) {
      client.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: false,
          logPrint: (line) => debugPrint('[api] $line'),
        ),
      );
    }

    return client;
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await readToken?.call();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    options.headers[Headers.acceptHeader] = Headers.jsonContentType;

    handler.next(options);
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    final statusCode = error.response?.statusCode;
    final isLoginRequest = error.requestOptions.path.endsWith(ApiEndpoints.login);

    if (statusCode == 401 && !isLoginRequest) {
      onUnauthorized?.call();
    }

    final apiException = toApiException(error);

    handler.reject(
      DioException(
        requestOptions: error.requestOptions,
        response: error.response,
        type: error.type,
        error: apiException,
        stackTrace: error.stackTrace,
        message: apiException.message,
      ),
    );
  }

  /// Traduce un [DioException] a [ApiException] conservando el mensaje del
  /// servidor cuando existe.
  ApiException toApiException(DioException error) {
    final embedded = error.error;
    if (embedded is ApiException) {
      return embedded;
    }

    return switch (error.type) {
      DioExceptionType.badResponse => ApiException.fromResponse(
        error.response?.statusCode,
        error.response?.data,
      ),
      DioExceptionType.badCertificate => ApiException.network(),
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.transformTimeout => ApiException.network(),
      DioExceptionType.connectionError => ApiException.network(),
      DioExceptionType.unknown => ApiException.network(),
      DioExceptionType.cancel => ApiException.unexpected(),
    };
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
    Duration? receiveTimeout,
  }) => _send(
    () => dio.get<Object?>(
      path,
      queryParameters: cleanQuery(query),
      options: Options(receiveTimeout: receiveTimeout),
    ),
  );

  /// Respuesta que es una **lista** JSON (p. ej. `GET /catalog/categories`).
  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await dio.get<Object?>(
        path,
        queryParameters: cleanQuery(query),
      );

      return _asMapList(response.data);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  static List<Map<String, dynamic>> _asMapList(Object? data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry('$key', value)))
          .toList(growable: false);
    }

    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) {
          return _asMapList(decoded);
        }
      } on FormatException {
        return const <Map<String, dynamic>>[];
      }
    }

    return const <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) => _send(
    () => dio.post<Object?>(path, data: data, queryParameters: cleanQuery(query)),
  );

  Future<Map<String, dynamic>> putJson(String path, {Object? data}) =>
      _send(() => dio.put<Object?>(path, data: data));

  Future<Map<String, dynamic>> patchJson(String path, {Object? data}) =>
      _send(() => dio.patch<Object?>(path, data: data));

  Future<Map<String, dynamic>> deleteJson(String path, {Object? data}) =>
      _send(() => dio.delete<Object?>(path, data: data));

  /// `multipart/form-data` para evidencias fotográficas (timeout amplio).
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required FormData data,
    String method = 'POST',
  }) => _send(
    () => dio.request<Object?>(
      path,
      data: data,
      options: Options(
        method: method,
        receiveTimeout: AppConfig.uploadTimeout,
        sendTimeout: AppConfig.uploadTimeout,
      ),
    ),
  );

  Future<Map<String, dynamic>> _send(
    Future<Response<Object?>> Function() request,
  ) async {
    try {
      final response = await request();
      return ApiException.decodeBody(response.data) ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Quita los parámetros nulos o vacíos antes de enviarlos.
  static Map<String, dynamic>? cleanQuery(Map<String, dynamic>? query) {
    if (query == null) {
      return null;
    }

    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null && value != '') {
        cleaned[key] = value;
      }
    });

    return cleaned;
  }
}
