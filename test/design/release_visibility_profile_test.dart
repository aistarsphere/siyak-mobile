import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/auth/presentation/controllers/session_controller.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/v2/domain/entities/release_visibility.dart';
import 'package:context_game/features/v2/presentation/controllers/profile_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/release_visibility_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/profile_harness.dart';

/// Behaviour of the Profile "Game data" section, plus the state rules around it.
///
/// The governing property is that an ineligible or offline player sees **exactly
/// nothing** — no section, no placeholder, no error affordance — and that the
/// rest of Profile is unaffected either way.

ResolvedRelease _resolved({
  String? releaseId = 'siyak-ar-lexicon-v003-ar-iq',
  String? displayName = 'Arabic Iraqi v003',
  Gated<String> datasetVersion = const Gated<String>.of('arabic-lexicon-v003'),
  Gated<String> pack = const Gated<String>.of('ar-IQ'),
  Gated<String> sourceCommit = const Gated<String>.absent(),
}) => ResolvedRelease(
  releaseId: releaseId == null
      ? const Gated<String>.absent()
      : Gated<String>.of(releaseId),
  displayName: displayName,
  datasetVersion: datasetVersion,
  pack: pack,
  language: 'ar',
  status: 'active',
  sourceCommit: sourceCommit,
);

ReleaseVisibility _visible({
  ResolvedRelease? resolved,
  CurrentGameRelease? current,
  bool changed = false,
}) => ReleaseVisibility(
  visible: true,
  scope: ReleaseVisibilityScope.internalTesters,
  resolvedRelease: resolved ?? _resolved(),
  currentGameRelease: current,
  releaseChangedForNewGames: changed,
);

/// Profile is a tall `ListView`, and the section under test is its last child.
/// A short viewport would leave it unattached, so the surface is sized to fit the
/// whole screen rather than scrolling in every test.
void _sizeToFitProfile(WidgetTester t) {
  t.view.physicalSize = const Size(1000, 3000);
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
}

