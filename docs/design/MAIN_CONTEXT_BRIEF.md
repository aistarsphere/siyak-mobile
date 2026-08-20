# Main context brief — Siyaq Orbit Live (multiplayer) refactor

Written by Main after Phase 1 inspection, 2026-08-20. Read this before touching code.

## 1. Architecture as it actually is

- **Flutter + Riverpod.** `Notifier`/`AsyncNotifier` controllers, `ConsumerStatefulWidget`
  screens. No generated routing: navigation is imperative
  `Navigator.of(context).push(siyagRoute(Widget))` — `lib/features/siyag/presentation/siyag_route.dart`
  (fade + slide y 12->0, 240ms, easeOutQuint, honours `MediaQuery.disableAnimationsOf`).
- **Design system** lives in `lib/core/design/`:
  - `tokens/` — `SiyaqColors`, `SiyaqSpacing`, `SiyaqTypography`, `SiyaqMotion`,
    `SiyaqElevation`, `SiyaqIcons`
  - `organic/` — `OrganicColors`, `OrganicTokens`, `OrganicType`, `SyIcon`, `SyPrimitives`
    (the newer layer, from the Claude Design "organic" DS bundle)
  - `theme/context_tokens.dart` — `context.colors`, `context.motion` (reduced-motion aware)
  - `components/{foundation,gameplay,shared}/` — `SiyaqButton`, `SiyaqText`, `SiyaqSurface`,
    `SiyaqGuessRow`, `SiyaqGuessComposer`, `SiyaqGuessHighlight`, `SiyaqHintPanel`,
    `SiyaqPlayerRow`, `SiyaqChip`, `SiyaqStatusIndicator`, `SiyaqEmptyState`, ...
  - barrel: `lib/core/design/siyaq_design.dart`
- **Localization**: `AppLocalizations` via `ref.watch(localizationsProvider)`;
  `loc('key')`, `loc.fill('key', {...})`, `loc.direction`. Tables in
  `core/localization/strings_ar.dart` / `strings_en.dart`. Arabic is the default.
- **Script vs locale**: `SiyaqScript.{arabic,latin,mono}` is chosen from the *game*
  language, not the app locale — the secret word and guesses follow `room.language`.

## 2. Gameplay surfaces

| Screen | File | Role |
|---|---|---|
| Multiplayer room | `siyag_room_game_screen.dart` (475) | **primary target** |
| Solo practice | `siyag_practice_game_screen.dart` + `siyag_game_view.dart` (603) | shared view |
| Weekly | `siyag_weekly_game_screen.dart` | uses `SiyagGameView` |
| Ranked 1v1 | `siyag_ranked_match_screen.dart` (553) | |
| Lobby | `siyag_room_lobby_screen.dart` -> pushes room game | |

## 3. Backend truth for multiplayer (V2) — what CAN be represented

`lib/features/v2/domain/entities/room.dart`:

- `Room.participants: List<RoomParticipant>` — `participantId`, `label`, `isHost`,
  `connected`, `isMe`
- `Room.sharedHistory: List<SharedGuess>` — `guess`, `byParticipantId`, `byLabel`,
  `isMine`, `isSystemHint`. **Arrival-ordered.**
- `Room.sortedHistory` — same list re-sorted by rank ascending
- `Room.state: RoomState{lobby, playing, solved, expired}`, `winner`, `secretWord`,
  `totalWords`, `hintMode`, `language`, `category`, `joinCode`, `maxPlayers`
- `Guess` — `word`, `rank` (int), **`proximity` (double 0-100, server closeness)**,
  `tier` (HeatTier), `isSecret`, `originalWord`/`originalDiffers`

`RealtimeRoomController` (`realtime_room_controller.dart`): WS stream with
`SequenceTracker` dedup, gap -> REST snapshot recovery, exponential backoff.
`RoomConnStatus{idle,connecting,connected,recovering,reconnecting,closed}`.
`RoomEventType{guessAccepted, sharedDuplicate, participantJoined, participantLeft,
hostChanged, hintRevealed, roomStarted, roomSolved, roomExpired, snapshot, pong, unknown}`.

