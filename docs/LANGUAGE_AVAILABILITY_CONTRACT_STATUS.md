# Language Availability Contract v1 — implementation notes

Contract v1 is **live** and **implemented on the client**. Verified against
`https://siyak-api.aljoodnet.info/api/v1` on 2026-07-31.

## What the server sends

`GET /game/languages`:

```json
{
  "contract_version": "1.0.0",
  "default_language": "en",
  "languages": [
    {"code":"ar","display_name":"العربية","supported":true,"available":false,
     "state":"NO_ACTIVE_RELEASE","message_key":"language_ar_no_active_release",
     "active_release":null,"categories":{"available_count":0,"available":[]},
     "name":"Arabic","native_name":"العربية","dir":"rtl","ready":false},
    {"code":"en","display_name":"English","supported":true,"available":true,
     "state":"ACTIVE_MANAGED","active_release":{"release_id":"siyak-en-reference-v1-candidate-1",
       "ranking_mode":"precomputed_neighbors","word_count":20000,
       "secret_count":829,"runtime_loaded":true},
     "categories":{"available_count":1,"available":["general"]},
     "name":"English","native_name":"English","dir":"ltr","ready":true}
  ]
}
```

The pre-contract fields (`name`, `native_name`, `dir`, `ready`) are still there.
That is what makes the rollout non-breaking, and the client still reads `ready`
as a fallback so an older server keeps working.

Typed start failures, all live:

```
POST /game/new-game {"language":"ar","category":"general"}  → 503
  code NO_ACTIVE_RELEASE, language, message_key, retryable:true,
  available_languages:["en"]

POST /game/new-game {"language":"en","category":"animals"}  → 409
  code NO_PLAYABLE_SECRETS_FOR_CATEGORY, language, category, message_key,
  retryable:false, available_categories:["general"],
  details.remedy "choose_another_category"

POST /game/new-game {"category":"general"}                  → 200
  resolves to the configured default (en). Never Arabic.
```

`LANGUAGE_REQUIRED` is not emitted today because a default is always available.
The client understands it anyway, so it will not need a change when it appears.

## Client shape

| Layer | File |
|---|---|
| Models + states | `lib/features/game/domain/languages/language_availability.dart` |
| Typed failures | `lib/features/game/domain/languages/game_start_failure.dart` |
| Repository port | `lib/features/game/domain/languages/language_availability_repository.dart` |
| Remote + cache | `lib/features/game/data/remote_language_availability_repository.dart` |
| Controllers | `lib/features/game/presentation/controllers/language_availability_controller.dart` |
| UI | `lib/features/siyag/presentation/screens/siyag_practice_setup_screen.dart` |

Three decisions worth knowing:

**`available` is the only readiness flag.** `state` is the *reason* and never
gates play. `capabilities_contract.languages.<code>` also reports availability,
and it is deliberately not consulted — two sources deciding playability is how
they drifted apart before.

**A reason is never inferred.** On a pre-contract server `ready:false` decodes to
`state: UNKNOWN`, and the UI says "temporarily unavailable" rather than claiming
"no active word release", which it has not been told.

**The server's `message_key` is carried but not used to pick copy.** Localisation
stays client-side; honouring the key would let the backend choose the app's
words. It is kept for support and logging.

## Selection rules

Automatic selection runs **only** when the player has not chosen:

1. a saved language that is still supported — honoured *even when unavailable*,
   because it was their choice once;
2. otherwise the server default, when available;
3. otherwise the first available language;
4. otherwise the default (or first supported), so the selection is deterministic
   even when nothing can be played.

After an explicit choice, nothing re-derives it — not a refresh, not a typed
error, not an app restart.

## Device evidence

Xiaomi `25010PN30G`, Android 16, arm64-v8a, device `2ba15772`, debug build,
app data cleared first. Screenshots in the session scratchpad under `shots/lang/`.

| # | What it shows |
|---|---|
| 02 | Fresh install, **Arabic UI** — English auto-selected because Arabic is unavailable; both options visible; Arabic marked; only English's playable category listed |
| 03 | Arabic explicitly selected — stays selected, contract copy verbatim, "اختيار English" + retry, Play disabled *with* its reason |
| 04 | After a full restart — still Arabic. Never auto-switched |
| 06 | "اختيار English" → Start → a real English game |

Scenario C (`NO_PLAYABLE_SECRETS_FOR_CATEGORY`) is covered by widget tests rather
than on-device: the client only ever offers categories the catalogue marks
playable, so the error cannot be provoked through the UI without tampering. The
handling exists for the case where the server's category list and its secrets
disagree.

## Tests

- `test/unit/language_availability_test.dart` — 18 contract tests over the
  **real** captured bodies: v1 parsing, pre-contract fallback, unknown states,
  cache round-trip, every selection rule, and each typed failure.
- `test/design/language_availability_ui_test.dart` — 16 widget tests: scenarios
  A–D, both-unavailable, duplicate-tap prevention, explicit-language submission,
  untyped-failure recovery, cache resilience, RTL/LTR.
