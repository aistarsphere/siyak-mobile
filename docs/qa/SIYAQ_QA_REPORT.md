# Siyaq / Siyag — Production Device QA Report

**Date:** 2026-07-26 · **Build:** `1.0.0+1` (debug), branch `main` @ `35c04aa`
**Backend:** production `https://siyak-api.aljoodnet.info/api/context-game` (V2, contract 2026-07)
**Scope:** real-device QA pass to surface integration/API/UX/runtime issues before the polish phase.
**No fixes were applied** — this is a findings-only report, as briefed.

---

## Method & honest coverage

| Area | How it was tested | Depth |
|---|---|---|
| Android runtime (guest surface) | Real device, live launch + navigation + screenshots + logcat | **Executed** ✅ |
| Live API integration (guest) | Confirmed via live gameplay data on device + endpoint audit | **Executed** ✅ |
| API contract compatibility | Full static audit of every call vs. live OpenAPI (195 paths) | **Executed** ✅ |
| UX / polish | Full static read of 17 screens + on-device verification of reachable ones | **Executed** ✅ |
| Google / Apple sign-in | **Not executed** — OAuth consent / Face ID require a human at the device | ⚠️ manual |
| Ranked 1v1 (2 players) | **Not executed** — needs two humans on two devices simultaneously | ⚠️ manual |
| Notifications delivery/tap | **Not executed** — needs a push sent + a human to observe/tap | ⚠️ manual |
| iOS runtime | **Not executed** — the iPhones are only reachable wirelessly + locked; Flutter could not attach | ⚠️ blocked |
| Account-gated Wallet/Profile/Social live | **Not executed** — requires a signed-in session (blocked by the above) | ⚠️ manual |

