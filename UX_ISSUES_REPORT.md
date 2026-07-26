# Siyaq / Siyag — UX & Polish Issues Report

> **Status:** collection only — **no fixes applied** (per the QA brief). This feeds
> the upcoming Phase 10 polish pass.
> **Method:** full static read of all 17 Siyag screens + shared widgets + theme +
> localization, cross-checked against on-device behaviour on a real Android device
> (Nubia NX679J, Android 13) where reachable as a guest.

**Summary:** 71 issues across 17 screens + shared widgets — **5 high, 32 medium, 34 low**
(one originally-high Home finding downgraded to medium after on-device verification —
see Home §1). Dominant patterns: async data rendered via `.value` with no
loading/error/empty states (Home, Ranked, Profile, Leaderboard) while other screens do
it correctly; destructive actions (forfeit, leave, sign-out) with no confirmation or
busy guard; English "kicker" labels + hardcoded Arabic throughout despite a shipped
`strings_en.dart` + `loc()` system that only Profile/gameplay controllers use.

---

## Home — `siyag_home_screen.dart`

- [SEVERITY: medium] **(device-verified)** Weekly-hero primary CTA "ابدأ التحدي الأسبوعي"
  has **no `onTap`** — `siyag_home_screen.dart:279-282`. The `SiyagPrimaryButton` renders
  dimmer than a live button (looks disabled). **On-device test:** tapping the button still
  navigates to the Weekly overview because the whole card is wrapped in a nav `SiyagTap`
  (`:115-119`), so the flow is **not broken** — but the CTA looks disabled yet works, which
  is confusing. Fix: give the button its own `onTap` (or drop it to a label).
- [SEVERITY: medium] Profile/caps/weekly/wallet read via `.value` with no loading/error/empty
  handling — `:32-36` — while loading it shows placeholders ("لاعب مجهول", "—"); a fetch
  failure is indistinguishable from empty; no retry.
- [SEVERITY: medium] Countdown formatter emits English unit letters in an Arabic RTL UI —
  `:24-28` — `'${d.inDays}d ${d.inHours%24}h'` mixes Latin d/h/m into the layout.
- [SEVERITY: low] Hardcoded English kickers — `:56` ('Semantic Word Game'), `:265` ('Ends in'),
  `:103` ('RANK #').
- [SEVERITY: low] No pull-to-refresh and no skeleton — `:43` — live coins/weekly/rank pop in abruptly.
- [SEVERITY: low] Weekly subtitle duplicates the card title when weekly is null — `:122-127` vs `:273`.

## Shared top bar — `siyag_topbar.dart`
- [SEVERITY: low] `trailing` is force-boxed into a fixed 36×36 slot — `:73` — a wider indicator would clip.

## Solo Practice setup — `siyag_practice_setup_screen.dart`  _(device-verified: renders 7 live categories, functional)_
- [SEVERITY: medium] Error state has no retry — `:49-54` — modes-load failure shows only "تعذّر التحميل"; dead-ends.
- [SEVERITY: medium] Start button not resilient to failure — `:155-179` — `startNewGame` awaited with no
  try/catch; a throw leaves `busy` stuck true, and it `pushReplacement`es regardless of success.
- [SEVERITY: medium] No empty state for zero categories — `:94, 157`.
- [SEVERITY: low] Header is English-only ("SOLO PRACTICE") with no Arabic title — `:41`.
- [SEVERITY: low] `busy` is a plain local that resets on any parent rebuild — `:31`.

## Solo Practice game — `siyag_practice_game_screen.dart`
- [SEVERITY: low] Secret-word fallback can be empty — `:100-102` — result may show a blank word.
  _(Otherwise handles errors/duplicates via localized snackbars — the good pattern. Phase 6 hint
  reconciliation fix verified present at `:129`.)_

## Shared gameplay view — `siyag_game_view.dart` (solo + weekly)
- [SEVERITY: medium] Keyboard submit bypasses the busy guard — `:135` → `_submit()` (`:75`) never checks
  `widget.submitting`; only the send button is guarded (`:149`) — pressing Enter can double-submit.
- [SEVERITY: medium] Active sort-tab text uses `SC.bg` on the gold fill — `:339` — low contrast in light theme; use `SC.onColor`.
- [SEVERITY: medium] English hardcoded labels — `:117` ('GUESSES'), `:229/:241` ('Closest'/'Latest'), `:258` ('Hints').
- [SEVERITY: low] No empty state for zero guesses — `:293-310`.
- [SEVERITY: low] Submitting force-resets sort to "newest" every guess — `:79`.
- [SEVERITY: low] Send icon points right (LTR) in an RTL input — `:171`.

