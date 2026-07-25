import 'dart:async';

import 'package:context_game/features/v2/data/remote/remote_ranked_repository.dart';
import 'package:context_game/features/v2/data/remote/v2_api_client.dart';
import 'package:context_game/features/v2/domain/entities/ranked.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Returns canned JSON routed by request path, so we can assert the ranked
/// mappers against the real contract §8 shapes without any network.
class _RouteAdapter implements HttpClientAdapter {
  _RouteAdapter(this.routes);
  final Map<String, String> routes; // path-substring → body

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final body = routes.entries
        .firstWhere(
          (e) => path.endsWith(e.key),
          orElse: () => const MapEntry('', '{}'),
        )
        .value;
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

RemoteRankedRepository _repo(Map<String, String> routes) {
  final dio = Dio(BaseOptions(baseUrl: 'https://x/api/context-game/v2'))
    ..httpClientAdapter = _RouteAdapter(routes);
  return RemoteRankedRepository(
    V2ApiClient(
      baseUrl: 'https://x/api/context-game/v2',
      installationIdLoader: () async => 'inst-1',
      sessionTokenProvider: () => 'sess_1',
      dio: dio,
    ),
  );
}

void main() {
  test('parses tiers', () async {
    final r = _repo({
      '/ranked-matches/tiers':
          '{"tiers":[{"tier_id":"ranked_50","entry_cost":50,"payout":100,'
              '"player_count":2,"platform_fee":0,"currency":"COIN","enabled":true}]}',
    });
    final tiers = await r.getTiers();
    expect(tiers, hasLength(1));
    expect(tiers.first.id, 'ranked_50');
    expect(tiers.first.entryCost, 50);
    expect(tiers.first.payout, 100);
  });

  test('parses a matchmaking ticket with nested matched match', () async {
    final r = _repo({
      '/matchmaking/join':
          '{"ticket_id":"mmt_1","status":"matched","tier_id":"ranked_50",'
              '"reserved_coins":50,"match_id":"rm_1",'
              '"match":{"match_id":"rm_1","status":"preparing","players":['
              '{"profile_id":"p1","slot":1,"is_you":true},'
              '{"profile_id":"p2","slot":2,"is_you":false}],"guesses":[]}}',
    });
    final t = await r.joinMatchmaking(language: 'ar', tierId: 'ranked_50');
    expect(t.isMatched, isTrue);
    expect(t.matchId, 'rm_1');
    expect(t.match?.players, hasLength(2));
    expect(t.match?.you?.profileId, 'p1');
  });

  test('parses an active match and computes my-turn', () async {
    final r = _repo({
      '/ranked-matches/rm_1':
          '{"match_id":"rm_1","status":"active","turn_number":1,'
              '"current_turn":"p1","turn_remaining_seconds":30.0,'
              '"state_version":5,"seq":5,"players":['
              '{"profile_id":"p1","slot":1,"is_you":true,"ready":true},'
              '{"profile_id":"p2","slot":2,"is_you":false,"ready":true}],'
              '"guesses":[{"word":"علم","rank":42,"profile_id":"p1","is_you":true}]}',
    });
    final m = await r.getMatch('rm_1');
    expect(m.status, RankedMatchStatus.active);
    expect(m.isMyTurn, isTrue, reason: 'current_turn == my profile');
    expect(m.opponent?.profileId, 'p2');
    expect(m.guesses.single.rank, 42);
  });
}