### Representable truthfully
multiple players; persistent identity (`participantId`); one path per player
(group `sharedHistory` by `byParticipantId`); best-guess-per-player (min `rank`);
current-player distinction (`isMine`/`isMe`); shared secret/centre (`secretWord`);
room state updates; winner (`room.winner`); join/leave (`participantJoined/Left`
+ `connected`).

### NOT on the wire — must be derived or declared a gap
- **Per-player colour** — no colour field. Must be derived deterministically from
  `participantId` so every client agrees. Derivation, not fabrication.
- **Per-guess submission index** — `SharedGuess` carries no `attempt_number`.
  Nasij thread angle is a function of submission index, so ordering must come from
  `sharedHistory` arrival order and must survive snapshot recovery, or the board
  rearranges between frames. **Risk to verify.**
- **Live per-player presence beyond `connected`** (typing, spectating) — absent.

## 4. The actual gap this task closes

1. **The Orbit board is not rendered anywhere.**
   `lib/features/game/domain/orbit/nasij_geometry.dart` (423 lines) is a complete,
   tested pure geometry model — `NasijSpace`, `NasijBand`, `NasijLayout.layout()`,
   `.rosette()`, `.hintWedge()`, `NasijThread` — and `grep` shows it is imported by
   **exactly one file: its own test**. Zero widgets paint it. 39 tests pass on maths
   that nothing draws.
2. **Multiplayer gameplay is a list.** Header -> reconnecting banner -> hint panel ->
   "closest"/"latest" highlight cards -> rank-sorted `SiyaqGuessRow`s with attribution
   -> composer. Correct and functional, but it is the spreadsheet the design brief
   explicitly rules out.
3. **Victory is static.** `_Winner` is a `ColoredBox` + trophy tile + button. The design
   calls for the knot bloom (7->38 over 900ms spring, glow 66 shimmering at 3s,
   *no confetti*).
4. **Motion tokens are stale.** `SiyaqMotion`'s doc comment asserts "Figma specifies no
   motion at all" and carries values over from a legacy `SM` class. The Claude Design
   project *does* specify motion. The token file needs the design's real durations
   and curves added (not a rewrite — additions + corrected provenance).
5. **Two different closeness scales coexist.** `SiyaqHeat` is a continuous ramp over
   `log(rank)/log(total)` with 6 named bands; `NasijBand` is discrete over
   `proximity` 0-100. Both are legitimate; the board must use `proximity` (that is
   what the design's `geom()` consumes) while the existing rows keep `SiyaqHeat`.
   **Do not change either scale's thresholds** — the win/rank/heat contract is frozen.

## 5. Hard constraints for this task

- Do NOT change the guess/hint/room/rank/heat/win API contracts.
- Do NOT advance a player's thread before the confirmed state change. Animation
  follows authoritative Riverpod state, which follows the socket/REST snapshot.
- Do NOT invent per-player data the wire does not carry.
- Preserve Arabic RTL / English LTR. Arabic is a *different composition*, not a mirror
  (threads counter-clockwise from 168deg; no letter-spacing; no uppercase).
- Keep `ExcludeSemantics` on the painter and keep the row list as the semantic source
  of truth — that is the design's own accessibility answer.
- Reduced motion: identical final frame, no draw-in, 120ms cross-fade.

## 6. Test surface that must stay green

`test/unit/nasij_geometry_test.dart` (39), `test/unit/heat_test.dart`,
`test/design/room_golden_test.dart`, `room_migration_test.dart`,
`test/design/motion_test.dart`, `test/v2/mock/room_realtime_test.dart`,
plus harnesses in `test/helpers/room_harness.dart` and mocks in `test/support/v2_mock/`.
