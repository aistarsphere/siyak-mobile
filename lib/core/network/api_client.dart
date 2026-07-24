import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_error.dart';

/// Thin Dio wrapper: JSON in/out, typed [ApiException]s, and a single safe
/// retry for idempotent GETs that fail on transient network errors.
class ApiClient {
  ApiClient({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              headers: const {'Accept': 'application/json'},
              responseType: ResponseType.json,
            ),
          );

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;
  set baseUrl(String url) => _dio.options.baseUrl = url;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _requestJson(
        () => _dio.get<dynamic>(path, queryParameters: query),
      );
    } on ApiException catch (e) {
      // One safe retry: GETs on this API are idempotent.
      if (e.type == ApiErrorType.network || e.type == ApiErrorType.timeout) {
        return _requestJson(
          () => _dio.get<dynamic>(path, queryParameters: query),
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) =>
      _requestJson(() => _dio.post<dynamic>(path, data: body));

  Future<Map<String, dynamic>> _requestJson(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      final res = await send();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      throw const ApiException(ApiErrorType.server);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  static ApiException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(ApiErrorType.timeout);
      case DioExceptionType.connectionError:
        return const ApiException(ApiErrorType.network);
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final detail = _extractDetail(e.response?.data);
        // 400/422 = client-side validation (e.g. bad input) → badRequest.
        if (status == 400 || status == 422) {
          return ApiException(
            ApiErrorType.badRequest,
            detail: detail,
            statusCode: status,
          );
        }
        return ApiException(
          ApiErrorType.server,
          detail: detail,
          statusCode: status,
        );
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      default:
        return const ApiException(ApiErrorType.unknown);
    }
  }

  /// FastAPI returns `detail` as either a string or a validation-error list.
  static String? _extractDetail(dynamic data) {
    if (data is! Map<String, dynamic>) return null;
    final d = data['detail'];
    if (d is String) return d;
    if (d is List && d.isNotEmpty) {
      final first = d.first;
      if (first is Map && first['msg'] != null) return first['msg'].toString();
    }
    return null;
  }
}
