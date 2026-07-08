/// Typed API failures, mapped to user-friendly localized messages in the UI.
enum ApiErrorType {
  /// No connectivity / DNS / socket failure.
  network,

  /// Connect or receive timeout.
  timeout,

  /// HTTP 400 with a `detail` payload — e.g. an invalid guess word.
  badRequest,

  /// 5xx or malformed server response.
  server,

  unknown,
}

class ApiException implements Exception {
  const ApiException(this.type, {this.detail, this.statusCode});

  final ApiErrorType type;

  /// Server-provided message (FastAPI `detail` field), when available.
  final String? detail;
  final int? statusCode;

  bool get isInvalidWord => type == ApiErrorType.badRequest;

  @override
  String toString() =>
      'ApiException($type, status: $statusCode, detail: $detail)';
}
