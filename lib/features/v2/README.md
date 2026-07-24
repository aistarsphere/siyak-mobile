# Context Game API V2 — client layer (contract-independent scaffolding)

> Status: **BACKEND_V2_CONTRACT_PENDING / LIVE_V2_INTEGRATION_PENDING**
>
> The V2 backend and its documentation (`docs/api-v2/*`, `/v2/capabilities`,
> a V2 OpenAPI) do not exist yet. Everything here is built **without inventing
> request/response schemas**: the presentation and domain layers depend only on
> the abstract interfaces in `domain/repositories/` and the domain entities in
> `domain/entities/`. The only placeholder code lives under `data/mock/`.

## The swap boundary

```
presentation/  ─┐
domain/entities ─┼─ depend ONLY on ─►  domain/repositories/ (abstract)
controllers/    ─┘                              ▲
                                                │  implemented by
                              data/mock/  (now)  │  data/remote/ (later)
                              deterministic      │  generated V2 OpenAPI client
                              fixtures           │  / hand-written DTO mappers
```

When the real V2 contract lands:
1. Generate/write DTOs + mappers under `data/remote/` that implement the SAME
   `domain/repositories/` interfaces and return the SAME domain entities.
2. Flip the provider overrides in `presentation/controllers/v2_providers.dart`
   from the mock implementations to the remote ones.
3. **No change** to any screen, controller, or domain entity is required.

## Placeholder assumptions (to reconcile against the real contract)

These are UI/behaviour assumptions only — NOT frozen schemas:
- Capability detection is `GET <CG_V2_BASE>/capabilities` returning at least an
  availability flag + per-feature flags.
- Installation identity is sent via header `X-Installation-ID: <uuid v4>`.
- A guess response distinguishes accepted / duplicate(canonical) / unknown, and
  carries a canonical word, rank, and heat (mirrors V1 semantics).
- Realtime delivers ordered events with a stable `id` and monotonic `seq`; a
  REST room snapshot is the recovery source of truth after a gap/reconnect.
- `best_user_generated_rank` drives adaptive hints; hint ranks 1–3 are never
  surfaced as adaptive hints.

All of the above are encoded as domain entities + mock behaviour and are
trivially remappable once `docs/api-v2/openapi.json` is available.