I did **not** fabricate results for the manual/blocked rows. Exact repro steps for those are in
[§ Manual test plan](#manual-test-plan-flows-that-need-a-human).

---

## Device information

**Android (tested):**
- Nubia **NX679J**, Android **13** (API 33), arm64-v8a, 60 Hz.
- App installed as `com.kaher.siyak`, versionName 1.0.0, targetSdk 36, minSdk 24.

**iOS (not tested this pass):**
- Physical iPhones are present but only advertised over the local network and locked; `flutter devices`
  returned "The device must be opted into Developer Mode to connect wirelessly (code -27)". iOS runtime QA
  needs an iPhone **cabled + unlocked + Developer Mode on** (this same app was device-verified on an iPhone
  earlier in the project — SYG-X74H4 — so the build itself runs on iOS).

---

## Passed (executed on the Android device)

All of the following were observed live on NX679J against the production backend, as a fresh **guest**
(secure-storage cipher migration ran clean: RSA→AES_GCM, 0 items migrated). Screenshots in
`docs/qa/screenshots/`.

1. **Fresh launch → Home** (`01_home_guest.png`) — splash resolves to Home; `effective CG_BASE =` production;
   Firebase initializes; **no crash, no exceptions** in logcat; installation/guest identity created
   (public code `HXW86V` shown). Correct **RTL** Arabic-first layout.
2. **Live weekly data on Home** — hero card shows live countdown (`23h 59m`) and category `عام` pulled from
   the backend, plus stats pill (0 games / 0 solved) and bottom nav (Account / Ranking / Home).
3. **Solo Practice setup** (`04_solo_setup_live_categories.png`) — **7 live categories** loaded from the
   backend (عام/الحيوانات/الرياضة/الزراعة/التقنية/الطعام/الجغرافيا), language (ar/en) + difficulty selectors,
   start button. RTL correct.
4. **Weekly overview** (`05_weekly_overview.png`) — reached from Home; live challenge loads (status `نشط`,
   category `عام`, countdown 59m/23h/00d, placement `—` as guest). Start button present.
5. **Multiplayer hub** (`02_multiplayer_hub.png`) — Create Room / Join by code / Ranked 1v1 / **Players
   online (Phase 8)** rows all render; the Players row correctly shows **no invite badge** as guest.
6. **Players / social guest gate** (`03_players_guest_gate.png`) — the account-only screen correctly shows
   the sign-in prompt ("سجّل الدخول لرؤية اللاعبين / invitations & online list for accounts only") instead of
   erroring — Phase 8 guest gating works on-device.
7. **Navigation & back stack** — Home → hub → Players → back → Home → Solo → back all worked with no route
   errors in logcat; RTL back affordances point the correct direction.

**Automated regression suite (host):** `flutter test` — 75 v2 + game unit/widget tests pass;
`dart analyze lib` clean.

---

## Failed / blocked

### FAIL-1 (test maintenance, not an app bug) — live E2E integration tests are stale
- **What:** `flutter test integration_test/live_e2e_test.dart -d NX679J` — both tests fail:
  `Timed out waiting for … text "ابدأ لعبة جديدة"` (Arabic) and `"Start New Game"` (English).
- **Root cause:** the tests were written for the **pre-redesign** Home, where "ابدأ لعبة جديدة" was a direct
  button on Home. The current Siyag Home has **no such text** — it shows the weekly hero + mode cards
  ("تدريب حر / Solo Practice"), and starting a solo game is now behind the Solo card → setup → "ابدأ اللعب".
  Verified: the app itself launches to Home fine (see Passed §1). `v2_live_test.dart` (weekly) is similarly
  keyed to `لعبة فردية`, which also no longer matches the redesigned Home.
- **Impact:** the live E2E safety net does not currently run; it must be updated to the Siyag flow.
- **Verdict:** test staleness. **Not a runtime regression.** (Deferred to Phase 11 per "don't fix yet".)

### BLOCKED — flows requiring human interaction (not run; see Manual test plan)
Google sign-in, Apple sign-in, session-expiry/refresh live, account Profile states
(active/suspended/banned/deleted), account Wallet, 2-device Ranked play, Social rooms with 2 devices,
and all Notification delivery/tap cases. iOS runtime entirely (device unreachable).

### No crashes observed
No `FATAL EXCEPTION` / `AndroidRuntime` crashes and no Flutter framework exceptions in logcat across the
entire guest session. **Crash report: empty.**

---

## API compatibility findings

Full static audit: **51 REST endpoints + 2 WebSocket channels** vs. the live OpenAPI (195 paths).
Result: **all REST paths, HTTP methods, required request fields, and query params the app uses exist in and
match the contract.** 3 findings.

> **Contract caveat:** every 2xx response body in the live OpenAPI is typed as untyped
> `{object, additionalProperties:true}`, and no `securitySchemes`/`security` are declared. So response-field
> names (mappers) and guest-vs-bearer expectations **cannot be validated from the contract** — only paths,
> methods, request bodies and query params can. Mapper drift would surface as silent nulls at runtime.

### API-1 (medium) — `push/register` sends wrong field names for build + notifications flag
- `POST /installations/push/register` — code sends `build_number` + `notification_permission` (string) and
  omits `device_model`/`os_version`; the contract's `RegisterPushRequest` expects **`app_build`** and
  **`notifications_enabled` (boolean)**. The 3 required fields (`installation_id`,`platform`,`token`) match,
  so the token **does register**, but FastAPI silently drops the mismatched extras → app-build and the
  notifications-enabled flag are **never recorded** on the token (degrades push targeting/analytics). The
  sibling `POST /installations/register` legitimately uses `build_number`/`notification_permission`, which is
  why the names were reused here by mistake.
- `lib/features/auth/data/remote/remote_installation_repository.dart:68,71`
- **Verdict:** mobile issue.

### API-2 (low) — room create sends `hint_mode: "medium"` for standard mode
- `POST /rooms` — code sends `hint_mode: hintMode == adaptive ? 'adaptive' : 'medium'`; everywhere else the
  app encodes hint mode as `HintMode.code` → `"standard"`/`"adaptive"` (see room hint & weekly hint). `"medium"`
  is really a *difficulty* value. Contract types `hint_mode` as a free string (no enum), so it can't be proven
  rejected — but if the backend validates `hint_mode ∈ {standard,adaptive}`, standard rooms are misconfigured.
- `lib/features/v2/data/remote/remote_repositories.dart:190`
- **Verdict:** likely mobile issue (unverifiable from contract).

### API-3 (low) — two room families in the contract; confirm which is canonical
- The contract exposes both `/rooms/*` **and** `/social/rooms/*`. The app uses `/rooms/*` throughout, and the
  Phase 8 host-invite posts to `/rooms/{id}/invitations` (which exists under that family). **Needs backend
  confirmation** that invitations created via `/rooms/{id}/invitations` are surfaced to the invitee's
  `GET /social/invitations` — if invitations only bind to the `/social/rooms/*` family, the invite→accept
  flow would silently not connect. This is the single most important thing to verify live for Phase 8.
- `remote_repositories.dart:185-251`, `remote_social_repository.dart:89`
- **Verdict:** ambiguous — verify against backend.

**Non-findings (verified correct):** auth google/apple bodies, migrate-guest, account PATCH, profiles
register/me, matchmaking join, all guess bodies, rooms/join, weekly join, and — specifically — the Phase 8
`POST /rooms/{id}/invitations` field `target_public_player_id` **matches the contract exactly**. Query params
for social/players, wallet/transactions, and weekly leaderboard all match.

---

## UX issues

Full list (71 issues: 5 high / 32 medium / 34 low) in **`UX_ISSUES_REPORT.md`** at the repo root.
Highlights that most affect production readiness:

- **Ranked match (staked) has 4 high-severity gaps:** silent error swallowing on every action, stream errors →
  infinite spinner, **forfeit with no confirmation**, and **no guard against abandoning a staked match via
  back**. These risk real coin loss and should lead Phase 10.
- **Leaderboard renders blank with 1–2 players** (podium needs ≥3) and never loads if the weekly challenge
  fetch fails.
- **Home weekly CTA** has a null `onTap` (looks disabled) — device-verified the card still navigates, so
  downgraded to medium.
- **Cross-cutting:** inconsistent async patterns (`.value` vs `.when`), destructive actions without
  confirmation/busy guards, and a largely-bypassed localization layer (no real English/LTR path despite
  `strings_en.dart`).

---

## Manual test plan (flows that need a human)

Run these on a cabled+unlocked Android **and** iPhone (Developer Mode on). Capture screenshots/video.

1. **Google sign-in** (both OS): tap sign-in → complete Google consent → verify Home shows the account
   (avatar/name), then kill+reopen → session restores with **no** re-prompt; sign out → sign in again →
   **same** account (no duplicate). Watch logcat for `[Auth] … OK created=false` on the 2nd login.
2. **Apple sign-in** (iPhone): first login (Face ID) → account created; sign out → sign in → `created=false`,
   same `publicPlayerId`.
3. **Session expiry:** with a signed-in session, let it expire (or revoke server-side) → make any API call →
   confirm one `POST /auth/refresh` rotates the token and the request retries once; if refresh fails, app
   drops to guest with **no infinite loop** (code path verified in `v2_api_client.dart`; needs live trigger).
4. **Wallet (account):** sign in → open Home coins pill / wallet → balance loads and persists across restart.
5. **Ranked 1v1 (two devices):** both sign in → both enter Ranked → same tier → matchmaking pairs them →
   play turns → verify opponent guesses appear (now realtime-nudged, Phase 9) → result + rating update →
   test: background one app mid-match (reconnect), double-tap send (dedup), forfeit.
6. **Social rooms (two devices):** A creates a room → A opens "دعوة لاعبين" → invites B → **B should receive
   the invitation** on the Players screen (this validates API-3) → B accepts → both in lobby → A starts.
7. **Notifications (both OS):** confirm FCM token registers on login (logcat `[Notifications] FCM token
   registered`); send a test push → verify foreground (in-app banner), background, and terminated delivery,
   plus tap-to-open; confirm no duplicates. (Token minting already verified working on both platforms.)

---

## Recommendation

The **guest surface is production-solid** on Android: clean launch, live backend data (weekly + categories),
correct RTL, no crashes, and the Phase 8 social/Phase 9 realtime code renders and gates correctly. The
integration is sound; the API layer matches the contract with only one real defect (API-1).

Before shipping, in priority order:
1. **Verify API-3 live** (does a `/rooms/{id}/invitations` invite reach the invitee?) — gates Phase 8.
2. **Fix API-1** push-register field names (quick, improves push targeting).
3. **Phase 10 polish** led by the 5 high UX issues (ranked-match safety + leaderboard blank state).
4. **Run the manual test plan** on cabled Android + iPhone (auth, ranked 2-device, notifications).
5. **Update the live E2E tests** (FAIL-1) to the Siyag flow so the safety net runs again (Phase 11).

**No fixes were made in this pass** — awaiting the next implementation phase.
