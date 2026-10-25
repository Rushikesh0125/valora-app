# Authentication issuer implementation plan

## Scope

The Worker implements a Google-only Valora identity broker. It starts Google OAuth, validates the provider response, creates or resolves the local user, and issues a Valora API access token. ChatGPT identity sign-in is disabled while access is invite-only. This does not replace the existing API's profile, preferences, and memory routes.

## Source-to-target mappings

| Current state | Target |
| --- | --- |
| API validates externally-issued JWTs via `JWT_ISSUER`, `JWT_AUDIENCE`, `JWT_JWKS_URL` | The same Worker signs Valora JWTs and publishes the corresponding public JWKS |
| No production auth endpoints | Public provider-start, provider-callback, one-time app-code exchange, refresh, and logout endpoints |
| User table keyed by provider + subject | Keep this account identity invariant and keep roles sourced from the database |
| Mobile token retrieval used to be a placeholder | Flutter now launches Google OAuth, handles `valora://auth/callback`, exchanges one-use codes, and stores/rotates tokens using secure storage |

## Architecture and invariants

- Store OAuth state, PKCE verifier, nonce, callback URI, and expiry in D1. Consume an auth transaction once before processing the provider response.
- Use fixed, configured HTTPS provider callback URIs and fixed configured mobile return URI. Do not accept arbitrary return URLs.
- Verify provider ID-token signature, issuer, audience, expiry, nonce, and subject before issuing a Valora token. Treat email as a profile claim, never as an account-linking key.
- Sign Valora access JWTs with an ES256 private JWK stored as a Worker secret; publish only its public key. Use the configured issuer, fixed `valora-api` audience, and `identity_provider` plus provider `sub` claims.
- Exchange a high-entropy, one-use app code for access/refresh tokens. Store only the app-code hash and refresh-token hash. Rotate refresh tokens on use and revoke on logout.
- Keep all auth routes public but narrowly route/method allowlisted. Existing `/v1` data routes remain protected by Valora JWT verification.

## Known semantic / integration requirements

- Google requires OAuth client registration with the exact Worker callback URL and a server-side client secret for the selected web-server flow.
- Google Web OAuth requires the exact Worker callback URL and server-side client secret. The Web client ID and callback are deployed; the secret still needs to be added to Cloudflare.
- Flutter's Android and iOS URI handlers are configured for `valora://auth/callback`. The active Google start route cannot succeed until the Cloudflare `GOOGLE_CLIENT_SECRET` is set.

## Validation strategy

- Run backend TypeScript type checking, Flutter analysis, and Android debug compilation.
- Review the auth routes, token claim mapping, database one-time-use behavior, and deployment documentation independently after implementation.
- Google provider sign-in remains unverified until its client secret is configured and a real sign-in completes.
