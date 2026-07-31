# Language Availability Contract v1 — deployment status

Probed live against `https://siyak-api.aljoodnet.info/api/v1` on 2026-07-31.
Mobile implementation is **paused** until the gaps below close, so the client is
not written against a shape that is about to change.

## Summary

| Contract surface | Status |
|---|---|
| `GET /game/languages` returns the v1 body | ✗ still pre-contract |
| Per-language availability + state, somewhere | ✓ in `GET /capabilities` |
| `NO_ACTIVE_RELEASE` typed error | ✓ live |
| `NO_PLAYABLE_SECRETS_FOR_CATEGORY` typed error | ✓ live |
| `LANGUAGE_REQUIRED` typed error | ✗ falls back to `VALIDATION_ERROR` |
| Omitted language never defaults to Arabic | ✓ satisfied |

## 1. `GET /game/languages` — the one real gap

Returned today:

```json
{"languages":[
  {"code":"ar","name":"Arabic","native_name":"العربية","dir":"rtl","ready":false},
  {"code":"en","name":"English","native_name":"English","dir":"ltr","ready":true}
]}
```

Missing versus the contract: `contract_version`, `default_language`, and per
language `supported`, `available`, `state`, `message_key`, `active_release`,
`categories.available_count`.

Only `ready` carries availability. A client can map `ready → available`, but
**not** `state` — and `state` is what decides whether the UI may say "no active
word release" rather than a vague "unavailable". Inferring the reason from
`ready:false` would be inventing it.

`dir` and `native_name` are extras the contract does not list; keeping them is
useful — please don't drop them, the selector renders `native_name`.

## 2. Availability already exists — in `/capabilities`

`capabilities_contract.languages.<code>` is already contract-shaped:

```json
"ar": {"available": false, "state": "NO_ACTIVE_RELEASE",
       "release_unavailable_reason": "NO_ACTIVE_RELEASE",
       "active_release": null, "release_components": []},
"en": {"available": true,  "state": "ACTIVE_MANAGED-equivalent",
       "release_id": "siyak-en-reference-v1-candidate-1",
       "active_release": {"release_id": "...", "ranking_mode": "precomputed_neighbors",
                          "word_count": 20000, "secret_count": 829,
                          "runtime_loaded": true}}
```

`active_release` matches the contract field-for-field. So the availability
service exists; `/game/languages` simply is not reading from it yet. That is
exactly the "must derive from the same language-availability service" clause.

**Note:** the disagreement documented in `v2_capabilities.dart` — capabilities
reporting `en` as `NO_ACTIVE_RELEASE` while `/game/languages` marked it ready —
is **resolved**. Both now agree (`ar` unavailable, `en` available), and
`POST /game/new-game` behaves consistently with both. The stale warning comment
in that file should come out when the client work resumes.

## 3. Typed errors — two of three live

`POST /game/new-game`, no auth header needed to reproduce:

```
{"language":"ar","category":"general"}  → 503
{"error":"release_unavailable","code":"NO_ACTIVE_RELEASE","language":"ar","retryable":true}

{"language":"en","category":"animals"}  → 409
{"error":"no_playable_secrets_for_category","code":"NO_PLAYABLE_SECRETS_FOR_CATEGORY",
 "details":{"language":"en","category":"animals","retryable":false,
            "remedy":"choose_another_category"}}

{"category":"general"}                  → 422 VALIDATION_ERROR (field required)
{"language":"en","category":"zzz"}      → 400 VALIDATION_ERROR (unknown category)
```

The two availability errors are correctly typed and correctly *distinct*, which
is contract rule 8. Two smaller gaps:

- **`LANGUAGE_REQUIRED` is not implemented.** Omitting `language` yields a
  generic `VALIDATION_ERROR`. This *does* satisfy the important half of the rule
  — it does not silently fall back to Arabic — but a client cannot tell this
  case apart from any other validation failure.
- **`message_key` and `available_languages` / `available_categories` are absent**
  from both error bodies. Without `available_languages`, the "Choose English"
  action has to be derived from the language catalogue rather than from the
  error itself. Workable, but it is contract text that isn't shipped.

## 4. Current production state (for reference, not to be hard-coded)

- `ar`: no active release; all 7 categories `playable: false`, `word_count: 0`.
- `en`: `siyak-en-reference-v1-candidate-1`; only `general` playable
  (20 000 words / 829 secrets), the other 6 categories empty.

So both acceptance scenarios A and C are reproducible against production right
now: Arabic is the unavailable-language case, and English + `animals` is the
empty-category case.

## What the client will do once `/game/languages` ships v1

Read the v1 body as the single source of truth, keep `ready` as a fallback for
older servers, and treat `available` as readiness with `state` as the reason.
Until then the selector fix shipped in `fix/translation-live-alignment` keeps
both languages reachable, which was the user-visible dead end.
