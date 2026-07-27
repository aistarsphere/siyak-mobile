import 'dart:async';

import 'package:context_game/core/design/theme/siyaq_theme_data.dart';
import 'package:context_game/core/design/tokens/siyaq_typography.dart';
import 'package:context_game/features/auth/domain/entities/account.dart';
import 'package:context_game/features/auth/presentation/controllers/session_controller.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_multiplayer_hub_screen.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/hint_mode.dart';
import 'package:context_game/features/v2/domain/entities/room.dart';
import 'package:context_game/features/v2/domain/entities/social.dart';
import 'package:context_game/features/v2/presentation/controllers/room_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/social_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test harness for the Multiplayer Hub.
///
/// Overrides only the session, room-lifecycle and invitations providers the
/// screen reads; the widget tree, localization and theme under test are real.
class FakeSessionController extends SessionController {
  FakeSessionController(this._state);
  final SessionState _state;

  @override
  Future<SessionState> build() async => _state;
}

class FakeRoomLifecycleController extends RoomLifecycleController {
  FakeRoomLifecycleController(this._state);
  final RoomLifecycleState _state;

  @override
  RoomLifecycleState build() => _state;
}

final kHubAccount = Account(
  publicPlayerId: 'SYG-4F2A9',
  displayName: 'كاظم',
  linkedProviders: const ['google'],
);

/// A minimal active room, enough to render the resume action.
final kActiveRoom = Room(
  roomId: 'room_1',
  joinCode: 'AB12CD',
  language: GameplayLanguage.arabic,
  category: 'general',
  categoryLabelAr: 'عام',
  categoryLabelEn: 'General',
  hintMode: HintMode.adaptive,
  state: RoomState.lobby,
  participants: const [],
  sharedHistory: const [],
  totalWords: 22548,
);

RoomInvitation _invite(String id) => RoomInvitation(
  invitationId: id,
  roomId: 'room_$id',
  roomName: 'Room $id',
  language: 'ar',
  host: const InvitationParty(publicPlayerId: 'SYG-OTHER', displayName: 'Sara'),
);

/// Builds the Multiplayer Hub inside a real MaterialApp.
///
/// [invitationCount] populates the badge; [invitationsError] renders the inline
/// failure notice; [invitationsLoading] holds the pending state.
Future<Widget> buildHub({
  required Brightness brightness,
  String lang = 'ar',
  bool signedIn = true,
  int invitationCount = 0,
  Object? invitationsError,
  bool invitationsLoading = false,
  bool hasActiveRoom = false,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();

  // Inferred: the override type is not exported.
  invitationsOverride() {
    if (invitationsError != null) {
      // Sync throw so Riverpod publishes AsyncError on first build.
      return incomingInvitationsProvider.overrideWith(
        (ref) => throw invitationsError,
      );
    }
    if (invitationsLoading) {
      return incomingInvitationsProvider.overrideWith(
        (ref) => Completer<List<RoomInvitation>>().future,
      );
    }
    return incomingInvitationsProvider.overrideWith(
      (ref) => [for (var i = 0; i < invitationCount; i++) _invite('$i')],
    );
  }

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      sessionControllerProvider.overrideWith(
        () => FakeSessionController(
          SessionState(account: signedIn ? kHubAccount : null),
        ),
      ),
      roomLifecycleControllerProvider.overrideWith(
        () => FakeRoomLifecycleController(
          RoomLifecycleState(room: hasActiveRoom ? kActiveRoom : null),
        ),
      ),
      invitationsOverride(),
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
          child: const SiyagMultiplayerHubScreen(),
        ),
      ),
    ),
  );
}
