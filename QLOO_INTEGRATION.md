# Qloo in Valora Nebius

One Flutter app, Google session, Worker and D1 database. Nebius remains the inference provider. Qloo functionality adapted from Valora Qloo commit `6bcd8e0aad6b15e2fa3c0a9d388aad4deb049a29`; that repository and deployment were not modified.

## Data flow

Saved public tastes plus allowlisted onboarding cuisines → one Qloo cuisine Insights lookup → restriction-checked recipe ranking → Nemotron structured selection → existing first-day plan or confirmed single-meal change. Actual returned affinities and explicitly selected cuisine inputs are separate. Evidence enters the model context and is stored in the plan and each meal; unchanged meals retain their evidence after a swap. Ordered tastes and an integration marker participate in fingerprints, invalidating stale results and proposals.

Qloo receives only public entity/tag IDs and applicable search location. Account identifiers, health notes, allergies, exclusions and raw conversation are excluded. Temporary cuisine requests project an allowlisted tag without saving a new preference. Saved diet, food restrictions, cooking limits, cuisine preferences, comfort style and supported staple facts constrain candidates before taste ranking. Existing catalog IDs remain valid; four original Qloo-variant staple preparations were added with source/license metadata. This is not a clinical suitability system.

## Discover

The fifth app tab shares BackendApi and the current bearer token. Search supports cuisine, restaurant, artist and movie, with explicit match selection and confirmed taste saving (maximum ten). Confirmed saves refresh main meal personalization. Routes: POST `/v1/qloo/search`, GET/PUT `/v1/qloo/tastes`, POST `/v1/qloo/recommend`. Resolved IDs are account-owned and expire after 30 days. Counters are atomic: discovery 20/minute, recommendations 6/minute, model-related endpoints 6/minute.

Discover returns up to three Mumbai venue leads and three home recipes. Supported cuisine mapping is Indian, Italian and Chinese. Venue price categories are ordinal, never INR prices; ingredients, availability, dietary suitability and allergen safety remain unverified. Discover's separate preparation catalog withholds home recipes whenever saved allergies/exclusions are present; the main planner continues using its restriction-checked catalog. Client controls cannot bypass this server hold. No ordering or Swiggy integration. Milder/softer/quicker refinements use consented Nemotron and only narrow preparation constraints.

## Operations

`QLOO_API_KEY` is a Worker secret. Add it to ignored `backend/.dev.vars` for local work; never bundle it in Flutter. `QLOO_API_URL` allows only https://hackathon.api.qloo.com or https://api.qloo.com. `QLOO_ENABLED=true` enables taste analysis in main planning/chat; false is an explicit operator rollback to the existing Nebius path, with no false Qloo attribution. Discover routes remain available independently. Never automatically fall back after a Qloo failure. Users without a usable public seed must select/save tastes in Discover. Unmapped affinities return a specific error.

From backend, run `npm run check:deployment` before remote commands. Migration `0006_qloo_tastes.sql` adds only taste, resolved-ID and rate tables; no auth migration or Qloo user copying. Deploy with `npm run db:migrate:remote` and `npm run deploy`. Upload only the Qloo key using `npx wrangler secret put QLOO_API_KEY`; do not bulk-upload development variables. Existing Nebius signing, model, OAuth, API URL and database bindings remain unchanged. Never retire the old Qloo deployment until unified-device acceptance is complete.

## Verification

See the latest entry in NEBIUS_VALIDATION.md for executed local checks, live synthetic journeys and device limitations. Web compilation does not establish a browser OAuth journey; Android is the submission target. Keep the prior signed APK and Worker version available for rollback.
