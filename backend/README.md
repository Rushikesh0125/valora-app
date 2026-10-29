# Valora API

Cloudflare Worker API for persistent, authenticated user data and consent-gated cloud AI.

## Current endpoints

Data routes require a Bearer token (or a configured development identity for local direct API requests). Auth start/callback/exchange/refresh/logout use their own public OAuth/session contracts:

- `GET` / `PUT` `/v1/profile`
- `GET` / `PUT` `/v1/preferences`
- `GET` / `PUT` `/v1/food-state`
- `GET` / `POST` `/v1/memory`
- `PATCH` / `DELETE` `/v1/memory/:id`
- `GET` / `PUT` `/v1/ai/consent`
- `POST` `/v1/ai/respond`
- `POST` `/v1/auth/google/start` and `GET` `/v1/auth/google/callback`
- `POST` `/v1/auth/exchange`, `/v1/auth/refresh`, and `/v1/auth/logout`
- `GET` `/.well-known/jwks.json`
- `GET` `/health`

All user records are scoped to the identity resolved by the server. The API sends `Cache-Control: no-store`, validates JSON bodies, and rejects unconfigured production authentication. Do not enable `DEV_AUTH_ENABLED` in a deployed environment.

## Food records

Migration `0003_food_state.sql` adds an account-owned JSON aggregate for pantry, confirmed meal logs and the five-day example draft. `GET /v1/food-state` returns `{data:{version,state,updatedAt}}`; a new account has version 0 and null state. `PUT` accepts `{expectedVersion,mutationId,state}` and returns the committed version. Mutation IDs are 32 lowercase hexadecimal characters. Repeat the same ID and identical state after a lost response; stale versions return `409 food_state_conflict` instead of overwriting newer records.

State schema version 1 contains `pantry` (id, name, amount, kind), `intake` (name, portion, UTC/offset ISO timestamp, nullable sourceName and remaining), and `plan` (recipeSet `example-v1`, YYYY-MM-DD startDate, exactly five days with breakfast/lunch/dinner slots). Slots contain option 0–4, servings 1–4 and removed. Pantry IDs are unique positive 32-bit integers scoped to the account. Bounds: 512 KiB per request, 500 pantry items, 5000 meal logs, 200 characters per text field. A log and its linked pantry correction commit in one statement. This preserves example plan edits; recipe generation, verified quantities and merchant quotes remain separate work.

Apply migrations before deploying the updated Worker. No new environment variables or secrets are required.

## Local setup

1. Install Node.js.
2. From `backend/`, run `npm install`.
3. Copy `.dev.vars.example` to `.dev.vars`. Set a local signing key if testing the JWKS/auth routes, and enter the selected cloud AI key if testing cloud AI.
4. Run `npm run db:migrate` to apply D1 migrations to the local SQLite database, then `npm run dev` from `backend/`.

PowerShell example for local development:

```powershell
npm run db:migrate
npm run dev
```

Place the chosen provider credential in `backend/.dev.vars` (for example `OPENAI_API_KEY=...` with `AI_DEFAULT_PROVIDER=openai`). `.dev.vars` is ignored by source control.

For the mobile app, run with `--dart-define=VALORA_API_URL=http://10.0.2.2:8787` on an Android emulator or `--dart-define=VALORA_API_URL=http://localhost:8787` on web/iOS simulator. Do not provide a token for local development: when `DEV_AUTH_ENABLED=true`, the local Worker accepts requests without a bearer token. Never enable this on deployment. The native app uses `GoogleSignInService` and platform secure storage for production token retrieval. The app itself requires sign-in; development identities support direct API requests. No provider key belongs in the mobile app.

The development identity is fixed by configuration and is not authentication. It is only for local endpoint development. Production sign-in is handled by this Worker: it validates Google identity tokens, creates Valora sessions, and publishes the matching signing key at `/.well-known/jwks.json`. ChatGPT identity sign-in is invite-only and is disabled in this API until access is available.

### Identity setup

The three JWT settings previously mentioned do not come from a third-party provider:

- `JWT_ISSUER` is the public origin of this Worker, such as `https://api.example.in`. Use the exact same value when configuring the Worker and when the API verifies Valora tokens.
- The audience is fixed by the backend to `valora-api`.
- The JWKS URL is derived automatically as `<JWT_ISSUER>/.well-known/jwks.json`.

