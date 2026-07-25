@Tags(['live'])
library;

import 'package:context_game/features/v2/data/remote/remote_repositories.dart';
import 'package:context_game/features/v2/data/remote/remote_realtime_gateway.dart';
import 'package:context_game/features/v2/data/remote/v2_api_client.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/hint_mode.dart';
import 'package:context_game/features/v2/domain/entities/room_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

/// OPTIONAL live smoke test — hits the real V2 backend. Excluded from the
/// default run (tagged `live`); run explicitly:
///   `flutter test test/v2/live/live_v2_smoke.dart --tags live`
/// optionally with `--dart-define=CG_V2_BASE=<tunnel>/api/context-game/v2`.
const _base = String.fromEnvironment(
  'CG_V2_BASE',
  defaultValue:
      'https://viking-subject-watched-woods.trycloudflare.com/api/context-game/v2',
);

void main() {
  final id = const Uuid().v4();
  V2ApiClient client() =>
      V2ApiClient(baseUrl: _base, installationIdLoader: () async => id);

  test(
    'profile → weekly → guess → hint → leaderboard (live)',
    () async {
      final profiles = RemoteProfileRepository(client(), uiLanguage: 'ar');
      final profile = await profiles.register(
        installationId: id,
        displayName: 'اختبار',
      );
      expect(profile.profileId, isNotNull);
      expect(profile.shortCode, isNotEmpty);

      final weekly = RemoteWeeklyRepository(
        client(),
        myProfileId: () => profile.profileId,
      );
      final challenge = await weekly.current(language: GameplayLanguage.arabic);
      expect(challenge.weekId, isNotEmpty);

      final run = await weekly.startRun(
        weekId: challenge.weekId,
        language: GameplayLanguage.arabic,
      );
      expect(run.runId, isNotEmpty);

      final g = await weekly.guess(runId: run.runId, word: 'بيت');
      expect(g.outcome.accepted, isTrue);
      expect(g.run.attempts, greaterThanOrEqualTo(1));

      // Unknown word → suggestions, no attempt.
      final unknown = await weekly.guess(runId: run.runId, word: 'سيار');
      expect(unknown.outcome.unknown, isTrue);
      expect(unknown.outcome.suggestions, isNotEmpty);

      final hint = await weekly.hint(runId: run.runId, mode: HintMode.adaptive);
      expect(hint.word, isNotEmpty);
      expect(hint.semanticRank, greaterThanOrEqualTo(4));

      final lb = await weekly.leaderboard(
        weekId: challenge.weekId,
        pageSize: 5,
      );
      expect(lb.entries, isNotEmpty);
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'room create → WS snapshot → start event (live)',
    () async {
      final host = const Uuid().v4();
      final hostClient = V2ApiClient(
        baseUrl: _base,
        installationIdLoader: () async => host,
      );
      final profiles = RemoteProfileRepository(hostClient, uiLanguage: 'ar');
      final me = await profiles.register(
        installationId: host,
        displayName: 'مضيف',
      );
      final rooms = RemoteRoomRepository(
        hostClient,
        myProfileId: () => me.profileId,
      );
      final room = await rooms.create(
        language: GameplayLanguage.arabic,
        category: 'general',
      );
      expect(room.roomId, isNotEmpty);
      expect(room.joinCode, isNotEmpty);
      expect(room.amHost, isTrue);

      final socketBase = _base.startsWith('https')
          ? 'wss://${_base.substring(8)}'
          : 'ws://${_base.substring(7)}';
      final gw = RemoteRealtimeGateway(
        socketBase: socketBase,
        myProfileId: () => me.profileId,
      );
      final events = <RoomEvent>[];
      final sub = gw
          .connect(roomId: room.roomId, installationId: host)
          .listen(events.add);
      await Future<void>.delayed(const Duration(seconds: 2));
      await rooms.start(roomId: room.roomId);
      await Future<void>.delayed(const Duration(seconds: 2));
      await sub.cancel();
      await gw.disconnect();

      expect(
        events.any((e) => e.type == RoomEventType.snapshot),
        isTrue,
        reason: 'first WS frame is room.snapshot',
      );
      expect(
        events.any((e) => e.type == RoomEventType.roomStarted),
        isTrue,
        reason: 'room.started event received after host start',
      );
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
