import 'package:context_game/core/design/theme/siyaq_theme_data.dart';
import 'package:context_game/core/design/tokens/siyaq_typography.dart';
import 'package:context_game/features/game/domain/entities/guess.dart';
import 'package:context_game/features/game/domain/entities/heat.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_ranked_match_screen.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_room_game_screen.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/hint_mode.dart';
import 'package:context_game/features/v2/domain/entities/ranked.dart';
import 'package:context_game/features/v2/domain/entities/room.dart';
import 'package:context_game/features/v2/presentation/controllers/realtime_room_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/room_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'room_harness.dart' show FakeRealtimeRoomController;

/// Test harness for the two shared gameplay modes — Room Game and Ranked Match.
///
/// Only the providers each screen reads are overridden; the widget tree, theme,
/// localization and every gameplay component under test are real.

class _FakeRoomLifecycle extends RoomLifecycleController {
  @override
  RoomLifecycleState build() => const RoomLifecycleState();
}

/// A scored guess in a shared timeline.
SharedGuess shared(
  String word,
  int rank, {
  required String by,
  bool isMine = false,
  bool isSystemHint = false,
  bool solved = false,
  double proximity = 40,
}) => SharedGuess(
  guess: Guess(
    word: word,
    rank: rank,
    proximity: proximity,
    tier: Heat.fromProximity(proximity),
    isSecret: solved,
  ),
  byParticipantId: 'p_$by',
  byLabel: by,
  isMine: isMine,
  isSystemHint: isSystemHint,
);

Room roomWith({
  required List<SharedGuess> history,
  GameplayLanguage language = GameplayLanguage.arabic,
  RoomState state = RoomState.playing,
  int totalWords = 22548,
  RoomParticipant? winner,
  String? secretWord,
}) => Room(
  roomId: 'room_1',
  joinCode: 'A7X2',
  language: language,
  category: 'general',
  categoryLabelAr: 'عام',
  categoryLabelEn: 'General',
  hintMode: HintMode.adaptive,
  state: state,
  participants: const [
    RoomParticipant(
      participantId: 'p_كاظم',
      label: 'كاظم',
      isHost: true,
      isMe: true,
    ),
    RoomParticipant(participantId: 'p_Sara', label: 'Sara', isHost: false),
  ],
  sharedHistory: history,
  totalWords: totalWords,
  maxPlayers: 4,
  winner: winner,
  secretWord: secretWord,
);

Widget _app({
  required Widget child,
  required Brightness brightness,
  required String uiLang,
  required double textScale,
  required List<dynamic> overrides,
  required SharedPreferences prefs,
}) => ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: SiyaqThemeData.of(
      brightness,
      script: SiyaqTypography.scriptForLocale(uiLang),
    ),
    locale: Locale(uiLang),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  ),
);

/// Room Game. [room] null renders the pre-snapshot loader.
Future<Widget> buildRoomGame({
  Brightness brightness = Brightness.dark,
  String uiLang = 'ar',
  Room? room,
  RoomConnStatus status = RoomConnStatus.connected,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': uiLang});
  final prefs = await SharedPreferences.getInstance();
  return _app(
    brightness: brightness,
    uiLang: uiLang,
    textScale: textScale,
    prefs: prefs,
    overrides: [
      roomLifecycleControllerProvider.overrideWith(_FakeRoomLifecycle.new),
      realtimeRoomControllerProvider.overrideWith(
        () => FakeRealtimeRoomController(
          RoomConnState(room: room, status: status),
        ),
      ),
    ],
    child: const SiyagRoomGameScreen(),
  );
}

MatchPlayer player({
  required String id,
  required String name,
  bool isYou = false,
  bool ready = false,
  String connection = 'connected',
}) => MatchPlayer(
  profileId: id,
  slot: isYou ? 0 : 1,
  displayName: name,
  ready: ready,
  connectionState: connection,
  isYou: isYou,
);

MatchGuess matchGuess(
  String word, {
  int? rank,
  bool isYou = false,
  int? turn,
}) => MatchGuess(word: word, rank: rank, isYou: isYou, turnNumber: turn);

RankedMatch match({
  RankedMatchStatus status = RankedMatchStatus.active,
  String language = 'ar',
  List<MatchGuess> guesses = const [],
  bool myTurn = true,
  bool youReady = false,
  bool oppReady = false,
  double? turnRemaining = 18,
  String? winner,
  String? secretWord,
  int? ratingDelta,
}) {
  final you = player(id: 'me', name: 'كاظم', isYou: true, ready: youReady);
  final opp = player(id: 'them', name: 'Sara', ready: oppReady);
  return RankedMatch(
    id: 'm1',
    status: status,
    language: language,
    players: [you, opp],
    guesses: guesses,
    currentTurn: myTurn ? you.profileId : opp.profileId,
    turnRemainingSeconds: turnRemaining,
    winner: winner,
    secretWord: secretWord,
    ratingDelta: ratingDelta,
  );
}

/// Ranked Match. [snapshot] null renders the pre-snapshot loader.
Future<Widget> buildRankedMatch({
  Brightness brightness = Brightness.dark,
  String uiLang = 'ar',
  RankedMatch? snapshot,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': uiLang});
  final prefs = await SharedPreferences.getInstance();
  return _app(
    brightness: brightness,
    uiLang: uiLang,
    textScale: textScale,
    prefs: prefs,
    overrides: [
      rankedMatchStreamProvider.overrideWith(
        (ref, id) => snapshot == null
            ? const Stream<RankedMatch>.empty()
            : Stream.value(snapshot),
      ),
    ],
    child: const SiyagRankedMatchScreen(matchId: 'm1'),
  );
}
