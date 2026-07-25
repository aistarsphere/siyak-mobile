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
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

/// A scripted server: protected endpoints accept only [acceptedToken];
/// `/auth/refresh` rotates the token to `sess_new` after a small delay so
/// concurrent callers overlap. Counts refreshes to assert single-flight.
class _RotatingAdapter implements HttpClientAdapter {
  _RotatingAdapter({this.refreshStatus = 200});
  final String acceptedToken = 'sess_new';
  final int refreshStatus;
  int refreshCalls = 0;
  int protectedCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (path.endsWith('/auth/refresh')) {
      refreshCalls++;
      await Future<void>.delayed(const Duration(milliseconds: 25));
      return _resp(
        refreshStatus,
        refreshStatus == 200
            ? '{"session_token":"sess_new"}'
            : '{"error":{"code":"SESSION_REVOKED","message":"no"}}',
      );
    }
    protectedCalls++;
    if (options.headers['Authorization'] == 'Bearer $acceptedToken') {
      return _resp(200, '{"ok":true}');
    }
    return _resp(401, '{"error":{"code":"SESSION_EXPIRED","message":"stale"}}');
  }

  ResponseBody _resp(int code, String body) => ResponseBody.fromString(
    body,
    code,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

V2ApiClient _rotatingClient(
  _RotatingAdapter adapter,
  _TokenBox box, {
  void Function(V2Exception)? onAuth,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x/api/context-game/v2'))
    ..httpClientAdapter = adapter;
  return V2ApiClient(
    baseUrl: 'https://x/api/context-game/v2',
    installationIdLoader: () async => 'inst-123',
    sessionTokenProvider: () => box.token,
    onTokenRotated: (t) async => box.token = t,
    onAuthFailure: onAuth,
    dio: dio,
  );
}

class _TokenBox {
  _TokenBox(this.token);
  String? token;
}

void main() {
  test(
    'injects X-Installation-ID and a client X-Request-ID on every call',
    () async {
      final a = _CapturingAdapter();
      await _client(a).get('/wallet');
      expect(a.lastHeaders['X-Installation-ID'], 'inst-123');
      expect(a.lastHeaders['X-Request-ID'], startsWith('req_'));
      expect(
        a.lastHeaders.containsKey('Authorization'),
        isFalse,
        reason: 'guests send no bearer',
      );
    },
  );

  test('adds Authorization: Bearer when a session token exists', () async {
    final a = _CapturingAdapter();
    await _client(a, token: () => 'sess_abc').get('/account/me');
    expect(a.lastHeaders['Authorization'], 'Bearer sess_abc');
  });

  test(
    'adds X-Game-Language and Idempotency-Key on writes when supplied',
    () async {
      final a = _CapturingAdapter();
      await _client(a).post(
        '/weekly/runs/wr_1/guess',
        body: {'guess': 'x'},
        gameLanguage: 'ar',
        idempotencyKey: 'idem-1',
      );
      expect(a.lastHeaders['X-Game-Language'], 'ar');
      expect(a.lastHeaders['Idempotency-Key'], 'idem-1');
    },
  );

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
      throwsA(
        isA<V2Exception>()
            .having((e) => e.code, 'code', V2ErrorCode.notYourTurn)
            .having((e) => e.rawCode, 'rawCode', 'NOT_YOUR_TURN'),
      ),
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
      _client(
        a,
        token: () => 'sess_x',
        onAuth: (_) => fired = true,
      ).get('/account/me'),
      throwsA(isA<V2Exception>()),
    );
    expect(fired, isTrue);
  });

  test('rotates the session on a refreshable 401 and retries once', () async {
    final a = _RotatingAdapter();
    final box = _TokenBox('sess_old');
    final res = await _rotatingClient(a, box).get('/account/me');
    expect(res['ok'], isTrue);
    expect(box.token, 'sess_new', reason: 'rotated token persisted atomically');
    expect(a.refreshCalls, 1);
    expect(a.protectedCalls, 2, reason: 'original 401 + one retry');
  });

  test('concurrent refreshable 401s trigger exactly ONE refresh', () async {
    final a = _RotatingAdapter();
    final box = _TokenBox('sess_old');
    final client = _rotatingClient(a, box);
    final results = await Future.wait([
      client.get('/account/me'),
      client.get('/wallet'),
      client.get('/profiles/me'),
    ]);
    expect(results.every((r) => r['ok'] == true), isTrue);
    expect(
      a.refreshCalls,
      1,
      reason: 'single-flight: 3 concurrent 401s coalesce to one rotation',
    );
    expect(box.token, 'sess_new');
  });

  test('clears session (onAuthFailure) when refresh itself fails', () async {
    final a = _RotatingAdapter(refreshStatus: 401);
    final box = _TokenBox('sess_old');
    var fired = false;
    await expectLater(
      _rotatingClient(a, box, onAuth: (_) => fired = true).get('/account/me'),
      throwsA(isA<V2Exception>()),
    );
    expect(fired, isTrue);
    expect(a.refreshCalls, 1, reason: 'one refresh attempt, no loop');
  });

  test('SESSION_REVOKED is unrecoverable — no refresh, clears immediately', () async {
    final a = _CapturingAdapter(
      statusCode: 401,
      bodyJson: jsonEncode({
        'error': {'code': 'SESSION_REVOKED', 'message': 'revoked'},
      }),
    );
    var fired = false;
    await expectLater(
      _client(a, token: () => 'sess_x', onAuth: (_) => fired = true)
          .get('/account/me'),
      throwsA(
        isA<V2Exception>().having(
          (e) => e.code,
          'code',
          V2ErrorCode.sessionRevoked,
        ),
      ),
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
          'details': {
            'suggestions': ['كتاب', 'علم'],
          },
        },
      }),
    );
    await expectLater(
      _client(a).post('/weekly/runs/wr_1/guess', body: {'guess': 'zzz'}),
      throwsA(
        isA<NotInVocabularyException>().having(
          (e) => e.suggestions,
          'suggestions',
          ['كتاب', 'علم'],
        ),
      ),
    );
  });
}
