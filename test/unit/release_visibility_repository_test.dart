import 'package:context_game/features/v2/data/remote/remote_release_visibility_repository.dart';
import 'package:context_game/features/v2/data/remote/v2_api_client.dart';
import 'package:context_game/features/v2/domain/entities/release_visibility.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repository contract, exercised against a real [V2ApiClient] over a stubbed
/// Dio adapter — so the assertions cover the headers the client actually sends,
/// not a hand-rolled fake of it.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.respond);

  /// Called with each request; returns the canned response.
  final ResponseBody Function(RequestOptions options) respond;

  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Map<String, dynamic> body, {int status = 200}) =>
    ResponseBody.fromString(
      _encode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

String _encode(Object? v) {
  if (v is Map) {
    return '{${v.entries.map((e) => '"${e.key}":${_encode(e.value)}').join(',')}}';
  }
  if (v is List) return '[${v.map(_encode).join(',')}]';
  if (v is String) return '"$v"';
  return '$v';
}

void main() {
  const installationId = '11111111-2222-4333-8444-555555555555';

  ({RemoteReleaseVisibilityRepository repo, _StubAdapter adapter}) build({
    required ResponseBody Function(RequestOptions) respond,
    String? sessionToken,
  }) {
    final adapter = _StubAdapter(respond);
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter;
    final client = V2ApiClient(
      baseUrl: 'https://example.test/api/v1',
      installationIdLoader: () async => installationId,
      sessionTokenProvider: () => sessionToken,
      dio: dio,
    );
    return (repo: RemoteReleaseVisibilityRepository(client), adapter: adapter);
  }

  group('endpoint and auth', () {
    test('calls exactly GET /release-visibility', () async {
      final h = build(respond: (_) => _json({'visible': false}));
      await h.repo.fetch();

      expect(h.adapter.requests, hasLength(1));
      final req = h.adapter.requests.single;
      expect(req.method, 'GET');
      expect(req.path, '/release-visibility');
      expect(req.uri.path, '/api/v1/release-visibility');
    });

    test('never touches an /admin/* route', () async {
      final h = build(respond: (_) => _json({'visible': false}));
      await h.repo.fetch(language: 'ar');

      for (final r in h.adapter.requests) {
        expect(r.uri.toString(), isNot(contains('/admin')));
      }
      expect(RemoteReleaseVisibilityRepository.path, '/release-visibility');
    });

    test('guest: sends X-Installation-ID and no bearer', () async {
      final h = build(respond: (_) => _json({'visible': false}));
      await h.repo.fetch();

      final headers = h.adapter.requests.single.headers;
      expect(headers['X-Installation-ID'], installationId);
      expect(headers.containsKey('Authorization'), isFalse);
    });

    test('account: sends the session bearer', () async {
      final h = build(
        respond: (_) => _json({'visible': false}),
        sessionToken: 'sess_abc123',
      );
      await h.repo.fetch();

      final headers = h.adapter.requests.single.headers;
      expect(headers['Authorization'], 'Bearer sess_abc123');
      // The either/or rule: the installation id still rides along, which is what
      // the shared client does for every call.
      expect(headers['X-Installation-ID'], installationId);
    });
  });

  group('optional language query', () {
    test('is sent when supplied', () async {
      final h = build(respond: (_) => _json({'visible': false}));
      await h.repo.fetch(language: 'ar');
      expect(h.adapter.requests.single.uri.queryParameters['language'], 'ar');
    });

    test(
      'is omitted when null or empty, letting the server default it',
      () async {
        final h = build(respond: (_) => _json({'visible': false}));
        await h.repo.fetch();
        await h.repo.fetch(language: '');
        for (final r in h.adapter.requests) {
          expect(r.uri.queryParameters.containsKey('language'), isFalse);
        }
      },
    );
  });

  group('failure is always hidden, never an error', () {
    test('an unidentified caller receives a normal hidden response', () async {
      // Contract: this is NOT a 401.
      final h = build(respond: (_) => _json({'visible': false}));
      final v = await h.repo.fetch();
      expect(v.visible, isFalse);
    });

    test('a 500 becomes hidden', () async {
      final h = build(
        respond: (_) => _json({
          'error': {'code': 'boom'},
        }, status: 500),
      );
      final v = await h.repo.fetch();
      expect(v.visible, isFalse);
    });

    test('a 401 becomes hidden rather than surfacing an auth error', () async {
      final h = build(
        respond: (_) => _json({
          'error': {'code': 'unauthorized'},
        }, status: 401),
      );
      final v = await h.repo.fetch();
      expect(v.visible, isFalse);
    });

    test('a 404 becomes hidden — endpoint not deployed yet', () async {
      final h = build(respond: (_) => _json(const {}, status: 404));
      expect((await h.repo.fetch()).visible, isFalse);
    });

    test('a connectivity failure becomes hidden', () async {
      final adapter = _StubAdapter((options) {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      });
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter;
      final repo = RemoteReleaseVisibilityRepository(
        V2ApiClient(
          baseUrl: 'https://example.test/api/v1',
          installationIdLoader: () async => installationId,
          dio: dio,
        ),
      );
      expect((await repo.fetch()).visible, isFalse);
    });

    test('a malformed body becomes hidden', () async {
      final adapter = _StubAdapter(
        (_) => ResponseBody.fromString(
          'not json at all',
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter;
      final repo = RemoteReleaseVisibilityRepository(
        V2ApiClient(
          baseUrl: 'https://example.test/api/v1',
          installationIdLoader: () async => installationId,
          dio: dio,
        ),
      );
      expect((await repo.fetch()).visible, isFalse);
    });

    test('a structurally wrong payload becomes hidden', () async {
      // `visible` present but the rest is nonsense: decode must not throw out.
      final h = build(
        respond: (_) => _json({
          'visible': true,
          'resolved_release': ['unexpected', 'list'],
        }),
      );
      final v = await h.repo.fetch();
      expect(v.visible, isTrue);
      expect(v.resolvedRelease, isNull);
      expect(v.hasAnythingToShow, isFalse);
    });
  });

  group('success decoding', () {
    test('a visible payload maps through', () async {
      final h = build(
        respond: (_) => _json({
          'visible': true,
          'scope': 'internal_testers',
          'resolved_release': {
            'release_id': 'siyak-ar-lexicon-v003-ar-iq',
            'display_name': 'Arabic Iraqi v003',
            'dataset_version': 'arabic-lexicon-v003',
            'pack': 'ar-IQ',
            'status': 'active',
          },
          'current_game_release': {
            'release_id': 'siyak-ar-lexicon-v002-ar-iq',
            'display_name': 'Arabic Iraqi v002',
            'pinned': true,
          },
          'release_changed_for_new_games': true,
        }),
      );
      final v = await h.repo.fetch(language: 'en');
      expect(v.visible, isTrue);
      expect(v.scope, ReleaseVisibilityScope.internalTesters);
      expect(v.resolvedRelease!.label, 'Arabic Iraqi v003');
      expect(v.currentGameRelease!.label, 'Arabic Iraqi v002');
      expect(v.releaseChangedForNewGames, isTrue);
    });
  });
}
