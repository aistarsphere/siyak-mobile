# Mobile V2 Integration Plan — Siyag Flutter × Backend Contract `2026-07.1`

Functional source of truth: `design_reference/Siyag_Backend_Contract_Bundle/` (frozen `2026-07.1`, API `2.0`).
UI/UX source of truth: `design_reference/Siyag_Mobile_Design_Handoff_V2/`.
This plan maps every screen → endpoints/DTOs/events/errors and records preserve/migrate/remove.

## Architecture (feature modules under `lib/features/`)

Existing clean layering is kept: `domain/{entities,repositories,errors}` · `data/{remote,…}` · `presentation/{controllers,screens}`. DTOs never cross into `domain`; repositories are the swap seam; Riverpod controllers hold state; Siyag widgets render.

- **Reuse:** `features/v2/` (capabilities, profile, weekly, code-rooms, realtime infra: `SequenceTracker`, `ReconnectPolicy`, `RealtimeRoomController`, `RemoteRealtimeGateway`), `features/game/` (V1 solo), `features/siyag/` (live shell + screens), `core/network`, `core/theme/siyag_theme.dart`.
- **New feature modules:** `features/auth/` (Google/session/bootstrap), `features/account/` (account + public id), `features/wallet/`, `features/ranked/`, `features/social/` (presence, directory, social rooms, invitations, join-requests). Each with domain/data/presentation.
- **Shared plumbing (Phase 2):** session-token store; `V2ApiClient` gains `Authorization: Bearer`, `X-Game-Language`, `X-Request-ID`, `Idempotency-Key`, and 401→session-invalidation; error codes expanded to the full frozen set.

## Identity & auth model (contract)

- Guest = `X-Installation-ID: <uuid4>` (already implemented, `InstallationIdStore`). Account = `Authorization: Bearer sess_…`.
- `current_profile` routes accept either; `current_account` routes require bearer.
- Migration: pass `installation_id` in `POST /v2/auth/google`, or `POST /v2/auth/migrate-guest`. The current anonymous installation becomes the guest layer — **preserved, migrated, never deleted**.

## Screen → backend map (SCREEN_MAP × API_TO_SCREEN_MAP × contract)

| # | Screen | Endpoints / events |
|---|---|---|
| 1 | Bootstrap/Splash | `GET /v2/capabilities`, `GET /v2/auth/session` (bearer) or `POST /v2/profiles/register` (guest); recovery scan (ranked→room→weekly) |
| 2 | Sign-in (Google/guest) | Google ID token → `POST /v2/auth/google` |
| 3 | Guest migration | `POST /v2/auth/migrate-guest` |
| 4 | Profile setup | suggested name/avatar from sign-in; `PATCH /v2/account/me` |
| 5 | Home | `GET /v2/wallet`, weekly status, active states, pending social counts |
| 6–8 | Solo + result + hint | V1 `/api/context-game/*` (unchanged; hints free) |
| 9–10 | Weekly + leaderboard | `/v2/weekly/current`, `/join`, `/runs/{id}/guess`+`X-Game-Language`, `/hint`, `/give-up`, `/current/leaderboard`, `/my-position` |
| 11–12 | Wallet + transactions | `GET /v2/wallet`, `GET /v2/wallet/transactions` |
| 13–14 | Profile + privacy | `GET/PATCH /v2/account/me`, `GET /v2/profiles/me/stats`, `GET/PATCH /v2/social/preferences` |
| 15 | Ranked entry/tier | `GET /v2/ranked-matches/tiers`, `GET /v2/ranked/me`, `GET /v2/wallet` |
| 16 | Matchmaking | `POST /v2/matchmaking/join`, poll `GET /v2/matchmaking/tickets/{id}`, `GET /v2/matchmaking/active`, `POST .../cancel` |
| 17–20 | Match / states / result | `GET /v2/ranked-matches/{id}`, `POST .../ready|guess|reconnect|forfeit`; ranked WS `/ranked-matches/{id}/events` |
| 21 | Ranked leaderboard | `GET /v2/ranked/leaderboard`, `GET /v2/ranked/history` |
| 22 | Multiplayer hub | active room, `GET /v2/social/invitations`, `GET /v2/social/join-requests/mine`, join-by-code fallback (`/v2/rooms/join`) |
| 23 | Create room | `POST /v2/social/rooms` (visibility/hint_policy/min/max enums) |
| 24 | Host lobby | `GET /v2/social/rooms/{id}`, `POST .../start|cancel`, invitations + join-request queue |
| 25 | Find players | `GET /v2/social/players?q&cursor&available_only`, `GET /v2/social/players/{id}` |
| 26 | Incoming invitations | `GET /v2/social/invitations`, `POST /v2/social/invitations/{id}/accept|decline` |
| 27–28 | Open rooms / preview | `GET /v2/rooms/open`, `GET /v2/social/rooms/{id}` |
| 29–30 | Join request pending / host queue | `POST /v2/rooms/{id}/join-requests`, `GET .../join-requests`, `POST .../{id}/accept|decline|cancel`, `GET /v2/social/join-requests/mine` |
| 31–32 | Room game / result | code-room gameplay `/v2/rooms/{id}/guess|hint` + room WS `/v2/rooms/{id}/events` (existing `RealtimeRoomController`) |
| 33–36 | Recovery / session-expired / reconnect | REST snapshot refresh + `after_seq` replay; 401 → re-auth |

## Realtime (3 channels — §11)

Room `/v2/rooms/{id}/events?installation_id&after_seq` · Ranked `/v2/ranked-matches/{id}/events?installation_id&after_seq` (has `state_version`) · Social `/v2/social/events?session_token` (no seq — reconcile via REST). Dedup by `seq`/`event_id`; snapshot first; `after_seq` replays gap; `resync`/REST refresh after long gap. Reuse `SequenceTracker`/`ReconnectPolicy`.

## Preserve / Migrate / Remove

- **Preserve:** V1 solo, weekly (reconcile shapes), code-rooms + realtime infra, Siyag design system, `InstallationIdStore`.
- **Migrate:** identity (installation → guest→account); WS auth adds `after_seq`; wallet/ranked stats consolidate onto account+`/profiles/me/stats`.
- **Remove (after replacement):** legacy Amber Noir screens `features/v2/presentation/screens/*` and old V1 shell (`features/game/presentation/screens/{shell,home,splash}_screen.dart`); migrate their widget tests to Siyag screens.

## Non-negotiables

Server authoritative for wallet/reward/rating/winner/timer/capacity/presence — never computed locally. No invented endpoints/enums/events. Hints are free (no paid-hint debit in `2026-07.1`). Production remains mock-free (mocks in `test/support`).

## Execution order

P0 config ✓ · P1 this plan ✓ · P2 API+domain foundation · P3 Google auth+bootstrap+migration · P4 account/profile · P5 wallet+home · P6 solo/weekly reconcile · P7 ranked · P8 social rooms+presence · P9 realtime+recovery · P10 UI+dead-code removal · P11 tests+live QA+screenshots.

## Known live-QA blockers (code proceeds regardless)

1. Backend tunnel currently down (health `000`) — no live run/screenshots until a fresh `CG_BASE` is provided.
2. Google live sign-in needs an **Android OAuth client** (package `com.kaher.siyak` + debug SHA-1 `8C:19:56:E3:34:B3:EA:56:20:A6:71:26:EE:C0:7B:E6:1A:DA:5E:3D`) and an **iOS OAuth client** registered under project `siyag-503420`, plus a Google account on the test device. Web/Server client ID is wired (`serverClientId`).
