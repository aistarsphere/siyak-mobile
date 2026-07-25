import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/errors/v2_error.dart';
import 'v2_error_mapper.dart';

/// Reusable V2 REST client.
///
/// - Injects `X-Installation-ID` (guest identity, resolved once & cached) and,
///   when a session exists, `Authorization: Bearer <session_token>` (account).
/// - Adds a client `X-Request-ID` to every call for log correlation; adds
///   `X-Game-Language` and `Idempotency-Key` per request when supplied.
/// - Maps the backend error envelope `{"error":{"code","message","details"}}`
///   to a typed [V2Exception]; connectivity failures → serverOffline/…
/// - Notifies [onAuthFailure] on session-invalidation responses so the app can
///   clear the token and prompt re-authentication.
/// - One safe retry for idempotent GETs on transient network errors.
class V2ApiClient {
  V2ApiClient({
    required String baseUrl,
    required Future<String> Function() installationIdLoader,
    String? Function()? sessionTokenProvider,
    void Function(V2Exception error)? onAuthFailure,
    Dio? dio,
  })  : _loadId = installationIdLoader,
        _sessionToken = sessionTokenProvider,
        // ignore: prefer_initializing_formals
        _onAuthFailure = onAuthFailure,
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
  final String? Function()? _sessionToken;
  final void Function(V2Exception error)? _onAuthFailure;
  final Uuid _uuid = const Uuid();
  String? _cachedId;

  String get baseUrl => _dio.options.baseUrl;

  Future<String> _installationId() async => _cachedId ??= await _loadId();

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
    String? gameLanguage,
    String? idempotencyKey,
  }) =>
      _send(() async => _dio.post<dynamic>(path,
          data: body ?? const {},
          cancelToken: cancelToken,
          options: await _opts(
            gameLanguage: gameLanguage,
            idempotencyKey: idempotencyKey,
          )));

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    String? idempotencyKey,
  }) =>
      _send(() async => _dio.patch<dynamic>(path,
          data: body ?? const {},
          options: await _opts(idempotencyKey: idempotencyKey)));

  Future<Map<String, dynamic>> delete(String path, {Object? body}) =>
      _send(() async =>
          _dio.delete<dynamic>(path, data: body, options: await _opts()));

  Future<Options> _opts({String? gameLanguage, String? idempotencyKey}) async {
    final headers = <String, String>{
      'X-Installation-ID': await _installationId(),
      'X-Request-ID': 'req_${_uuid.v4().replaceAll('-', '').substring(0, 16)}',
    };
    final token = _sessionToken?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (gameLanguage != null) headers['X-Game-Language'] = gameLanguage;
    if (idempotencyKey != null) headers['Idempotency-Key'] = idempotencyKey;
    return Options(headers: headers);
  }

  Future<Map<String, dynamic>> _send(
      Future<Response<dynamic>> Function() run) async {
    try {
      final res = await run();
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return const {};
    } on DioException catch (e) {
      final mapped = _map(e);
      if (mapped.isAuthFailure) _onAuthFailure?.call(mapped);
      throw mapped;
    }
  }

  static V2Exception _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const V2Exception(V2ErrorCode.serverOffline, detail: 'timeout');
      case DioExceptionType.connectionError:
        return const V2Exception(V2ErrorCode.tunnelOffline);
      case DioExceptionType.cancel:
        return const V2Exception(V2ErrorCode.unknown, detail: 'cancelled');
      case DioExceptionType.badResponse:
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['error'] is Map) {
          final err = data['error'] as Map<String, dynamic>;
          final code = err['code']?.toString();
          // NOT_IN_VOCABULARY is handled by callers (not a hard error).
          if (code == 'NOT_IN_VOCABULARY') {
            return NotInVocabularyException(_suggestionsOf(err));
          }
          return V2Exception(
            V2ErrorMapper.fromCode(code),
            detail: err['message']?.toString(),
            rawCode: code,
          );
        }
        final status = e.response?.statusCode ?? 0;
        if (status == 401) {
          return const V2Exception(V2ErrorCode.authenticationRequired);
        }
        if (status == 429) return const V2Exception(V2ErrorCode.rateLimited);
        if (status == 503) {
          return const V2Exception(V2ErrorCode.backendUnavailable);
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
      : super(V2ErrorCode.notInVocabulary, detail: 'not_in_vocabulary');

  final List<String> suggestions;
}
