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

### Pointing at a different backend

The API base URL resolves in this order (see `lib/core/config/app_config.dart`):

1. **In-app developer override** — Stats tab → الإعدادات → رابط الخادم.
2. **Build-time define**:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
   ```
   - Android emulator → `http://10.0.2.2:8000`
   - Physical Android device via USB → `adb reverse tcp:8000 tcp:8000`
     then `http://127.0.0.1:8000`
   - iOS simulator → `http://127.0.0.1:8000`
3. **Default**: the documented public URL `https://v4nbg9o9snrk.shares.zrok.io`.

## Tests

```bash
flutter test          # 44 tests: models, heat mapping, config, i18n/RTL,
                      # controller flows vs a scripted mock API, widget tests
```

Live end-to-end test on a device (drives the real app against a real backend):

```bash
adb reverse tcp:8000 tcp:8000   # for a USB Android device + local backend
flutter test integration_test/live_e2e_test.dart -d <device> \
  --dart-define=API_BASE_URL=http://127.0.0.1:8000
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
