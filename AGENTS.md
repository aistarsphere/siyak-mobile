# AGENTS.md — Siyaq Mobile

> **Read this file before editing anything.** It is the primary instruction file
> for any AI coding agent working in this repository.

## What Siyaq is

Siyaq (Arabic **سياق**, "context") is a premium, Arabic-first **semantic word
game** for mobile. Players guess words and are scored by *semantic proximity*
to a hidden secret (Contexto-style): rank 1 = the secret, with a calibrated
"heat" signal. The product is intentionally **calm, intelligent, minimal** — a
dark charcoal foundation with a warm **gold** accent. It is not an arcade/neon
game.

Modes: Solo Practice (V1), Weekly Challenge (shared weekly secret), Multiplayer
rooms (join-by-code + account-based Social Rooms), and Ranked 1v1 (coin-staked,
turn-based). An account/economy layer (Google sign-in, wallet/coins, ranked
rating) is being integrated against a frozen backend contract.

## Platforms

Flutter (Dart SDK `^3.12.2`). Ships on **Android** and **iOS**. No web/desktop
target is maintained. Android package `com.kaher.siyak`; iOS bundle
`com.kaher.siyag`.

## Repository architecture (clean, feature-first)

```
lib/
  main.dart                     # bootstraps ProviderScope + SiyagApp
  app.dart                      # MaterialApp: theme/darkTheme/themeMode, RTL
  core/
    config/app_config.dart      # CG_BASE/CG_V2_BASE, versions, Google client id
    network/                    # V1 Dio client + ApiError
    localization/               # AppLocalizations + strings_ar/en (Arabic-first)
    theme/                      # app_tokens.dart, siyag_theme.dart (SC), app_theme.dart
    widgets/siyag/              # shared design-system widgets (Siyag*)
  features/
    game/                       # V1 Solo game (domain/data/presentation)
    v2/                         # V2 domain/data/controllers: weekly, rooms, realtime
    siyag/                      # LIVE UI: SiyagShell + screens (consumes game + v2)
    auth/                       # Google auth, session, account (in progress)
test/  integration_test/        # unit / widget / mock / live tests
design_reference/               # git-ignored handoffs + backend contract bundle
docs/                           # ARCHITECTURE.md, DESIGN_SYSTEM.md, CURRENT_PHASE.md
```

Layering per feature: `domain/{entities,repositories,errors}` → `data/{remote,…}`
→ `presentation/{controllers,screens}`. **DTOs never leak into `domain`.** The
abstract repository interfaces are the swap seam (production = remote; tests =
in-memory mocks under `test/support/`).

## State management

**Riverpod 3** (`flutter_riverpod`). Patterns in use: `Notifier` /
`AsyncNotifier` (feature controllers), `FutureProvider` (reads),
`StateProvider` (small UI state — requires `import
'package:flutter_riverpod/legacy.dart'`). No codegen. Do **not** introduce a
second state solution (Bloc/GetX/Provider-only/etc.).

## Navigation

Imperative `Navigator.of(context).push(...)` with a shared transition helper
`siyagRoute<T>(Widget)` (fade + slide-y, 240ms). Root shell `SiyagShell`
(`features/siyag/presentation/siyag_shell.dart`) is an `IndexedStack` over three
tabs (Home / Leaderboard / Profile); full-screen flows are pushed and hide the
nav. No `go_router`. The selected tab is `siyagTabProvider`.

## Localization

`core/localization/app_localizations.dart` — a bilingual string table
(`strings_ar.dart` / `strings_en.dart`), **Arabic-first**. Access via
`ref.watch(localizationsProvider)` → `loc('key')` / `loc.fill('key', {...})`.
Missing keys fall back to the key string (no crash). Directionality: screens
wrap content in `Directionality(textDirection: TextDirection.rtl)` for Arabic.
Every user-facing string must exist in **both** `strings_ar` and `strings_en`.

## Theme & design system

Centralized, theme-aware tokens — see `docs/DESIGN_SYSTEM.md` for the full spec.
- `core/theme/app_tokens.dart` — `AppTokens` (`ThemeExtension`) with `light`/
  `dark` const palettes (semantic roles: background/surface/…/accent/…).
- `core/theme/siyag_theme.dart` — `SC` exposes those tokens as theme-aware
  getters for the custom screens (`SC.bg`, `SC.surface`, `SC.gold`, …), plus
  `SC.onColor(fill)` for readable foregrounds, `SF` (fonts), `SiyagHeat`
  (gameplay heat scale), `SM` (motion), `ST` (text styles).
- `core/theme/app_theme.dart` — `AppTheme.light`/`dark` `ThemeData` built from
  the same tokens (explicit `ColorScheme`, no seed → no stray blue/indigo).
