# لعبة السياق — Siyaq Word Explorer (Flutter client)

A Contexto-style semantic word-guessing game client for the existing (already
deployed) Contexto backend. The UI is a faithful implementation of the Stitch
project **“Siyag Word Explorer”** (Amber Noir design) — dark premium game UI,
warm amber CTAs, orange heat accents, glass panels, Arabic-first RTL.

> The backend lives in `~/Documents/automated_project/Contexto` (FastAPI).
> This app is **only a client** — no game logic is reimplemented; ranks,
> normalization, hints and suggestions all come from the API.

## Run

```bash
flutter pub get
flutter run                       # uses the documented public backend URL
```

### Backend base URL (one config only)

The base URL **includes** the `/api/context-game` path prefix and resolves in
this order (see the single source of truth `lib/core/config/app_config.dart`):

1. **In-app developer override** — الإحصائيات (Stats) tab → الإعدادات → رابط الخادم.
2. **Build-time define** — key is `CG_BASE`:
   ```bash
   flutter build apk --release \
     --dart-define=CG_BASE=https://<tunnel>.trycloudflare.com/api/context-game
   ```
3. **Default**: the documented public Cloudflare URL in `AppConfig`.

> The `trycloudflare.com` quick tunnel is **temporary** and rotates when the
> server restarts — when it changes, rebuild with a new `CG_BASE` or set the
> in-app override. The URL is not hardcoded anywhere else.

## Tests

```bash
flutter test          # 44 tests: models, heat mapping, config, i18n/RTL,
                      # controller flows vs a scripted mock API, widget tests
```

Live end-to-end test on a device (drives the real app against the live
Cloudflare backend — public URL, no tunnel/reverse needed):

```bash
flutter test integration_test/live_e2e_test.dart -d <device> \
  --dart-define=CG_BASE=https://<tunnel>.trycloudflare.com/api/context-game
```

Optional live-backend smoke test (needs a reachable backend):

```bash
./tool/live_smoke.sh                        # public URL
./tool/live_smoke.sh http://127.0.0.1:8000  # local backend
```

## Architecture

```
lib/
  main.dart / app.dart            # bootstrap, ProviderScope, MaterialApp (ar/en)
  core/
    config/app_config.dart        # base-URL resolution, timeouts, limits
    network/                      # Dio client + typed ApiException
    theme/                        # Amber Noir palette / Sora type scale / motion
    localization/                 # AR (default, RTL) + EN string tables
  features/game/
    data/models/                  # typed models matching the real API JSON
    data/context_game_api.dart    # endpoint bindings (/api/modes, /new, /game,
                                  #  /guess, /hint, /giveup, /datastore/words)
    data/game_repository_impl.dart
    domain/entities/heat.dart     # heat tiers + log-scaled closeness (tested)
    domain/repositories/          # GameRepository interface
    presentation/controllers/     # Riverpod: settings, stats, game state
    presentation/screens/         # splash, shell, home, game, solved, settings
    presentation/widgets/         # glass panels, glow buttons, heat bars,
                                  # hint pills, confetti, unknown-word card…
```

State management: **Riverpod** (Notifier-based). Networking: **Dio** with
timeouts, one safe retry on idempotent GETs, and typed error mapping.

## Game rules encoded in the client

- Duplicate **canonical** guesses (server-normalized `word`) never increment
  the attempts count — the existing row is highlighted instead.
- HTTP 400 on `/api/guess` = unknown/invalid word → inline "did you mean"
  card fed by `/api/datastore/words?q=…`.
- Autocomplete kicks in after 2 characters, debounced 300 ms.
- Hints (max 5) parse the semantic-neighbor word + rank out of the hint text
  and render compact pills (`تلميح 1 · حرب · #152`); raw text is the fallback.
- The secret word is only ever shown after `isSecret=true`.

## API V2 (weekly challenge · multiplayer · profiles · adaptive hints)

The app also integrates **Context Game API V2** (`<CG_BASE>/v2`) alongside V1.
V2 is gated by a live capability probe (`GET /v2/capabilities`): if it's
unreachable the app keeps V1 solo working and shows friendly "coming soon"
states.

- **Anonymous profile** — a UUID v4 in secure storage (no hardware id, no
  login), sent as `X-Installation-ID`; registered idempotently, editable name.
- **Weekly Challenge** — current challenge, run, adaptive hints, leaderboard
  (paginated) + your placement.
- **Multiplayer rooms** — create / join-by-code / lobby / shared live game /
  winner, over a **WebSocket** (`/v2/rooms/{id}/events?installation_id=<uuid>`):
  `room.snapshot` seed then ordered `{event_id,seq,type}` events; the client
  dedups by id, detects `seq` gaps, and recovers from the REST snapshot with
  exponential-backoff reconnect.
- **Gameplay language lock** — chosen before a session, immutable after.
- Backend is authoritative — no ranks/hints computed locally.

Config: base URL is one `CG_BASE` define (`CG_V2_BASE` optional; otherwise
`<CG_BASE>/v2`). Architecture: `lib/features/v2/{domain,data/{mock,remote},
presentation}` — screens/controllers depend only on the `domain/repositories/`
interfaces, so the remote client swaps in without touching UI. A developer
"Preview V2 (mock)" toggle in Settings runs V2 on deterministic mock data.

```bash
# optional live V2 smoke test (hits the real backend):
flutter test test/v2/live/live_v2_smoke.dart --tags live
```
# siyak-mobile