Future<void> _pump(
  WidgetTester t, {
  required FakeReleaseVisibilityRepository repo,
  String lang = 'en',
}) async {
  _sizeToFitProfile(t);
  await t.pumpWidget(
    await buildProfile(
      brightness: Brightness.dark,
      lang: lang,
      releaseVisibility: repo,
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  group('hidden', () {
    testWidgets('no section when the policy hides it', (t) async {
      await _pump(t, repo: FakeReleaseVisibilityRepository());

      expect(find.text('GAME DATA'), findsNothing);
      expect(find.text('Word data version'), findsNothing);
      // Nothing stands in for it either.
      expect(find.byType(SiyaqLoader), findsNothing);
      expect(find.byType(SiyaqEmptyState), findsNothing);
    });

    testWidgets('no section, and no error surface, when the fetch fails', (
      t,
    ) async {
      await _pump(t, repo: FakeReleaseVisibilityRepository(throws: true));

      expect(find.text('GAME DATA'), findsNothing);
      expect(find.byType(SiyaqEmptyState), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Retry'), findsNothing);
    });

    testWidgets('visible but entirely gated away renders no empty section', (
      t,
    ) async {
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(
          value: const ReleaseVisibility(
            visible: true,
            resolvedRelease: ResolvedRelease(language: 'ar', status: 'active'),
          ),
        ),
      );
      expect(find.text('GAME DATA'), findsNothing);
    });

    testWidgets('Profile still opens and keeps its own sections', (t) async {
      await _pump(t, repo: FakeReleaseVisibilityRepository(throws: true));

      // Regression guard: the pre-existing Profile content is untouched.
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('LANGUAGE'), findsOneWidget);
      expect(find.text('SOUND'), findsOneWidget);
      expect(find.text('HAPTICS'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);
    });
  });

  group('visible', () {
    testWidgets('renders the primary version row from display_name', (t) async {
      await _pump(t, repo: FakeReleaseVisibilityRepository(value: _visible()));

      expect(find.text('GAME DATA'), findsOneWidget);
      expect(find.text('Word data version'), findsOneWidget);
      expect(find.text('Arabic Iraqi v003'), findsOneWidget);
    });

    testWidgets('falls back to release_id when display_name is null', (
      t,
    ) async {
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            resolved: _resolved(displayName: null, releaseId: 'legacy-001'),
          ),
        ),
      );

      expect(find.text('Word data version'), findsOneWidget);
      expect(
        find.text('legacy-001'),
        findsNWidgets(2),
        reason: 'once as the fallback value, once as the Release ID row',
      );
      // Never a raw null or a placeholder.
      expect(find.textContaining('null'), findsNothing);
      expect(find.text('N/A'), findsNothing);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('no primary row when neither name nor id is available', (
      t,
    ) async {
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            resolved: _resolved(displayName: null, releaseId: null),
          ),
        ),
      );
      expect(find.text('Word data version'), findsNothing);
      // Dataset/pack rows still justify the section.
      expect(find.text('GAME DATA'), findsOneWidget);
    });

    testWidgets('renders optional rows that carry values', (t) async {
      await _pump(t, repo: FakeReleaseVisibilityRepository(value: _visible()));

      expect(find.text('Dataset version'), findsOneWidget);
      expect(find.text('arabic-lexicon-v003'), findsOneWidget);
      expect(find.text('Language pack'), findsOneWidget);
      expect(find.text('ar-IQ'), findsOneWidget);
      expect(find.text('Release ID'), findsOneWidget);
      expect(find.text('siyak-ar-lexicon-v003-ar-iq'), findsOneWidget);
    });

    testWidgets('omitted fields render no row and leave no trace', (t) async {
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            resolved: _resolved(
              datasetVersion: const Gated<String>.absent(),
              pack: const Gated<String>.absent(),
              releaseId: null,
            ),
          ),
        ),
      );

      expect(find.text('Dataset version'), findsNothing);
      expect(find.text('Language pack'), findsNothing);
      expect(find.text('Release ID'), findsNothing);
      // The section itself still shows, because display_name survived.
      expect(find.text('Arabic Iraqi v003'), findsOneWidget);
    });

    testWidgets('present-null legacy fields render no row either', (t) async {
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            resolved: _resolved(
              datasetVersion: const Gated<String>.of(null),
              pack: const Gated<String>.of(null),
            ),
          ),
        ),
      );

      expect(find.text('Dataset version'), findsNothing);
      expect(find.text('Language pack'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });

    testWidgets('no source-commit row when the backend omits it', (t) async {
      await _pump(t, repo: FakeReleaseVisibilityRepository(value: _visible()));
      expect(find.text('Source commit'), findsNothing);
    });

    testWidgets('source commit shows when the backend sends it', (t) async {
      // Arriving at all means the server already judged the caller eligible —
      // it clamps this field to internal testers even under `all_users`.
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            resolved: _resolved(
              sourceCommit: const Gated<String>.of('abc1234'),
            ),
          ),
        ),
      );
      expect(find.text('Source commit'), findsOneWidget);
      expect(find.text('abc1234'), findsOneWidget);
    });

    testWidgets('policy scope is never rendered', (t) async {
      await _pump(t, repo: FakeReleaseVisibilityRepository(value: _visible()));
      expect(find.textContaining('internal_testers'), findsNothing);
      expect(find.textContaining('Internal'), findsNothing);
    });
  });

  group('current game', () {
    testWidgets('no current-game row when there is no resumable game', (
      t,
    ) async {
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(value: _visible(current: null)),
      );
      expect(find.text('Current game release'), findsNothing);
    });

    testWidgets('renders the pinned current-game release', (t) async {
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            current: const CurrentGameRelease(
              releaseId: Gated<String>.of('siyak-ar-lexicon-v002-ar-iq'),
              displayName: 'Arabic Iraqi v002',
              pinned: true,
            ),
          ),
        ),
      );

      expect(find.text('Current game release'), findsOneWidget);
      expect(find.text('Arabic Iraqi v002'), findsOneWidget);
      expect(find.text('Pinned'), findsOneWidget);
    });

    testWidgets('a pre-pinning game shows the neutral legacy label', (t) async {
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            current: const CurrentGameRelease(
              releaseId: Gated<String>.of(null),
              unknownRelease: true,
            ),
          ),
        ),
      );

      expect(find.text('Current game release'), findsOneWidget);
      expect(find.text('Unknown legacy release'), findsOneWidget);
      // Must not be filled in from the resolved release.
      expect(
        find.text('Arabic Iraqi v003'),
        findsOneWidget,
        reason: 'only the primary row shows the resolved name',
      );
      expect(find.text('Pinned'), findsNothing);
    });
  });

  group('changed release', () {
    final changed = _visible(
      current: const CurrentGameRelease(
        releaseId: Gated<String>.of('siyak-ar-lexicon-v002-ar-iq'),
        displayName: 'Arabic Iraqi v002',
        pinned: true,
      ),
      changed: true,
    );

    testWidgets('distinguishes new-games from current-game and explains why', (
      t,
    ) async {
      await _pump(t, repo: FakeReleaseVisibilityRepository(value: changed));

      expect(find.text('New games release'), findsOneWidget);
      expect(find.text('Current game release'), findsOneWidget);
      expect(
        find.text(
          'Your current game remains on its original word-data version. '
          'New games use the newer version.',
        ),
        findsOneWidget,
      );
      // Informational, not alarming.
      expect(find.byType(SiyaqTintedSurface), findsOneWidget);
      final tinted = t.widget<SiyaqTintedSurface>(
        find.byType(SiyaqTintedSurface),
      );
      expect(tinted.tone, SiyaqTone.info);
    });

    testWidgets('no message and no duplicate row when nothing changed', (
      t,
    ) async {
      await _pump(
        t,
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            current: const CurrentGameRelease(
              releaseId: Gated<String>.of('siyak-ar-lexicon-v003-ar-iq'),
              displayName: 'Arabic Iraqi v003',
              pinned: true,
            ),
          ),
        ),
      );

      expect(find.text('New games release'), findsNothing);
      expect(find.byType(SiyaqTintedSurface), findsNothing);
      expect(find.textContaining('remains on its original'), findsNothing);
    });
  });

  group('localization and direction', () {
    testWidgets('Arabic renders RTL with Arabic copy', (t) async {
      await _pump(
        t,
        lang: 'ar',
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            current: const CurrentGameRelease(
              releaseId: Gated<String>.of('siyak-ar-lexicon-v002-ar-iq'),
              displayName: 'Arabic Iraqi v002',
              pinned: true,
            ),
            changed: true,
          ),
        ),
      );

      expect(find.text('بيانات اللعبة'), findsOneWidget);
      expect(find.text('إصدار بيانات الكلمات'), findsOneWidget);
      expect(find.text('إصدار الألعاب الجديدة'), findsOneWidget);
      expect(find.text('إصدار اللعبة الحالية'), findsOneWidget);
      expect(find.text('مثبّت'), findsOneWidget);
      expect(
        find.text(
          'تبقى لعبتك الحالية على إصدارها الأصلي، '
          'بينما تستخدم الألعاب الجديدة الإصدار الأحدث.',
        ),
        findsOneWidget,
      );

      final dir = Directionality.of(t.element(find.text('بيانات اللعبة')));
      expect(dir, TextDirection.rtl);
    });

    testWidgets('Arabic legacy label is localized', (t) async {
      await _pump(
        t,
        lang: 'ar',
        repo: FakeReleaseVisibilityRepository(
          value: _visible(
            current: const CurrentGameRelease(
              releaseId: Gated<String>.of(null),
              unknownRelease: true,
            ),
          ),
        ),
      );
      expect(find.text('إصدار قديم غير معروف'), findsOneWidget);
    });

    testWidgets('English renders LTR', (t) async {
      await _pump(t, repo: FakeReleaseVisibilityRepository(value: _visible()));
      expect(
        Directionality.of(t.element(find.text('GAME DATA'))),
        TextDirection.ltr,
      );
    });
  });

  group('state', () {
    testWidgets('a slow fetch does not block Profile or shift it', (t) async {
      final repo = FakeReleaseVisibilityRepository(
        value: _visible(),
        delay: const Duration(seconds: 3),
      );
      _sizeToFitProfile(t);
      await t.pumpWidget(
        await buildProfile(
          brightness: Brightness.dark,
          lang: 'en',
          releaseVisibility: repo,
        ),
      );
      await t.pump(); // one frame only — the fetch is still in flight

      // Profile is usable immediately, and the section is simply not there yet.
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('GAME DATA'), findsNothing);
      final before = t.getTopLeft(find.text('APPEARANCE'));

      await t.pump(const Duration(seconds: 4));
      await t.pumpAndSettle();

      expect(find.text('GAME DATA'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('APPEARANCE')),
        before,
        reason: 'the section appends below, so nothing above it moves',
      );
    });

    testWidgets('sends the UI language and refetches when it changes', (
      t,
    ) async {
      final repo = FakeReleaseVisibilityRepository(value: _visible());
      _sizeToFitProfile(t);
      await t.pumpWidget(
        await buildProfile(
          brightness: Brightness.dark,
          lang: 'en',
          releaseVisibility: repo,
        ),
      );
      await t.pumpAndSettle();
      expect(repo.languages, ['en']);

      // Switching language re-asks in the new language.
      final ctx = t.element(find.text('GAME DATA'));
      final container = ProviderScope.containerOf(ctx);
      container.read(appSettingsProvider.notifier).setLang('ar');
      await t.pumpAndSettle();

      expect(repo.languages, ['en', 'ar']);
      expect(repo.calls, 2);
    });

    testWidgets('refetches when the account changes', (t) async {
      final repo = FakeReleaseVisibilityRepository(value: _visible());
      _sizeToFitProfile(t);
      await t.pumpWidget(
        await buildProfile(
          brightness: Brightness.dark,
          lang: 'en',
          releaseVisibility: repo,
        ),
      );
      await t.pumpAndSettle();
      expect(repo.calls, 1);

      final container = ProviderScope.containerOf(
        t.element(find.text('GAME DATA')),
      );
      // Eligibility is per account, so a session change must re-ask.
      container.invalidate(sessionControllerProvider);
      await t.pumpAndSettle();

      expect(repo.calls, greaterThan(1));
    });

    testWidgets('refetches when the profile refreshes', (t) async {
      final repo = FakeReleaseVisibilityRepository(value: _visible());
      _sizeToFitProfile(t);
      await t.pumpWidget(
        await buildProfile(
          brightness: Brightness.dark,
          lang: 'en',
          releaseVisibility: repo,
        ),
      );
      await t.pumpAndSettle();
      final first = repo.calls;

      final container = ProviderScope.containerOf(
        t.element(find.text('GAME DATA')),
      );
      container.invalidate(profileControllerProvider);
      await t.pumpAndSettle();

      expect(repo.calls, greaterThan(first));
    });

    testWidgets('the provider itself swallows a repository failure', (t) async {
      final repo = FakeReleaseVisibilityRepository(throws: true);
      _sizeToFitProfile(t);
      await t.pumpWidget(
        await buildProfile(
          brightness: Brightness.dark,
          lang: 'en',
          releaseVisibility: repo,
        ),
      );
      await t.pumpAndSettle();

      final container = ProviderScope.containerOf(
        t.element(find.text('APPEARANCE')),
      );
      final value = container.read(releaseVisibilityProvider);
      expect(value.hasError, isFalse, reason: 'must not propagate an error');
      expect(value.value, isNotNull);
      expect(value.value!.visible, isFalse);
    });
  });
}