- Theme mode: `AppSettings.themeMode` (System/Light/Dark) via the existing
  `AppSettingsController` + `SharedPreferences` (`siyaq.themeMode`), applied by
  `app.dart` (which also calls `SC.applyBrightness` so the custom-token screens
  match). Gold is the **primary interaction color**; gray is the dominant
  surface family.

Legacy `app_colors.dart` / `app_typography.dart` / `app_motion.dart` back the
**old amber V1 screens** (dead but still compiled) and `game/domain/heat.dart`.
Do not build new UI on them.

## Backend / API boundaries

Client-only; never modify backend contracts. Config in `core/config/app_config.dart`
(`--dart-define=CG_BASE=…`, `CG_V2_BASE` derived as `<base>/v2`). V1 solo at
`/api/context-game`; V2 at `/api/context-game/v2`. Identity: guest
`X-Installation-ID` (UUID) and/or account `Authorization: Bearer`. The frozen
contract lives at `design_reference/Siyag_Backend_Contract_Bundle/` and is the
functional source of truth — **never invent endpoints, DTO fields, enum values,
or realtime events.** Integration status/plan: `MOBILE_V2_INTEGRATION_PLAN.md`.

## Build & run

```
flutter pub get
flutter run -d <device> --dart-define=CG_BASE=https://<host>/api/context-game
flutter build apk --release --dart-define=CG_BASE=…      # Android
flutter build ios --release --dart-define=CG_BASE=…      # iOS (needs signing)
```
`trycloudflare` tunnels are ephemeral — pass a fresh `CG_BASE`.

## Tests & static checks

```
flutter analyze          # must be 0 errors / 0 warnings
dart format --set-exit-if-changed lib test   # formatting
flutter test             # unit + widget + mock
flutter test integration_test/…              # live (needs device + backend)
```
Tests live in `test/` (`unit/`, `widget/`, `mock/`, `v2/`, `auth/`, `theme/`)
and `integration_test/`. Mocks/fakes are **test-only** under `test/support/`;
production is remote-only. Do not weaken or delete existing tests.

## Visual QA

Colour/UI changes require on-device evidence in **both themes**. Build + install,
capture via `adb exec-out screencap`, and compare light vs dark (and RTL Arabic
vs LTR English) at a fixed device size. Theme/branding renders offline, so the
backend being down does not block theme screenshots.

## Production constraints

- Production is **mock-free**; mocks stay in `test/support/`.
- Arabic-first; preserve RTL/LTR and both localizations.
- Server is authoritative for wallet/reward/rating/winner/timer/presence — never
  computed locally.
- Anonymous identity uses a random UUID only — never a hardware identifier.

## Rules future agents MUST follow

1. Read this `AGENTS.md` before editing.
2. Inspect the actual code before proposing or making architecture changes — do
   not infer from filenames.
3. Do **not** redesign screens/layout/navigation unless explicitly requested.
4. Do **not** replace working architecture for cosmetic work.
5. Do **not** hardcode colors in feature widgets — use the semantic tokens
   (`SC.*` / `AppTokens`). Extend the token system; don't fork it.
6. Preserve Arabic + English localization and RTL/LTR behavior.
7. Preserve API contracts, gameplay behavior, and authentication.
8. Run `flutter analyze` + `flutter test` before reporting completion.
9. Produce screenshots for any visual change.
10. Never commit secrets/credentials/tokens/production env values.
11. Do not claim completion without evidence (tests + screenshots).

## Files not to modify casually

- `core/theme/app_tokens.dart`, `siyag_theme.dart`, `app_theme.dart` — the whole
  app depends on these; change values, not the contract, and re-run visual QA.
- `core/config/app_config.dart` — configuration seam.
- `core/localization/strings_*.dart` — keep ar/en in lockstep.
- `features/v2/data/remote/*`, `features/auth/data/*` — API contract mappers.
- `android/app/build.gradle.kts`, `ios/Runner.xcodeproj/*` — identifiers/signing.
- `design_reference/**` — read-only source of truth (git-ignored).

## Security & secrets

- `secret/` and `**/client_secret*.json` are git-ignored; never commit them.
- Never embed a Google client *secret* in the app (public client). Only the
  public Web client **ID** is shipped as `serverClientId`.
- No credentials/tokens/keystores in source, assets, `pubspec.yaml`, or builds.

## Required final-report format

End every task with: (1) areas inspected, (2) files changed, (3) tokens/behavior
before→after, (4) accessibility checks, (5) tests run + results, (6) build
result, (7) screenshot paths + before/after notes, (8) regressions found/fixed,
(9) known remaining issues, (10) git branch/commits, (11) explicit confirmation
that layout, gameplay, localization, and API contracts were preserved.
