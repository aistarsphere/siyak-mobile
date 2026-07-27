import 'dart:async';

import 'package:context_game/core/design/theme/siyaq_theme_data.dart';
import 'package:context_game/core/design/tokens/siyaq_typography.dart';
import 'package:context_game/features/game/data/models/modes_info.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/providers.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_create_room_screen.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_join_room_screen.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_room_lobby_screen.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/hint_mode.dart';
import 'package:context_game/features/v2/domain/entities/installation_profile.dart';
import 'package:context_game/features/v2/domain/entities/room.dart';
import 'package:context_game/features/v2/presentation/controllers/profile_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/realtime_room_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/room_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test harness for the room flow — Lobby, Create and Join.
///
/// Overrides only the providers those three screens read. The widget tree,
/// localization, theme and every design-system component under test are real.

class FakeRoomLifecycleController extends RoomLifecycleController {
  FakeRoomLifecycleController(this._state);
  final RoomLifecycleState _state;

  @override
  RoomLifecycleState build() => _state;
}

class FakeRealtimeRoomController extends RealtimeRoomController {
  FakeRealtimeRoomController(this._state);
  final RoomConnState _state;

  @override
  RoomConnState build() => _state;

  // The lobby connects on first frame and leaves on back — both are network
  // calls the presentation test has no business making.
  @override
  Future<void> connect(Room room, String installationId) async {}

  @override
  Future<void> leave() async {}
}

class FakeProfileController extends ProfileController {
  FakeProfileController(this._profile);
  final InstallationProfile? _profile;

  @override
  Future<InstallationProfile?> build() async => _profile;
}

const kProfile = InstallationProfile(
  installationId: 'install-1',
  shortCode: 'SYG-4F2A9',
  displayName: 'كاظم',
);

RoomParticipant participant(
  String label, {
  bool isHost = false,
  bool isMe = false,
  bool connected = true,
}) => RoomParticipant(
  participantId: 'p_$label',
  label: label,
  isHost: isHost,
  isMe: isMe,
  connected: connected,
);

Room room({
  List<RoomParticipant> participants = const [],
  int? maxPlayers = 4,
  RoomState state = RoomState.lobby,
  String joinCode = 'A7X2',
}) => Room(
  roomId: 'room_1',
  joinCode: joinCode,
  language: GameplayLanguage.arabic,
  category: 'general',
  categoryLabelAr: 'عام',
  categoryLabelEn: 'General',
  hintMode: HintMode.adaptive,
  state: state,
  participants: participants,
  sharedHistory: const [],
  totalWords: 22548,
  maxPlayers: maxPlayers,
);

const kCategories = [
  CategoryInfo(
    code: 'general',
    label: 'General',
    labelAr: 'عام',
    wordCount: 22548,
    playable: true,
  ),
  CategoryInfo(
    code: 'animals',
    label: 'Animals',
    labelAr: 'حيوانات',
    wordCount: 900,
    playable: true,
  ),
  CategoryInfo(
    code: 'sports',
    label: 'Sports',
    labelAr: 'رياضة',
    wordCount: 640,
    playable: true,
  ),
  CategoryInfo(
    code: 'locked',
    label: 'Locked',
    labelAr: 'مقفل',
    wordCount: 0,
    playable: false,
  ),
];

/// Wraps [child] in a real MaterialApp with the Siyaq theme and localization.
Future<Widget> _app({
  required Widget child,
  required Brightness brightness,
  required String lang,
  required double textScale,
  // `Override` is not exported by flutter_riverpod 3, so the list is untyped
  // and the elements are implicitly downcast on spread.
  required List<dynamic> overrides,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SiyaqThemeData.of(
        brightness,
        script: SiyaqTypography.scriptForLocale(lang),
      ),
      locale: Locale(lang),
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
}

/// Room Lobby. [roomState] null renders the pre-room loader.
Future<Widget> buildLobby({
  required Brightness brightness,
  String lang = 'ar',
  Room? roomState,
  RoomConnStatus status = RoomConnStatus.connected,
  double textScale = 1.0,
}) => _app(
  brightness: brightness,
  lang: lang,
  textScale: textScale,
  overrides: [
    profileControllerProvider.overrideWith(
      () => FakeProfileController(kProfile),
    ),
    roomLifecycleControllerProvider.overrideWith(
      () => FakeRoomLifecycleController(RoomLifecycleState(room: roomState)),
    ),
    realtimeRoomControllerProvider.overrideWith(
      () => FakeRealtimeRoomController(
        RoomConnState(room: roomState, status: status),
      ),
    ),
  ],
  child: const SiyagRoomLobbyScreen(),
);

/// Join Room. [busy] holds the searching state; [error] is set by the screen
/// itself after a failed join, so tests drive it through the controller.
Future<Widget> buildJoin({
  required Brightness brightness,
  String lang = 'ar',
  bool busy = false,
  Object? error,
  double textScale = 1.0,
}) => _app(
  brightness: brightness,
  lang: lang,
  textScale: textScale,
  overrides: [
    roomLifecycleControllerProvider.overrideWith(
      () => FakeRoomLifecycleController(
        RoomLifecycleState(busy: busy, error: error),
      ),
    ),
  ],
  child: const SiyagJoinRoomScreen(),
);

/// Create Room wizard. [categories] null → error state; [loading] holds the
/// catalogue pending.
Future<Widget> buildCreate({
  required Brightness brightness,
  String lang = 'ar',
  List<CategoryInfo>? categories = kCategories,
  bool loading = false,
  bool busy = false,
  double textScale = 1.0,
}) {
  // Inferred: the override type is not exported.
  modesOverride() {
    if (loading) {
      return modesByLanguageProvider.overrideWith(
        (ref, language) => Completer<ModesInfo>().future,
      );
    }
    if (categories == null) {
      // Sync throw so Riverpod publishes AsyncError on the first build.
      return modesByLanguageProvider.overrideWith(
        (ref, language) => throw Exception('offline'),
      );
    }
    return modesByLanguageProvider.overrideWith(
      (ref, language) => ModesInfo(language: language, categories: categories),
    );
  }

  return _app(
    brightness: brightness,
    lang: lang,
    textScale: textScale,
    overrides: [
      modesOverride(),
      roomLifecycleControllerProvider.overrideWith(
        () => FakeRoomLifecycleController(RoomLifecycleState(busy: busy)),
      ),
    ],
    child: const SiyagCreateRoomScreen(),
  );
}
