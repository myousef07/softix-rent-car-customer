import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'config.dart';
import 'i18n.dart';

/// Thin wrapper over Dio for the customer endpoints (/api/v1/customer): bearer token, JSON,
/// and every failure turned into [ApiException].
class ApiClient {
  /// [adapter] replaces the network in tests.
  ApiClient({String? baseUrl, this.onUnauthorized, HttpClientAdapter? adapter})
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl ?? '${AppConfig.apiBaseUrl}/customer',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          headers: {'Accept': 'application/json'},
        ),
      ) {
    if (adapter != null) _dio.httpClientAdapter = adapter;
    // Messages and status labels come back in the app's language.
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['Accept-Language'] = AppLanguage.current.value;
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final void Function()? onUnauthorized;
  String? _token;

  set token(String? value) {
    _token = value;
    if (value == null) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $value';
    }
  }

  bool get hasToken => _token != null;

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) => _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<Map<String, dynamic>> post(String path, {Object? data}) => _send(() => _dio.post(path, data: data));

  Future<Map<String, dynamic>> patch(String path, {Object? data}) => _send(() => _dio.patch(path, data: data));

  Future<Map<String, dynamic>> delete(String path, {Object? data}) => _send(() => _dio.delete(path, data: data));

  /// Raw bytes of a file behind the token (contract and invoice PDFs).
  Future<List<int>> bytes(String path) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes, headers: {'Accept': 'application/pdf'}),
      );
      return response.data ?? const [];
    } catch (error) {
      final exception = ApiException.from(error);
      if (exception.isUnauthorized) onUnauthorized?.call();
      throw exception;
    }
  }

  Future<Map<String, dynamic>> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final data = response.data;
      return data is Map<String, dynamic> ? data : <String, dynamic>{'data': data};
    } catch (error) {
      final exception = ApiException.from(error);
      if (exception.isUnauthorized) onUnauthorized?.call();
      throw exception;
    }
  }

  Map<String, dynamic>? _clean(Map<String, dynamic>? query) {
    query?.removeWhere((key, value) => value == null || value == '');
    return query;
  }
}
