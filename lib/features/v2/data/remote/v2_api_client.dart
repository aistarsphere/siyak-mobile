import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/errors/v2_error.dart';
import 'v2_error_mapper.dart';

/// Reusable V2 REST client.
///
/// - Injects the `X-Installation-ID` header (resolved once, cached).
/// - Maps the backend error envelope `{"error":{"code","message","details"}}`
///   to a typed [V2Exception]; connectivity failures → serverOffline/…
/// - One safe retry for idempotent GETs on transient network errors.
/// - Supports request cancellation via [CancelToken].
class V2ApiClient {
  V2ApiClient({
    required String baseUrl,
    required Future<String> Function() installationIdLoader,
    Dio? dio,
  })  : _loadId = installationIdLoader,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              headers: const {'Accept': 'application/json'},
              responseType: ResponseType.json,
            ));

  final Dio _dio;
  final Future<String> Function() _loadId;
  String? _cachedId;

  String get baseUrl => _dio.options.baseUrl;

  Future<String> _installationId() async =>
      _cachedId ??= await _loadId();

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _send(() async => _dio.get<dynamic>(path,
          queryParameters: query,
          cancelToken: cancelToken,
          options: await _opts()));
    } on V2Exception catch (e) {
      if (e.isConnectivity) {
        return _send(() async => _dio.get<dynamic>(path,
            queryParameters: query,
            cancelToken: cancelToken,
            options: await _opts())); // single safe retry
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    CancelToken? cancelToken,
  }) =>
      _send(() async => _dio.post<dynamic>(path,
          data: body ?? const {},
          cancelToken: cancelToken,
          options: await _opts()));

  Future<Map<String, dynamic>> patch(String path, {Object? body}) =>
      _send(() async =>
          _dio.patch<dynamic>(path, data: body ?? const {}, options: await _opts()));

  Future<Options> _opts() async =>
      Options(headers: {'X-Installation-ID': await _installationId()});

  Future<Map<String, dynamic>> _send(
      Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return const {};
    } on DioException catch (e) {
      throw _map(e);
    }
  }

  static V2Exception _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const V2Exception(V2ErrorCode.serverOffline,
            detail: 'timeout');
      case DioExceptionType.connectionError:
        return const V2Exception(V2ErrorCode.tunnelOffline);
      case DioExceptionType.cancel:
        return const V2Exception(V2ErrorCode.unknown, detail: 'cancelled');
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['error'] is Map) {
          final err = data['error'] as Map<String, dynamic>;
          final code = err['code']?.toString();
          // NOT_IN_VOCABULARY is handled by callers (not a hard error), but if
          // it reaches here surface as unknown-word via a dedicated exception.
          if (code == 'NOT_IN_VOCABULARY') {
            return NotInVocabularyException(_suggestionsOf(err));
          }
          return V2Exception(V2ErrorMapper.fromCode(code),
              detail: err['message']?.toString());
        }
        final status = e.response?.statusCode ?? 0;
        if (status == 429) {
          return const V2Exception(V2ErrorCode.rateLimited);
        }
        return const V2Exception(V2ErrorCode.unknown);
      default:
        return const V2Exception(V2ErrorCode.tunnelOffline);
    }
  }

  static List<String> _suggestionsOf(Map<String, dynamic> err) {
    final d = err['details'];
    if (d is Map && d['suggestions'] is List) {
      return (d['suggestions'] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }
}

/// Special case: an out-of-vocabulary guess (HTTP 422) carrying suggestions.
class NotInVocabularyException extends V2Exception {
  const NotInVocabularyException(this.suggestions)
      : super(V2ErrorCode.unknown, detail: 'not_in_vocabulary');

  final List<String> suggestions;
}
