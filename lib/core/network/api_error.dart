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
  const ApiException(this.type, {this.detail, this.statusCode, this.body});

  final ApiErrorType type;

  /// Server-provided message (FastAPI `detail` field), when available.
  final String? detail;
  final int? statusCode;

  /// The decoded error body, kept whole.
  ///
  /// This API answers some failures with a *typed* payload — a `code` such as
  /// `NO_ACTIVE_RELEASE` plus the data needed to recover from it. Collapsing
  /// that to [detail] threw the type away and left the UI guessing from an HTTP
  /// status, so callers that understand a code can read it here.
  final Map<String, dynamic>? body;

  bool get isInvalidWord => type == ApiErrorType.badRequest;

  /// True for "can't reach the backend" failures — no connectivity, DNS
  /// failure, connection refused, timeout, or a tunnel 502/503/504. These
  /// drive the friendly backend-offline screen.
  bool get isConnectivity =>
      type == ApiErrorType.network ||
      type == ApiErrorType.timeout ||
      type == ApiErrorType.unknown ||
      (type == ApiErrorType.server &&
          (statusCode == null ||
              statusCode == 502 ||
              statusCode == 503 ||
              statusCode == 504));

  /// Classify an arbitrary caught error as a connectivity failure.
  static bool isOffline(Object? error) =>
      error is ApiException && error.isConnectivity;

  @override
  String toString() =>
      'ApiException($type, status: $statusCode, detail: $detail)';
}
