> Current integration update — 30 October 2026: Qloo public taste intelligence is now integrated into this app and backend, including main Nebius planning/chat and Discover. See QLOO_INTEGRATION.md and the latest NEBIUS_VALIDATION.md entry. Earlier dated entries below are historical.

# Valora Nebius submission

## First-day planning update — 26 October 2026

Onboarding now offers explicit consent to use confirmed food preferences for the
remaining meals today. Generation starts after the profile is saved; the first
plan appears on the home screen and Plan tab and is restored on later logins.
Existing users can opt in from the first-day plan card. Older chat consent alone
does not grant permission to send saved food preferences for this feature.

The planner uses a versioned starter recipe catalog and Nebius strict structured
output, followed by deterministic diet, cooking-time and meal-slot validation.
Cuisine and budget guide selection; prices and nutrition are not verified.
Allergy, exclusion, health and paused-safety holds remain in place. No example
plan is substituted when generation is blocked or fails.

Target: under five minutes while connected with the app open. Provider calls are
bounded, retries stop after three attempts, and interrupted leases can resume.
Generation is not guaranteed to continue while the app is closed. After 22:00,
the app reports that no meals remain instead of silently planning tomorrow.
Changed preferences hide an outdated plan until review and explicit regeneration.

Migration 0004 is applied to local and independent production D1. Deployed Worker
version: f063aa98-b9da-4866-8d2e-8dec2a375de4. Live synthetic verification completed
a dinner plan in 3417 ms and all three morning meal slots in 4129 ms. Reloading
returned the same saved plan. These operator-signed checks do not verify Google
sign-in or device onboarding. Synthetic accounts were removed after testing.

The signed APK was rebuilt and its signature verified. Backend tests: 53 passed;
Flutter analysis: passed; Flutter tests: 46 passed and the same known baseline UI
failure remains. See NEBIUS_VALIDATION.md.

Source baseline: https://github.com/Rushikesh0125/valora at commit 6c3645d.
Variant: https://github.com/Rushikesh0125/valora-nebius.
Implementation date: 25 October 2026. Track: Best Apps and Agents.
Deadline: 30 October 2026, 10:30 PM IST.

## Current implementation

Flutter routes AI conversations through the authenticated Worker to NVIDIA
Nemotron via Nebius Token Factory after stored cloud consent. Deterministic
saved-state questions and confirmation-based preference edits use their existing
paths. No AI tools, checkout, verified nutrition or clinical interpretation were added.

The dedicated adapter uses non-streaming Chat Completions, a 40-second timeout,
bounded output parsing and sanitized errors. The model is
nvidia/nemotron-3-super-120b-a12b for routine and complex requests. Replies display
both provider and model. Context remains bounded and food-preference sharing is
optional; saved health fields are excluded from automatic context.

Real Nemotron inference is verified through the local Worker using the configured
key. Local consent refusal and revocation both return HTTP 403.
Production Worker deployed on 25 October 2026. The shared Valora Google client
and Nebius credentials are configured. OAuth start opens Google sign-in; full
Google authentication and on-device verification remain pending.

## Isolated resources

- Worker name: valora-nebius-api; expected URL:
  https://valora-nebius-api.jadhav-rushikesh-ggl.workers.dev
- D1: valora-nebius-db, ID 56e7e18f-f37c-4fa4-a2c2-07cadc12bd67.
  Created independently; migrations 0001–0003 applied remotely on 25 October.
- Android application ID: com.valora.nebius. Callback: valoranebius://auth/callback.
- Android signing: independent ignored android/nebius-release.jks and
  android/key.properties were generated locally. Preserve both securely for updates.
- Local development settings: backend/.dev.vars is ignored and contains an
  independent LOCAL auth signing key. It now contains the supplied Nebius key, stored locally only.
- Canonical Worker and database were not used. The user explicitly authorized
  sharing Google OAuth credentials on 25 October; all other secrets stay separate.

## Finish configuration and deploy

1. Add NEBIUS_API_KEY to ignored backend/.dev.vars for local work. Never put it in
   Flutter, tracked config, Git or chat. Copy backend/.dev.vars.example on another
   machine; generate a local auth key with the existing auth-key script.
2. Reuse the main Valora Google Web OAuth client, as explicitly requested.
   GOOGLE_CLIENT_ID is configured. Add this URI to that client without removing
   the canonical Valora callback:
   https://valora-nebius-api.jadhav-rushikesh-ggl.workers.dev/v1/auth/google/callback
   Configure Google's consent screen for external judge access. Supply a new
   GOOGLE_CLIENT_SECRET as a Worker secret using the same Google client secret.
   Cloudflare secret values cannot be read back; obtain the original from the
   Google client configuration or your original credential backup.
