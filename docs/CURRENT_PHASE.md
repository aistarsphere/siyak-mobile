# Current Phase — Siyaq Mobile

**Git:** branch `main`, latest commit `d808581` ("change color and logo").

## Already implemented

- **App shell & screens (Siyag UI):** Home, Leaderboard, Profile (with a
  System/Light/Dark Appearance selector), Weekly overview + gameplay + result,
  Solo Practice setup + gameplay, Multiplayer hub / create / join / lobby / room
  game. Arabic-first, RTL.
- **Theme system:** centralized `AppTokens` (light/dark) → `SC` (custom screens)
  + `AppTheme` (Material); `ThemeMode` System/Light/Dark persisted in
  `AppSettings`; instant switching (shell re-keys by brightness). Graphite + gold
  identity, gold as the primary interaction color.
- **State/data:** Riverpod controllers; V1 Solo (live) and V2 Weekly/Rooms/
  realtime wired to the backend; error envelope → typed `V2Exception`.
- **Backend integration foundation (in progress):** frozen contract `2026-07.1`
  consumed; `V2ApiClient` bearer/installation/idempotency interceptor; `auth`
  feature (Google sign-in, session, guest→account migration) with unit tests.
  See `MOBILE_V2_INTEGRATION_PLAN.md`.
- **Branding:** launcher/adaptive/monochrome + iOS app icons regenerated to the
  metallic-"S" mark; notification icon assets placed.
- **Tests:** 115 passing (unit/widget/mock/theme/auth); analyzer clean.

## What THIS task changes

- Adds durable agent docs: `AGENTS.md`, `docs/ARCHITECTURE.md`,
  `docs/DESIGN_SYSTEM.md`, this file.
- **Refines the color system only** (values + a few added semantic roles) for a
  more premium, readable, game-like hierarchy: deeper dark background, clearer
  multi-level surface separation, a richer/less-beige gold, `primaryStrong` /
  `primaryContainer` / `surfaceElevated` / `surfaceStrong` / `borderStrong`
  roles, and stronger Weekly-card + navigation emphasis.
- Fixes on-gold foreground contrast where a custom widget used `SC.bg` as the
  on-accent color (wrong in light mode).

## What this task deliberately does NOT change

- No layout, spacing, typography, component hierarchy, or navigation changes.
- No gameplay, backend contract, auth, or endpoint changes.
- No new state-management, animation, or gradient systems.
- No app-name or launcher-icon change (tracked as separate follow-up below).
- No new features.

## Known remaining issues (recorded, not expanded here)

Branding/build follow-ups — **out of scope for the color task** unless coupled to
the same theme files:
- English devices should display/search the app as **`Siyaq`**; Arabic devices as
  **`سياق`**. The launcher label must **not** include the generic word `لعبة`.
- The adaptive launcher icon currently shows an **unintended white background**
  and needs a separate branding correction.

Product/integration follow-ups:
- Legacy Amber-Noir screens (`features/{game,v2}/presentation/screens/*`) are
  unrouted dead code kept only for their widget tests; schedule removal + test
  migration to the Siyag screens.
- Live backend tunnel is ephemeral/offline between sessions — live-data areas
  show offline states until a fresh `CG_BASE` is provided.
- Account/economy phases (wallet, ranked, social rooms, presence) are planned but
  not yet built in the UI (see `MOBILE_V2_INTEGRATION_PLAN.md`).

## Current visual concerns being addressed

Both themes felt muted/flat: beige gold, insufficient card/background separation,
dark surfaces too close in value, pale low-contrast light mode, secondary text
reading as disabled, weak nav selection, and the Weekly card not feeling like the
primary action. The token refinement targets each.

## Recommended next phase

After this refinement: (1) the two branding follow-ups above (app label per
locale + adaptive-icon background), then (2) resume the account/economy
integration (Phase 4 → wallet → ranked → social) per the integration plan, then
(3) remove the legacy Amber-Noir screens and migrate their tests.
