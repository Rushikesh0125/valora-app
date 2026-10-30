# Qloo in Valora Nebius

One Flutter app, Google session, Worker and D1 database. Nebius remains the inference provider. Qloo functionality adapted from Valora Qloo commit `6bcd8e0aad6b15e2fa3c0a9d388aad4deb049a29`; that repository and deployment were not modified.

## Data flow

Saved public tastes plus allowlisted onboarding cuisines → one Qloo cuisine Insights lookup → restriction-checked recipe ranking → Nemotron structured selection → existing first-day plan or confirmed single-meal change. Actual returned affinities and explicitly selected cuisine inputs are separate. Evidence enters the model context and is stored in the plan and each meal; unchanged meals retain their evidence after a swap. Ordered tastes and an integration marker participate in fingerprints, invalidating stale results and proposals.

Qloo receives only public entity/tag IDs and applicable search location. Account identifiers, health notes, allergies, exclusions and raw conversation are excluded. Temporary cuisine requests project an allowlisted tag without saving a new preference. Saved diet, food restrictions, cooking limits, cuisine preferences, comfort style and supported staple facts constrain candidates before taste ranking. Existing catalog IDs remain valid; four original Qloo-variant staple preparations were added with source/license metadata. This is not a clinical suitability system.

## Preference lookup and user experience

Cuisine autocomplete lives in onboarding and profile preferences, with debounced, account-authenticated lookup, explicit chip selection and local supported options during lookup failure. The four main tabs remain Chat, Plan, Insights and You. No separate Discover setup is required. Account-resolved cuisine IDs are projected from saved cuisine labels; old Discover taste selections no longer affect main planning. When no usable cuisine signal exists, no taste request is made and the existing restriction-checked Nebius flow operates without Qloo attribution. Actual upstream failures are still surfaced, not silently substituted. Firm preferences remain authoritative when related cuisines do not map to eligible recipes.

Only supported catalog cuisine labels are selectable from live suggestions. Custom cuisine text remains possible, but cannot invent catalog recipes. Local allergy autocomplete combines supported allergens and food aliases (including paneer → milk and chicken). Live capability probes returned dish, venue and dietary-option tags for milk/peanut/chicken rather than a dependable ingredient/allergen dictionary, so these tags are not used to create allergy values or establish suitability. No saved allergy fields are sent upstream for lookup.

User-facing workflow labels say meal assistant, cuisine suggestions and cloud AI. Provider names appear only in small attribution. Android launcher label is Valora; package ID, signing, callback and API URL are unchanged. Legacy authenticated discovery routes remain available for compatibility but have no app page; their conservative screening and unknown-price behavior are unchanged.

## Operations

`QLOO_API_KEY` is a Worker secret. Add it to ignored `backend/.dev.vars` for local work; never bundle it in Flutter. `QLOO_API_URL` allows only https://hackathon.api.qloo.com or https://api.qloo.com. `QLOO_ENABLED=true` enables taste analysis in main planning/chat; false is an explicit operator rollback to the existing Nebius path, with no false Qloo attribution. Discover routes remain available independently. Never automatically fall back after a Qloo failure. No separate public-taste setup is required; saved cuisine preferences are the source of main personalization. Unmapped affinities return a specific error.

From backend, run `npm run check:deployment` before remote commands. Migration `0006_qloo_tastes.sql` adds only taste, resolved-ID and rate tables; no auth migration or Qloo user copying. Deploy with `npm run db:migrate:remote` and `npm run deploy`. Upload only the Qloo key using `npx wrangler secret put QLOO_API_KEY`; do not bulk-upload development variables. Existing Nebius signing, model, OAuth, API URL and database bindings remain unchanged. Never retire the old Qloo deployment until unified-device acceptance is complete.

## Verification

See the latest entry in NEBIUS_VALIDATION.md for executed local checks, live synthetic journeys and device limitations. Web compilation does not establish a browser OAuth journey; Android is the submission target. Keep the prior signed APK and Worker version available for rollback.