3. From backend, run npm ci, npm run typecheck, npm test and
   npm run check:deployment. The deployment check validates the
   OAuth client ID and rejects canonical database IDs and callback settings.
4. Generate a NEW production signing JWK using scripts/generate-auth-key.mjs.
   Transfer its output directly to wrangler secret put AUTH_SIGNING_PRIVATE_JWK;
   do not reuse the local development signing key. Set Worker secrets with:
   npx wrangler secret put GOOGLE_CLIENT_SECRET
   npx wrangler secret put NEBIUS_API_KEY
   These commands target only the Worker named in this variant's config.
5. Run npm run deploy. Do not bulk-upload .dev.vars: it contains development
   settings. Keep DEV_AUTH_ENABLED absent in production.
6. In mobile, run flutter pub get, flutter analyze and flutter test. Build with
   flutter build apk --release. On Windows with plugin sources and build outputs
   on different drives, use the build-only options:
   flutter build apk --release -P kotlin.incremental=false -P kotlin.compiler.execution.strategy=in-process
   These flags affect compiler execution/caching, not type checking.
7. If the workers.dev hostname changes, update JWT_ISSUER, GOOGLE_CALLBACK_URL,
   Google's registered callback and the Flutter VALORA_API_URL build define together.

## Judge setup and real verification

Install the release APK on Android 11 or newer, open Valora Nebius, sign in with
Google, complete onboarding and enable Nebius cloud consent in AI settings.
No local model download or personal health documents are needed.

Use synthetic preferences and confirm this journey on a real device:

1. Save vegetarian preferences, a cooking-time limit and a weekly budget.
2. Enable Include food preferences, request a lunch idea, then ask for a quicker
   substitution. Verify the reply identifies NVIDIA Nemotron via Nebius and its model.
3. Ask to change a supported preference, review the proposed change and confirm.
4. Restart and verify persistence. Sign out and sign in as another account to
   check isolation. Disable cloud consent and verify no new inference is sent.
5. Test retry after an unavailable provider; the user turn must remain singular.

For a repeatable deployed synthetic inference check, set VALORA_API_URL and
VALORA_ACCESS_TOKEN for a signed-in test account with existing consent, then run
npm run verify:live in backend. It logs provider, model, duration and usage only.
It never enables consent, logs tokens or prints conversation content.

## Submission and operations checklist

- Read THIRD_PARTY_NOTICES.md. Public release is pending permission/provenance
  review for reference screenshots and landing images, including Git history.
- MIT license is added for original source; third-party licenses remain separate.
- After asset and secret review, publish source and upload a public YouTube demo
  under three minutes. Use NEBIUS_DEMO_SCRIPT.md; do not claim unverified success.
- Include working APK download, Google sign-in instructions, source provenance,
  significant changes and actual technology feedback in Devpost.
- Verify participant eligibility and public links before final submission.
- Keep judge access free through 15 December 2026. Check /health for Worker
  reachability; it does not prove inference or OAuth health. Use the signed-in
  synthetic check for end-to-end health. Review Nebius credits and expiration in
  Token Factory and replenish credits before exhaustion. No monitor is configured.
- On failures, inspect only sanitized error codes. Never log prompts, bearer
  tokens, OAuth codes, signing keys or raw provider payloads.

## Verification record

Backend type checking and all 31 tests pass. Worker bundling dry run passes with
only the Nebius database binding. Targeted Flutter chat/auth tests pass; Flutter
analysis passes. Full-suite and APK results are recorded in NEBIUS_VALIDATION.md.
Local Worker → Nebius inference passed (HTTP 200, about 3.2 seconds).
Deployed inference, OAuth, judge access and device verification remain pending. Current technology feedback is limited to implementation experience:
OpenAI-compatible Chat Completions required a separate adapter because Valora's
OpenAI provider uses Responses. One local Worker request completed in about 3.2 seconds (186 input tokens,
385 output tokens). This is a smoke check, not a quality or performance benchmark.

## 29 October — personalized meal-agent update
Saved profile restrictions now govern both chat suggestions and persisted plans. Added supported allergen/exclusion filtering, cuisine matching, grounded catalog replies, Markdown rendering, confirmation-based single-meal proposals, foreground daily renewal and two per-meal fulfillment choices. Onboarding with explicit consent opens Plan and starts generation after save. Added four cited published-study records with applicability limits; clinical diets/activity prescriptions remain unavailable. Swiggy is still not connected; fulfillment screens disclose the missing provider rather than simulating orders. See KNOWLEDGE_LAYER.md and the latest validation record.
