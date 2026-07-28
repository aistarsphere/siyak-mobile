import 'package:context_game/core/design/theme/siyaq_theme_data.dart';
import 'package:context_game/core/design/tokens/siyaq_typography.dart';
import 'package:context_game/features/auth/domain/entities/account.dart';
import 'package:context_game/features/auth/domain/repositories/auth_repository.dart';
import 'package:context_game/features/auth/presentation/controllers/auth_providers.dart';
import 'package:context_game/features/auth/presentation/controllers/session_controller.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_profile_screen.dart';
import 'package:context_game/features/v2/domain/entities/installation_profile.dart';
import 'package:context_game/features/v2/domain/entities/release_visibility.dart';
import 'package:context_game/features/v2/domain/repositories/release_visibility_repository.dart';
import 'package:context_game/features/v2/presentation/controllers/profile_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/v2_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test harness for the Profile screen.
///
/// Overrides only the two controllers the screen reads plus the Apple gateway,
/// so the real widget tree, the real localization tables and the real theme are
/// exercised — nothing about the screen under test is faked.
class FakeProfileController extends ProfileController {
  FakeProfileController(this._profile);
  final InstallationProfile? _profile;

  @override
  Future<InstallationProfile?> build() async => _profile;
}

class FakeSessionController extends SessionController {
  FakeSessionController(this._state);
  final SessionState _state;

  @override
  Future<SessionState> build() async => _state;
}

/// Serves a canned release-visibility answer, or fails.
///
/// Defaulting to [ReleaseVisibility.hidden] keeps every pre-existing Profile
/// test deterministic and off the network: the section is simply absent unless a
/// test asks for it.
class FakeReleaseVisibilityRepository implements ReleaseVisibilityRepository {
  FakeReleaseVisibilityRepository({
    this.value = ReleaseVisibility.hidden,
    this.throws = false,
    this.delay,
  });

  final ReleaseVisibility value;
  final bool throws;

  /// When set, the fetch stays pending for this long — used to prove that a slow
  /// endpoint never blocks Profile.
  final Duration? delay;

  int calls = 0;
  final languages = <String?>[];

  @override
  Future<ReleaseVisibility> fetch({String? language}) async {
    calls++;
    languages.add(language);
    if (delay != null) await Future<void>.delayed(delay!);
    if (throws) throw StateError('release-visibility unavailable');
    return value;
  }
}

class FakeAppleGateway implements AppleAuthGateway {
  FakeAppleGateway({this.isSupported = false});

  @override
  final bool isSupported;

  @override
  Future<AppleCredential?> obtainCredential() async => null;
}

/// A representative profile with non-zero stats.
const kSampleProfile = InstallationProfile(
  installationId: 'test-installation-id',
  shortCode: 'SYG-4F2A9',
  displayName: 'كاظم',
  gamesPlayed: 128,
  gamesSolved: 96,
  roomsJoined: 41,
  roomsWon: 17,
  weeklyBestPlacement: 3,
);

/// A signed-in account in good standing.
final kSampleAccount = Account(
  publicPlayerId: 'SYG-4F2A9',
  displayName: 'كاظم العكبي',
  avatarUrl: null,
  status: 'active',
  linkedProviders: const ['google'],
  createdAt: DateTime.utc(2026, 1, 1),
  lastActiveAt: DateTime.utc(2026, 7, 1),
);

/// A suspended account, to exercise the blocked banner.
final kBlockedAccount = Account(
  publicPlayerId: 'SYG-99XYZ',
  displayName: 'Blocked Player',
  avatarUrl: null,
  status: 'suspended',
  linkedProviders: const ['apple'],
  createdAt: DateTime.utc(2026, 1, 1),
  lastActiveAt: DateTime.utc(2026, 7, 1),
);

/// Builds the Profile screen inside a real MaterialApp.
///
/// [account] `null` renders the guest experience; non-null renders signed-in.
Future<Widget> buildProfile({
  required Brightness brightness,
  String lang = 'ar',
  Account? account,
  InstallationProfile? profile = kSampleProfile,
  bool appleSupported = false,
  bool signingIn = false,
  double textScale = 1.0,
  FakeReleaseVisibilityRepository? releaseVisibility,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      profileControllerProvider.overrideWith(
        () => FakeProfileController(profile),
      ),
      sessionControllerProvider.overrideWith(
        () => FakeSessionController(
          SessionState(account: account, signingIn: signingIn),
        ),
      ),
      appleAuthGatewayProvider.overrideWithValue(
        FakeAppleGateway(isSupported: appleSupported),
      ),
      releaseVisibilityRepositoryProvider.overrideWithValue(
        releaseVisibility ?? FakeReleaseVisibilityRepository(),
      ),
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
          child: const Scaffold(body: SiyagProfileScreen()),
        ),
      ),
    ),
  );
}