## Result — `siyag_result_screen.dart`
- [SEVERITY: low] Win-only screen with no lose/give-up variant — `:80-88` — always "🎉 / Solved!" + confetti.
- [SEVERITY: low] English kicker 'Solved!' (`:88`); confetti always plays with no reduced-motion check (`:135`).

## Ranked screen — `siyag_ranked_screen.dart`
- [SEVERITY: medium] Loading state disguised as real/empty data — `:22-24, 54-56, 112, 120` — tiers `.value ?? []`
  shows "لا توجد مستويات متاحة حالياً" during load; rating card shows fake defaults (1000, 0ف·0خ).
- [SEVERITY: medium] `SiyagPrimaryButton` (width:infinity) in a Row without Expanded/Flexible — `:170` — overflow risk.
- [SEVERITY: medium] No error/retry for stats or tiers load failure — `:22-23`.
- [SEVERITY: low] Uses a Material `AppBar` — `:40-45` — inconsistent with `SiyagTopBar`.
- [SEVERITY: low] Matchmaking error is static text with no retry — `:80-84`.

## Ranked match — `siyag_ranked_match_screen.dart`
- [SEVERITY: high] All match actions swallow errors silently — `:82-90` (`catch (_) {}`) — a failed
  guess/ready/forfeit gives no feedback in a live, staked match.
- [SEVERITY: high] Stream errors are swallowed → infinite spinner — `:39` + `:108-109` — persistent failure
  leaves a permanent spinner with no error/retry.
- [SEVERITY: high] Forfeit has no confirmation — `:315-320` — one accidental tap forfeits the match + coin stake.
- [SEVERITY: high] A staked active match can be abandoned via AppBar/system back with no guard — `:101-106`
  — no `PopScope`/confirmation.
- [SEVERITY: medium] Turn timer is a 2s poll snapshot — `:263` — countdown jumps in 2s steps.
- [SEVERITY: medium] Send has no in-flight disabled state and clears input pre-result — `:292-294, 245`.
- [SEVERITY: medium] `SiyagPrimaryButton` width:infinity directly in a Row (send) without Flexible — `:292`.
- [SEVERITY: low] Guess rows show rank only, no heat bar/color — `:299-313`.
- [SEVERITY: low] Hardcoded cap of 20 guesses with silent truncation — `:299` (`.take(20)`).
- [SEVERITY: low] No empty state before the first guess — `:299`.

## Multiplayer hub — `siyag_multiplayer_hub_screen.dart`  _(device-verified: renders, Players row + Phase 8 works)_
- [SEVERITY: low] English-only kicker 'Multiplayer' with no Arabic title — `:34`.
- [SEVERITY: low] Invite badge silently reads 0 while loading/on error — `:24-25`.

## Create room — `siyag_create_room_screen.dart`
- [SEVERITY: medium] Error state 'تعذّر التحميل' has no retry — `:50-55`.
- [SEVERITY: medium] Selected-chip text uses `SC.bg` on the accent fill — `:187, :106` — low contrast in light theme.
- [SEVERITY: medium] No empty state for zero categories — `:80, 124`.
- [SEVERITY: low] English-only kicker 'Create Room' — `:42`. _(Create failure handled via localized snackbar — good.)_

## Join room — `siyag_join_room_screen.dart`
- [SEVERITY: medium] Join enabled with an empty code, no client-side validation — `:125, 30`.
- [SEVERITY: low] Placeholder 'ABCD12' (6 chars) contradicts the 8-char limit — `:95` vs `:91`.
- [SEVERITY: low] English-only kicker 'Join by code' — `:62`.

## Room lobby — `siyag_room_lobby_screen.dart`
- [SEVERITY: medium] Inconsistent/unconfirmed leave — `:85-93` — top-bar back does destructive `leave()` with no
  confirm, while Android system back (no `PopScope`) pops without leaving server-side.
- [SEVERITY: medium] `room==null` yields an indefinite spinner with no error state — `:78-79`.
- [SEVERITY: medium] Host "ابدأ اللعبة" has no busy/disabled state — `:118-143` — double-tap can start twice.
  _(The Phase 8 invite sheet, by contrast, has proper loading/empty/error — good.)_
- [SEVERITY: low] English kickers 'Lobby' (`:83`) and 'Join Code' (`:202`).

## Room game — `siyag_room_game_screen.dart`
- [SEVERITY: medium] Vocabulary size hardcoded to `22548` for heat calc — `:38` — wrong heat for other categories.
- [SEVERITY: medium] Hint button is fire-and-forget — `:120-129` — no await/catch/spinner/disabled state.
- [SEVERITY: medium] Top-bar back pops without leaving the room — `:115` (no `onBack`/`PopScope`).
- [SEVERITY: low] No empty state before the first guess — `:227-234`.
- [SEVERITY: low] English 'PLAYERS' (`:117`) and Kicker 'Winner' (`:332`); winner overlay has no confetti.

