# Auth Foundation — real backend contract (audited live)

Source: live OpenAPI `https://siyak-api.aljoodnet.info/api/context-game/v2/openapi.json`
+ live probes (2026-07-25). `contract_version: 2026-07`. Providers: `google`, `apple`
(facebook exists server-side but is out of scope). Session = one opaque
`Authorization: Bearer <session_token>`; **`/auth/refresh` rotates it**.

## Installations (guest lifecycle)
- `POST /installations/register` — body `{installation_id*, platform?, app_version?, build_number?, locale?, timezone?, notification_permission?}`
  → `{installation_id (inst_…), platform, app_version, build_number, locale, timezone, notification_permission, attached:bool, created_at, last_seen_at}`
- `GET  /installations/current?installation_id=<uuid>` (installation_id is a **query param**)
- `POST /installations/heartbeat` — `{installation_id*}` → `{installation_id, last_seen_at}`
- `POST /installations/attach` — `{installation_id*}` (bearer) — attach guest install to account
- `POST /installations/detach` — `{installation_id*}` (bearer)
- `POST /installations/push/register` — `{installation_id*, platform*, token*}` → `{installation_id, platform, token_fingerprint}`
- `POST /installations/push/invalidate` — `{installation_id*, platform*}`

## Auth
- `POST /auth/google` — `{id_token*, installation_id?, device_label?}` → SignInResult
- `POST /auth/apple`  — `{identity_token*, authorization_code?, given_name?, family_name?, installation_id?, device_label?}` → SignInResult
- `POST /auth/refresh` — no body (bearer) → rotated `{session_token, …}`
- `GET  /auth/session` — bearer → `{authenticated, account}` (liveness check)
- `POST /auth/logout` / `POST /auth/logout-all` — bearer
- `POST /auth/migrate-guest` — `{installation_id}` (bearer)
- `GET  /auth/sessions` · `DELETE /auth/sessions/{id}`
- SignInResult (from working google impl): `{session_token, account{public_player_id, display_name, avatar_url, status, linked_providers[], created_at, last_active_at}, created, suggested_display_name?, suggested_avatar_url?}`

## Account
- `GET /account/me` (bearer) → account DTO (above)
- `GET /account/profile` (bearer) → extended profile
- `GET /account/identities` · `POST /account/identities/{provider}/link` · `DELETE /account/identities/{provider}`

## Error envelope
`{"error":{"code","message","details","request_id"},"api_version","contract_version"}`
Codes to handle: AUTHENTICATION_REQUIRED, SESSION_EXPIRED, SESSION_REVOKED,
REAUTHENTICATION_REQUIRED, ACCOUNT_SUSPENDED, ACCOUNT_BANNED,
ACCOUNT_VERIFICATION_REQUIRED, ACCOUNT_DELETION_PENDING, ACCOUNT_DELETED,
AUTH_PROVIDER_DISABLED, AUTH_TOKEN_INVALID, INVALID_INSTALLATION_TOKEN,
VALIDATION_ERROR, RATE_LIMITED.

## Notes
- Client keeps its own UUID as `X-Installation-ID` and as `installation_id` in bodies;
  the server maps it to a canonical `inst_…` id (returned for reference).
- `/auth/refresh` rotation → needs a single-flight coordinator so concurrent 401s
  trigger exactly one rotation; queued requests retry once with the new token.
