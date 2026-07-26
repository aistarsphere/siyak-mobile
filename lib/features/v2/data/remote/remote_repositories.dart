import '../../domain/entities/adaptive_hint.dart';
import '../../domain/entities/gameplay_language.dart';
import '../../domain/entities/hint_mode.dart';
import '../../domain/entities/installation_profile.dart';
import '../../domain/entities/leaderboard.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/v2_capabilities.dart';
import '../../domain/entities/weekly.dart';
import '../../domain/repositories/v2_repositories.dart';
import 'v2_api_client.dart';
import 'v2_mappers.dart';

/// Live capability detection. Any failure → unavailable (solo/gameplay kept,
/// platform features gated).
class RemoteCapabilitiesRepository implements CapabilitiesRepository {
  RemoteCapabilitiesRepository(this._client);
  final V2ApiClient _client;

  @override
  Future<V2Capabilities> detect() async {
    try {
      return V2Mappers.capabilities(await _client.get('/capabilities'));
    } catch (_) {
      return V2Capabilities.unavailable;
    }
  }
}

class RemoteProfileRepository implements ProfileRepository {
  RemoteProfileRepository(this._client, {this.uiLanguage = 'ar'});
  final V2ApiClient _client;
  final String uiLanguage;

  @override
  Future<InstallationProfile> register({
    required String installationId,
    String? displayName,
  }) async {
    final body = await _client.post(
      '/profiles/register',
      body: {
        'ui_language': uiLanguage,
        if (displayName != null && displayName.trim().isNotEmpty)
          'display_name': displayName.trim(),
      },
    );
    var profile = V2Mappers.profile(body, installationId: installationId);
    try {
      profile = V2Mappers.withStats(
        profile,
        await _client.get('/profiles/me/stats'),
      );
    } catch (_) {
      /* stats are best-effort */
    }
    return profile;
  }

  @override
  Future<InstallationProfile> updateDisplayName({
    required String installationId,
    required String displayName,
  }) async {
    final body = await _client.patch(
      '/profiles/me',
      body: {'display_name': displayName.trim()},
    );
    return V2Mappers.profile(body, installationId: installationId);
  }
}

class RemoteWeeklyRepository implements WeeklyRepository {
  RemoteWeeklyRepository(this._client, {this.myProfileId});
  final V2ApiClient _client;
  final String? Function()? myProfileId;

  @override
  Future<WeeklyChallenge> current({required GameplayLanguage language}) async =>
      V2Mappers.weeklyChallenge(
        await _client.get(
          '/weekly/current',
          query: {'language': language.code},
        ),
      );

  @override
  Future<WeeklyRun> startRun({
    required String weekId,
    required GameplayLanguage language,
    HintMode hintMode = HintMode.standard,
  }) async => V2Mappers.weeklyRun(
    await _client.post(
      '/weekly/current/join',
      body: {'language': language.code},
    ),
  );

  @override
  Future<WeeklyRun> resumeRun({required String runId}) async =>
      V2Mappers.weeklyRun(await _client.get('/weekly/runs/$runId'));

  @override
  Future<({WeeklyRun run, V2GuessOutcome outcome})> guess({
    required String runId,
    required String word,
  }) async {
    try {
      final body = await _client.post(
        '/weekly/runs/$runId/guess',
        body: {'guess': word},
      );
      return (
        run: V2Mappers.weeklyRun(body),
        outcome: V2Mappers.guessOutcome(body),
      );
    } on NotInVocabularyException catch (e) {
      // Unknown word (422): the run is unchanged — fetch it to keep state.
      final run = await resumeRun(runId: runId);
      return (
        run: run,
        outcome: V2GuessOutcome(
          accepted: false,
          duplicate: false,
          unknown: true,
          originalWord: word,
          suggestions: e.suggestions,
        ),
      );
    }
  }

  @override
  Future<AdaptiveHint> hint({
    required String runId,
    required HintMode mode,
  }) async => V2Mappers.adaptiveHint(
    await _client.post(
      '/weekly/runs/$runId/hint',
      body: {'mode': mode.code, 'difficulty': 'medium'},
    ),
  );

  @override
  Future<LeaderboardPage> leaderboard({
    required String weekId,
    int page = 0,
    int pageSize = 20,
  }) async {
    final lang = 'ar'; // leaderboard is per weekly language; server infers run
    int? currentPlacement;
    try {
      final pos = await _client.get(
        '/weekly/current/my-position',
        query: {'language': lang},
      );
      currentPlacement = (pos['placement'] as num?)?.toInt();
    } catch (_) {
      /* optional */
    }
    final body = await _client.get(
      '/weekly/current/leaderboard',
      query: {'language': lang, 'limit': pageSize, 'offset': page * pageSize},
    );
    return V2Mappers.leaderboard(
      body,
      myProfileId: myProfileId?.call(),
      currentPlacement: currentPlacement,
    );
  }
}

class RemoteRoomRepository implements RoomRepository {
  RemoteRoomRepository(this._client, {this.myProfileId});
  final V2ApiClient _client;
  final String? Function()? myProfileId;

  String? get _me => myProfileId?.call();

  @override
  Future<Room> create({
    required GameplayLanguage language,
    required String category,
    HintMode hintMode = HintMode.standard,
    int? maxPlayers,
  }) async => V2Mappers.room(
    await _client.post(
      '/rooms',
      body: {
        'language': language.code,
        'category': category,
        'hint_mode': hintMode == HintMode.adaptive ? 'adaptive' : 'medium',
        'max_players': ?maxPlayers,
      },
    ),
    _me,
  );

  @override
  Future<Room> join({required String joinCode}) async => V2Mappers.room(
    await _client.post(
      '/rooms/join',
      body: {'code': joinCode.trim().toUpperCase()},
    ),
    _me,
  );

  @override
  Future<Room> snapshot({required String roomId}) async =>
      V2Mappers.room(await _client.get('/rooms/$roomId'), _me);

  @override
  Future<Room> start({required String roomId}) async =>
      V2Mappers.room(await _client.post('/rooms/$roomId/start'), _me);

  @override
  Future<V2GuessOutcome> guess({
    required String roomId,
    required String word,
  }) async {
    try {
      final body = await _client.post(
        '/rooms/$roomId/guess',
        body: {'guess': word},
      );
      return V2Mappers.guessOutcome(body);
    } on NotInVocabularyException catch (e) {
      return V2GuessOutcome(
        accepted: false,
        duplicate: false,
        unknown: true,
        originalWord: word,
        suggestions: e.suggestions,
      );
    }
  }

  @override
  Future<AdaptiveHint> hint({
    required String roomId,
    HintMode mode = HintMode.adaptive,
    String difficulty = 'medium',
  }) async => V2Mappers.adaptiveHint(
    await _client.post(
      '/rooms/$roomId/hint',
      body: {'mode': mode.code, 'difficulty': difficulty},
    ),
  );

  @override
  Future<void> leave({required String roomId}) =>
      _client.post('/rooms/$roomId/leave');
}