## Weekly screen — `siyag_weekly_screen.dart`  _(device-verified: loads live challenge, countdown frozen)_
- [SEVERITY: medium] Countdown is a static snapshot — `:19-26, 54` — the days/hours/minutes never tick down.
- [SEVERITY: medium] Start button has no busy guard and swallows `start()` failures — `:82-97`.
  _(Loading + error-with-retry on the screen itself, `:42-46`/`:238`, is the best pattern in the app.)_
- [SEVERITY: low] English-only kicker 'Hero Mode' — `:49`.

## Weekly game — `siyag_weekly_game_screen.dart`
- [SEVERITY: low] `run==null` shows a spinner with no error state if the run later fails — `:118-122`.

## Players / social — `siyag_players_screen.dart`  _(device-verified: guest sign-in gate renders correctly)_
- [SEVERITY: low] Uses a Material `AppBar` — `:114` — inconsistent with `SiyagTopBar`. _(Otherwise the model
  screen: sign-in prompt, loading, error+retry, empty state, pull-to-refresh.)_
- [SEVERITY: low] Guest sign-in prompt has no actual sign-in button — the user must leave and go to Profile.
- [SEVERITY: low] Snackbar/decline messages are hardcoded Arabic, not `loc()` — `:76, 79, 300`; decline failures silent (`:91`).
- [SEVERITY: low] Decline has no busy state while in flight — `:377-378`.

## Leaderboard — `siyag_leaderboard_screen.dart`
- [SEVERITY: high] 1–2 entries render a blank screen — `:73-76` — podium needs `entries.length >= 3` and the list
  uses `entries.skip(3)`, so with 1–2 players nothing draws.
- [SEVERITY: medium] No error state and no non-loading empty state — `:67-101`.
- [SEVERITY: medium] Leaderboard load gated on `weeklyChallenge.value` — `:46-52` — if weekly fails, weekId is
  never set and the leaderboard never loads.
- [SEVERITY: low] No pull-to-refresh; attempts stat uses a lightbulb icon (`:230`); English kicker 'Weekly Rankings' (`:61`).

## Profile — `siyag_profile_screen.dart` _(localization gold standard — uses `loc()` throughout)_
- [SEVERITY: medium] Sign-out is immediate with no confirmation or busy state — `:309-318`.
- [SEVERITY: medium] Name-save errors are swallowed — `:477-481` — `try/finally` with no `catch` closes the sheet as if saved.
- [SEVERITY: medium] Profile read via `.value` with no loading/error state — `:26, 38-49`.
- [SEVERITY: low] No pull-to-refresh on the profile stats.

---

## Cross-cutting themes (fix these once → clears a large cluster)

1. **Two divergent async patterns.** Weekly/Players/Create-Room/Practice-Setup use `AsyncValue.when`
   (+retry/empty); Home/Ranked/Profile/Leaderboard read `.value` and silently render placeholder/zeroed UI, so
   loading/empty/error are indistinguishable and un-retryable. Standardize on `.when` + retry.
2. **Localization inconsistent and largely bypassed.** Only ~19 `loc()` keys are referenced across all Siyag
   screens; everything else hardcodes Arabic body text + English mono "kickers". All 17 screens force
   `Directionality.rtl`, so despite a shipped `strings_en.dart` there is **no English/LTR UI path**.
3. **Destructive/critical actions lack confirmation + busy guards.** Forfeit, leave-room, sign-out have no
   confirm; start-room/start-weekly/ranked-send have no disabled state → double-fire and accidental-loss risks
   (worst in the coin-staked ranked flow).
4. **Silent error handling in multiplayer/ranked.** Ranked-match actions + stream `catch (_) {}`; room hint
   fire-and-forget; leaderboard/room-null paths spin forever.
5. **Layout constraint smell.** `SiyagPrimaryButton` (`width: double.infinity`) dropped directly into Rows
   without Expanded/Flexible in Ranked (`:170`) and Ranked Match (`:292`) — overflow risk.
6. **Static timers / hardcoded magic values.** Weekly countdown + ranked turn timer are frozen snapshots
   (no live tick); room-game heat uses hardcoded vocab size `22548`.
7. **Inconsistent back affordance + selection styling.** Ranked/Ranked-Match/Players use Material `AppBar`;
   the rest use `SiyagTopBar`. Selected chips/tabs mix `SC.bg` and `SC.onColor(accent)` → low-contrast on gold.
8. **Missing "zero guesses" empty states** across all gameplay timelines (solo/weekly/room/ranked).