Create a signing key once with `node scripts/generate-auth-key.mjs` from `backend/`. Keep the output private. For local development, put the full JSON value in `.dev.vars` as `AUTH_SIGNING_PRIVATE_JWK=...`. In Cloudflare, add it as a Worker secret with `wrangler secret put AUTH_SIGNING_PRIVATE_JWK`. The public key is served by the JWKS endpoint; the private key must never be sent to the app or committed.

For Google, the Worker is configured with the Web client ID and callback `https://valora-api.jadhav-rushikesh-ggl.workers.dev/v1/auth/google/callback`. Store the Web client secret as the Worker secret `GOOGLE_CLIENT_SECRET`. Local development can use `http://localhost:8787/v1/auth/google/callback` if the provider registration accepts the local callback; add a matching local client ID and secret to `.dev.vars`.

The mobile callback is `valora://auth/callback`. The app generates a cryptographically random `clientState`, sends it to `/v1/auth/google/start`, opens the returned authorization URL in the system browser, checks callback state, then exchanges the one-time code. Access and refresh tokens are kept in platform secure storage; refresh tokens rotate and can be revoked at `/v1/auth/logout`.

## Cloud deployment

The Worker is bound to the Cloudflare D1 database `valora-db`. Apply its schema with `npm run db:migrate:remote`. The production config sets `JWT_ISSUER`, the Google Web client ID and callback, and the mobile callback. Add `GOOGLE_CLIENT_SECRET` from the Google Cloud Console as a Worker secret (`npx wrangler secret put GOOGLE_CLIENT_SECRET`), then deploy with `npm run deploy`. The checked-in Worker environment defaults to production; development identity is read only from local `.dev.vars` and must never be uploaded as a secret or variable.

## Flutter client

`mobile/lib/core/backend_api.dart` is the typed HTTP boundary. Construct it with the production API base URL and a callback that retrieves the current Valora bearer token from secure session storage. Google sign-in UI, Android/iOS custom URI callbacks, secure token storage, and account-data loading/saving are connected. Universal/verified HTTPS app links and iOS device validation remain separate follow-ups.

`mobile/lib/core/ai_service.dart` currently runs in Gemma only test mode: all chat requests use Gemma 4 E2B on Android/iOS after explicit model download. The download is several gigabytes and is never started at launch. Chat does not call `/v1/ai/respond` in this mode. Set `localOnly: false` to restore consent-gated cloud fallback after device testing. The Profile screen provides model download controls.

The backend accepts one configured provider (`AI_DEFAULT_PROVIDER=openai|gemini`) and reads credentials from Worker secrets (`OPENAI_API_KEY` or `GEMINI_API_KEY`). Cloud prompts are sent to that provider for inference and are not stored by Valora. Model IDs can be changed using the `AI_OPENAI_*_MODEL` and `AI_GEMINI_*_MODEL` vars. Cloud AI consent defaults off. Provider billing is handled by the provider account; this backend does not track spend or impose a request-rate limit.

The app passes bounded recent successful conversation turns in the context field. Its optional food-preference switch attaches selected active food constraints and practical limits; health-context fields and arbitrary memory are not attached automatically. Context/history are treated as untrusted data. OpenAI requests set `store: false`; Valora does not persist prompts. Provider retention policies still apply. AI prompts prohibit diagnosis, treatment, nutrition calculations, allergen-safety claims, and order placement. Nutrition facts and clinical checks require separately approved structured data and deterministic logic.

## Deferred integrations

Report/document extraction and Swiggy are not connected. Their data must not be presented as live. Planning and transaction endpoints are not yet exposed by this initial persistence slice.

## Chat validation

Four backend provider-boundary tests verify server-side consent, OpenAI storage-disabled requests, Gemini context/instruction handling, and missing credentials without live provider calls. The mobile suite covers saved reads, context/history, fallback, retry, draft preservation and logout isolation. Current configured defaults remain as documented in source; recommending a model does not change deployment configuration automatically.

Selected cloud model: `gpt-6-luna` for both routine and complex requests, with reasoning effort `none` for the current conversational MVP. OpenAI credentials must be stored as the `OPENAI_API_KEY` Worker secret.
