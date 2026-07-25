import 'dart:async';
import 'dart:convert';

import 'package:context_game/features/v2/data/remote/v2_api_client.dart';
import 'package:context_game/features/v2/domain/errors/v2_error.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures outgoing request headers and returns a canned response, so we can
/// assert exactly what [V2ApiClient] injects — without any network.
class _CapturingAdapter implements HttpClientAdapter {
  Map<String, dynamic> lastHeaders = {};
  int statusCode;
  String bodyJson;

  _CapturingAdapter({this.statusCode = 200, this.bodyJson = '{"ok":true}'});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    lastHeaders = Map<String, dynamic>.from(options.headers);
    return ResponseBody.fromString(
      bodyJson,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

V2ApiClient _client(
  _CapturingAdapter adapter, {
  String? Function()? token,
  void Function(V2Exception)? onAuth,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x/api/context-game/v2'))
    ..httpClientAdapter = adapter;
  return V2ApiClient(
    baseUrl: 'https://x/api/context-game/v2',
    installationIdLoader: () async => 'inst-123',
    sessionTokenProvider: token,
    onAuthFailure: onAuth,
    dio: dio,
  );
}

void main() {
  test('injects X-Installation-ID and a client X-Request-ID on every call',
      () async {
    final a = _CapturingAdapter();
    await _client(a).get('/wallet');
    expect(a.lastHeaders['X-Installation-ID'], 'inst-123');
    expect(a.lastHeaders['X-Request-ID'], startsWith('req_'));
    expect(a.lastHeaders.containsKey('Authorization'), isFalse,
        reason: 'guests send no bearer');
  });

  test('adds Authorization: Bearer when a session token exists', () async {
    final a = _CapturingAdapter();
    await _client(a, token: () => 'sess_abc').get('/account/me');
    expect(a.lastHeaders['Authorization'], 'Bearer sess_abc');
  });

  test('adds X-Game-Language and Idempotency-Key on writes when supplied',
      () async {
    final a = _CapturingAdapter();
    await _client(a).post('/weekly/runs/wr_1/guess',
        body: {'guess': 'x'}, gameLanguage: 'ar', idempotencyKey: 'idem-1');
    expect(a.lastHeaders['X-Game-Language'], 'ar');
    expect(a.lastHeaders['Idempotency-Key'], 'idem-1');
  });

  test('maps the error envelope to a typed V2Exception with rawCode', () async {
    final a = _CapturingAdapter(
      statusCode: 409,
      bodyJson: jsonEncode({
        'error': {'code': 'NOT_YOUR_TURN', 'message': 'It is not your turn.'},
        'api_version': '2.0',
      }),
    );
    await expectLater(
      _client(a).post('/ranked-matches/rm_1/guess', body: {'guess': 'x'}),
      throwsA(isA<V2Exception>()
          .having((e) => e.code, 'code', V2ErrorCode.notYourTurn)
          .having((e) => e.rawCode, 'rawCode', 'NOT_YOUR_TURN')),
    );
  });

  test('fires onAuthFailure when the session is rejected', () async {
    final a = _CapturingAdapter(
      statusCode: 401,
      bodyJson: jsonEncode({
        'error': {'code': 'SESSION_EXPIRED', 'message': 'Re-authenticate.'},
      }),
    );
    var fired = false;
    await expectLater(
      _client(a, token: () => 'sess_x', onAuth: (_) => fired = true)
          .get('/account/me'),
      throwsA(isA<V2Exception>()),
    );
    expect(fired, isTrue);
  });

  test('surfaces NOT_IN_VOCABULARY with suggestions', () async {
    final a = _CapturingAdapter(
      statusCode: 422,
      bodyJson: jsonEncode({
        'error': {
          'code': 'NOT_IN_VOCABULARY',
          'message': 'nope',
          'details': {'suggestions': ['كتاب', 'علم']},
        },
      }),
    );
    await expectLater(
      _client(a).post('/weekly/runs/wr_1/guess', body: {'guess': 'zzz'}),
      throwsA(isA<NotInVocabularyException>()
          .having((e) => e.suggestions, 'suggestions', ['كتاب', 'علم'])),
    );
  });
}
