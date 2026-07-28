# Gameplay Translation Assistant — Required Backend Contract

**Status: NOT implemented server-side.** The mobile client ships the complete
assistant UX (detection → candidates → explicit pick → normal server-validated
submit) behind a capability gate. In release builds the feature is invisible
until the backend provides the pieces below; debug builds exercise the flow
with a deterministic fixture adapter (`DevTranslationAdapter`, `dev-fixture`
source tag) that is never a production translator.

## Why

The player locks one gameplay language per session but may think or type in
another. Example: game language English, player types `سيارة` → the client
offers `car / vehicle / automobile`; the player picks one; only the picked
English word is submitted through the existing guess endpoint, which validates
it against the vocabulary as usual. **Scoring, ranking and validation are
untouched** — translation is strictly an input aid.

## 1. Capability flag

Add to `GET /api/v1/capabilities` → `features`:

```json
{ "features": { "translation": true } }
```

Client mapping already exists (`V2Capabilities.translationEnabled`,
fail-closed: absent/non-`true` ⇒ disabled).

## 2. Endpoint

```
POST /api/v1/translate
X-Installation-ID: <uuid>            (same auth model as the game endpoints)

{ "text": "سيارة", "from": "ar", "to": "en" }
```

Response `200`:

```json
{
  "candidates": [
    { "word": "car" },
    { "word": "vehicle" },
    { "word": "automobile" }
  ]
}
```

Notes for the implementer:

- `candidates` ordered best-first, ≤ 6 entries; empty array is a valid answer
  ("no suggestion") and the client renders it as such.
- Candidates SHOULD be filtered against the target vocabulary server-side so
  the player is not offered a word the guess endpoint will then reject —
  the client tolerates it either way, since the pick still flows through the
  normal validation.
- Language pairs: `ar↔en` first; the request shape is already pair-agnostic.
- Rate limiting: the client requests at most once per settled input word, but
  standard per-installation limits should apply.
- Error contract: normal error envelope; the client fails soft (assist simply
  doesn't appear).

## 3. Client plug-in point

`lib/features/game/domain/translation/translation_service.dart` — implement
`TranslationService` with a remote adapter and return it from
`translationServiceProvider`
(`lib/features/game/presentation/widgets/translation_assist.dart`) when
`translationEnabled` is true. No other client change is needed.

## Explicit non-goals

- No client-side calls to public translation APIs (key exposure, unreviewed
  content) — the service must be first-party.
- No secret material in the app; auth rides the existing installation header.
- No auto-submit of a candidate under any circumstances.
