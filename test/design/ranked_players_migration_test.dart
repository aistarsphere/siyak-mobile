import 'dart:async';

import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/core/sound/sound_player_adapter.dart';
import 'package:context_game/core/sound/sound_service.dart';
import 'package:context_game/features/auth/domain/entities/account.dart';
import 'package:context_game/features/auth/presentation/controllers/session_controller.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_players_screen.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_ranked_screen.dart';
import 'package:context_game/features/v2/domain/entities/ranked.dart';
import 'package:context_game/features/v2/domain/entities/social.dart';
import 'package:context_game/features/v2/presentation/controllers/ranked_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/social_controller.dart';
import 'package:context_game/features/v2/domain/repositories/social_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Feature QA for the Ranked-entry and Players migrations — including the
/// state bugs the migration fixed (fake 1000 rating while loading, swallowed
/// errors, silent invitation failures).

class FakeSession extends SessionController {
  FakeSession(this._signedIn);
  final bool _signedIn;

  @override
  Future<SessionState> build() async => SessionState(
    account: _signedIn
        ? const Account(
            publicPlayerId: 'SYG-1',
            displayName: 'كاظم',
            linkedProviders: ['google'],
          )
        : null,
  );
}

/// Social repo used only for the presence heartbeat this screen fires.
class _HeartbeatOnlySocialRepo implements SocialRepository {
  @override
  Future<PresenceInfo> heartbeat({
    String? activity,
    PresenceState? state,
  }) async =>
      const PresenceInfo(state: PresenceState.onlineAvailable, available: true);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('unexpected call');
}

Future<Widget> _app({
  required Widget child,
  String lang = 'en',
  List<dynamic> overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundPlayerAdapterProvider.overrideWithValue(const SilentSoundAdapter()),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SiyaqThemeData.of(
        Brightness.dark,
        script: SiyaqTypography.scriptForLocale(lang),
      ),
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

const _tier = RankedTier(id: 't1', entryCost: 50, payout: 100);

void main() {
  group('Ranked entry', () {
    testWidgets('loading shows a loader — never a fake 1000 rating', (t) async {
      await t.pumpWidget(
        await _app(
          child: const SiyagRankedScreen(),
          overrides: [
            rankedTiersProvider.overrideWith(
              (ref) => Completer<List<RankedTier>>().future,
            ),
            rankedStatsProvider.overrideWith(
              (ref) => Completer<RankedStats?>().future,
            ),
          ],
        ),
      );
      await t.pump();

      expect(find.byType(SiyaqLoader), findsOneWidget);
      expect(find.text('1000'), findsNothing);
    });

    testWidgets('a tiers failure surfaces with retry — was swallowed', (
      t,
    ) async {
      var calls = 0;
      await t.pumpWidget(
        await _app(
          child: const SiyagRankedScreen(),
          overrides: [
            rankedTiersProvider.overrideWith((ref) {
              calls++;
              throw Exception('offline');
            }),
            rankedStatsProvider.overrideWith((ref) async => null),
          ],
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      // Riverpod 3 auto-retries failing providers, so the exact call count is
      // not deterministic — what matters is that the button triggers a fetch.
      final before = calls;
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(calls, greaterThan(before), reason: 'retry must refetch');
    });

    testWidgets('data renders rating, record and tiers on the DS', (t) async {
      await t.pumpWidget(
        await _app(
          child: const SiyagRankedScreen(),
          overrides: [
            rankedTiersProvider.overrideWith((ref) async => [_tier]),
            rankedStatsProvider.overrideWith(
              (ref) async =>
                  const RankedStats(rating: 1240, wins: 8, losses: 3),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('1240'), findsOneWidget);
      expect(find.byType(SiyaqStatCard), findsNWidgets(2));
      expect(find.byType(SiyaqListRow), findsOneWidget);
      expect(find.widgetWithText(SiyaqButton, 'Search'), findsOneWidget);
    });
  });

  group('Players', () {
    testWidgets('guest gate uses the DS empty state with a sign-in action', (
      t,
    ) async {
      await t.pumpWidget(
        await _app(
          child: const SiyagPlayersScreen(),
          overrides: [
            sessionControllerProvider.overrideWith(() => FakeSession(false)),
            socialRepositoryProvider.overrideWithValue(
              _HeartbeatOnlySocialRepo(),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      expect(find.widgetWithText(SiyaqButton, 'Sign In'), findsOneWidget);
    });

    testWidgets('directory renders SiyaqPlayerRows with presence chips', (
      t,
    ) async {
      await t.pumpWidget(
        await _app(
          child: const SiyagPlayersScreen(),
          overrides: [
            sessionControllerProvider.overrideWith(() => FakeSession(true)),
            socialRepositoryProvider.overrideWithValue(
              _HeartbeatOnlySocialRepo(),
            ),
            playersDirectoryProvider.overrideWith(
              (ref) async => const SocialDirectory(
                players: [
                  SocialPlayer(
                    publicPlayerId: 'SYG-2',
                    displayName: 'Sara',
                    presence: PresenceState.onlineAvailable,
                  ),
                  SocialPlayer(
                    publicPlayerId: 'SYG-3',
                    displayName: 'Yousef',
                    presence: PresenceState.inRoomGame,
                  ),
                ],
              ),
            ),
            incomingInvitationsProvider.overrideWith(
              (ref) async => const <RoomInvitation>[],
            ),
          ],
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SiyaqPlayerRow), findsNWidgets(2));
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('In a game'), findsOneWidget);
    });

    testWidgets('an invitations failure is surfaced, not silent', (t) async {
      await t.pumpWidget(
        await _app(
          child: const SiyagPlayersScreen(),
          overrides: [
            sessionControllerProvider.overrideWith(() => FakeSession(true)),
            socialRepositoryProvider.overrideWithValue(
              _HeartbeatOnlySocialRepo(),
            ),
            playersDirectoryProvider.overrideWith(
              (ref) async => const SocialDirectory(players: []),
            ),
            incomingInvitationsProvider.overrideWith(
              (ref) => throw Exception('offline'),
            ),
          ],
        ),
      );
      await t.pumpAndSettle();

      expect(
        find.textContaining('invitations'),
        findsOneWidget,
        reason: 'a failed invitations fetch must not masquerade as "none"',
      );
    });

    testWidgets('directory failure shows the DS error state with retry', (
      t,
    ) async {
      await t.pumpWidget(
        await _app(
          child: const SiyagPlayersScreen(),
          overrides: [
            sessionControllerProvider.overrideWith(() => FakeSession(true)),
            socialRepositoryProvider.overrideWithValue(
              _HeartbeatOnlySocialRepo(),
            ),
            playersDirectoryProvider.overrideWith(
              (ref) => throw Exception('offline'),
            ),
            incomingInvitationsProvider.overrideWith(
              (ref) async => const <RoomInvitation>[],
            ),
          ],
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
