# Verification — 25 October 2026

## Latest feature verification — 26 October 2026

This update supersedes the older deployment and test totals below.

- Backend type checking passes; 53 tests pass across five files, including 21
  first-day lifecycle/constraint tests using the actual migration in SQLite.
- Flutter analysis passes; eight new onboarding/planner tests pass. Full suite:
  46 pass, one unchanged baseline app_flow_test.dart:104 failure.
- New migration 0004 was applied locally and to valora-nebius-db only.
- Worker version f063aa98-b9da-4866-8d2e-8dec2a375de4 is deployed. Model selection
  uses strict provider JSON Schema plus independent semantic validation.
- Live remaining-meals plan: ready in 3417 ms, Asia/Kolkata, vegan dinner recipe
  with ten-minute cooking time. Live morning test: ready in 4129 ms, saved
  America/Los_Angeles timezone, breakfast/lunch/dinner, all vegan and within the
  saved 25-minute limit. Returning GET and repeated POST restored the saved plan.
- Missing cloud consent and unconfirmed preference-sharing both blocked new
  generation. The initial prompt-only live attempt failed validation and the
  retry recovered; strict structured output was added before final release and
  both final live scenarios passed. Invalid output was never shown as a plan.
- Synthetic test accounts and their first-day records were deleted after testing.
- Release APK rebuilt and signature verified. SHA-256:
  30778b15522826617335383f4920566532342a2edc1a57fa8f733f8499dad658.
- Independent pass reviewed account-scoped SQL, lease ownership, explicit sharing
  consent, stale preferences, server-side constraint checks and late response
  handling. It prompted fixes for first-plan-specific consent and retrying expired
  interrupted work; associated regression tests pass.

No Android device is connected. Actual Google sign-in, on-device onboarding and
restart verification remain pending. Five minutes is a foreground/network target;
no background completion guarantee or verified price/nutrition claim is made.

## Executed

Latest deployment: 85e4b0bf-50d8-4cfa-87df-5a878b9f757c at
https://valora-nebius-api.jadhav-rushikesh-ggl.workers.dev.
This production follow-up supersedes earlier pending-deployment notes below.
Health returns HTTP 200. Real Nemotron inference using an operator-signed
synthetic identity returned HTTP 200 in 5265 ms (186 input / 388 output tokens).
Consent-disabled and revoked calls returned HTTP 403. Synthetic account records
were removed from only the Nebius database after testing.

OAuth start returns HTTP 200; Google redirects to its sign-in page without a
reported redirect mismatch. Cancellation returns HTTP 302 to the Nebius app
scheme. The missed backend callback validator was fixed in both normal and
error paths. Three new regression tests cover OAuth start, cancellation and
rejection of the canonical app scheme. Shared Google credentials are configured
by explicit user request; the production signing key and database remain separate.
This does not verify a real Google user's token exchange or on-device sign-in.

| Check | Result |
| --- | --- |
| Backend TypeScript type checking | Passed |
| Backend Vitest suite | 31 passed across 4 files |
| Flutter analysis | Passed, no issues |
| Targeted chat/auth Flutter tests | 15 passed |
| Complete Flutter test suite | 38 passed, 1 baseline failure |
| Worker deployment dry run | Passed; only valora-nebius-db is bound |
| Deployment isolation guard | Passed with explicitly authorized shared Google client |
| New remote D1 database migrations | 0001, 0002 and 0003 applied successfully |
| Android release build | Passed with build-only Kotlin cache options below |
| APK signing verification | Passed, APK Signature Scheme v2, independent Valora Nebius RSA certificate |
| APK application ID / label / minimum SDK | com.valora.nebius / Valora Nebius / 30 (Android 11) |
| Connected Android devices | None |

Release artifact: mobile/build/app/outputs/flutter-apk/app-release.apk.
The APK targets the deployed production Worker. Full on-device Google sign-in
and restart persistence still need verification before judge access is published.

Windows Kotlin incremental caches failed for large_file_handler and
background_downloader because dependency sources and build outputs span drives.
Build succeeded using:

    flutter build apk --release --no-pub -P kotlin.incremental=false -P kotlin.compiler.execution.strategy=in-process

No linting, type checking, tests or dependency validation were disabled.

## Existing failing test

mobile/test/app_flow_test.dart:104, “custom chat hides workspace cards and saved
reads show a widget”, cannot find “What you have”. Reproduced by exporting the
unchanged HEAD baseline into a temporary directory, resolving its locked Flutter
dependencies and running that exact test. The test and associated unrelated UI
behavior were not altered to hide this failure.

The local-mode test fixture now explicitly opts into local-only behavior because
the variant's defaults intentionally changed to cloud. Its complex-request assertion
checks the existing local-only behavior: both complexities use the explicit local
mode and make no cloud requests. Nebius defaults are tested separately for both
complexities, no local calls and consent revocation.

## Independent review

Reviewed the diff, complete Nebius adapter, public request/response contracts,
consent boundary, metadata path, Android signing and deployment targets separately
from implementation. Confirmed no automatic provider fallback, no schema change,
no raw provider-error logging, and no canonical service binding. Generated Worker
types were regenerated with Wrangler rather than edited manually.

## Not verified or released

- Deployed Nebius inference, answer quality benchmarks, sustained latency, cost or remaining credit balance.
- Production Worker deployment, new Google OAuth credentials/consent publishing,
  Google sign-in and revocation against deployed services.
- On-device installation, restart persistence and cross-account isolation.
- iOS compilation or distribution.
- Third-party asset redistribution rights, public repository publication,
  YouTube recording/upload, Devpost submission and participant eligibility.
- Continued service availability through 15 December; no scheduled monitor exists.

These remain explicit release tasks, not completed verification claims.

Final release APK SHA-256: bd2e6391cf59419dc87da47f46d98d4dfcfb55a10f8f855583ec25cc782f9f8a

## Real inference follow-up

The supplied key was saved only in ignored backend/.dev.vars. A direct Token
Factory synthetic request returned HTTP 200 using
nvidia/nemotron-3-super-120b-a12b with finish_reason stop (about 8.4 seconds).

A local Wrangler Worker, local D1 and the actual app adapter then returned HTTP
200 with provider nebius and the configured NVIDIA model in about 3.2 seconds;
usage was 186 input tokens and 385 output tokens. Before consent and after
revocation, the same AI endpoint returned HTTP 403 cloud_ai_consent_required.
Consent was left disabled and the temporary local server was stopped. No
production deployment or Google sign-in was tested. Raw answers and secrets
were not printed. These synthetic requests incurred normal provider usage.

## Shared Google OAuth follow-up

By explicit user request, the canonical Google OAuth client ID is now configured
in Nebius production config and ignored local settings. The isolation guard permits
that reuse and retains the independent database and callback checks. The canonical
GOOGLE_CLIENT_SECRET exists as a Cloudflare encrypted Worker secret, but no local
copy was found. An available downloaded Google client JSON belongs to a different
client and was not used. The original matching secret and registration of the
Nebius HTTPS callback remain required; Google sign-in is not verified.
## Meal-agent validation — 29 October 2026

- Backend typecheck passed; 64 tests across six files passed. Flutter analysis passed; 50 tests passed before the final presentation-only source-label/onboarding-button changes, with the final suite run recorded below when completed.
- Migration 0005_meal_plan_proposals applied only to valora-nebius-db after target isolation checks. Worker deployed as version 9a24c576-ef8b-4d74-9155-af87aae5e00f.
- Synthetic operator-signed deployed test: saved vegan profile with milk allergy and onion exclusion, generated remaining lunch/dinner in 2,590 ms; grounded chat reply in 1,936 ms; Italian dinner proposal in 1,366 ms. GET proved no change before confirmation. Confirmation persisted the single dinner swap; reload restored it. Lunch remained unchanged. Research query returned knowledge/evidence-registry-v1 with the published source.
- Separate live restriction check adds wheat allergy, regenerates the safe Indian plan and requires clarification rather than offering wheat-containing Italian dishes. No real orders or payments tested.
- Independent review covered account-scoped proposal lookup, expiry, base-payload compare-and-swap, revoked consent, changed preferences, new-day renewal, model output validation, recipe allergen tags and raw health-field exclusion. Fixed stale daily-window handling, preserved source attribution for deterministic replies, and filtered explicit cuisine requests before inference.
- New-day meals regenerate on app open/resume with existing recorded consent, not through a background scheduler. The single-plan row stores the latest day, not a history archive.
- Known supported allergies and explicit exclusions are checked against fixed ingredient metadata. Unknown restrictions and unvalidated health constraints withhold meal suggestions. Packaged foods, substitutions and restaurant cross-contact are not verified by this catalog.
- Swiggy has no working adapter in this repository. Ingredient and dish actions expose the relevant list/review and clearly disclose ordering unavailable. Production delegated OAuth/provider onboarding remains required.
- Four published studies are stored with provenance/applicability limits in backend/src/evidence.ts, documented in KNOWLEDGE_LAYER.md. The app does not generate individualized clinical diets or exercise prescriptions. Age, baseline activity, mobility/injury and safety data are missing; research ingestion does not supply those user facts.
- Physical-device Google login, new onboarding and meal-change flow remain for the user to verify in the rebuilt APK. Synthetic backend tests are not device verification.
Final release verification: all 50 Flutter tests passed after the final changes; Flutter analysis passed. Release APK built in 64.8 seconds and signature verified. Artifact: mobile/build/app/outputs/flutter-apk/Valora-Nebius-Personal-Meals-2026-10-29.apk. Synthetic live wheat-allergy check passed (safe plan ready; Italian wheat-containing choices withheld), and the synthetic account plus cascading plan/proposal data were removed from the Nebius database. Canonical Valora remained clean.

## 29 October — saved-preference review-loop fix
User clarified this is everyday healthy-food support, not clinical diet planning. Removed the blanket hold for reported health context and paused health context; health details remain excluded from inference and ordinary suggestions do not claim condition-specific suitability. Allergens, explicit food exclusions and uninterpretable restrictions still constrain recipes. Saved preference changes now regenerate automatically; routine flow no longer requires re-reviewing the same profile. Added exact today-plan chat reads and server-owned current-plan context for conversational continuity.

Validation: backend typecheck and all 66 tests passed; Flutter analysis and all 51 tests passed. Independent review checked actual saved-plan reads, automatic refresh after preference save, preservation of allergy filtering and stale-response protection. Deployed version a7c18bea-e3db-40c6-ac19-932872c01151. Synthetic profile with reported health conditions plus milk allergy/onion exclusion produced a plan in 2,705 ms, a lunch reply in 2,337 ms and an Italian proposal in 1,303 ms. Confirmation and GET restoration passed; synthetic account and cascading rows deleted only from Nebius D1. No real-user prompts or health records inspected. Release build completed in 47.3 seconds and APK signature verified. Artifact: mobile/build/app/outputs/flutter-apk/Valora-Nebius-Saved-Preferences-2026-10-29.apk.

Swiggy documentation clarification: direct and delegated auth use dynamic client registration; no manually supplied client identity/secret is required. Delegated-auth documentation still specifies exact allowlisted redirect URIs and per-user OAuth PKCE, secure rotating tokens and scoped tool calls. Existing APK has no Swiggy adapter; automatic registration in compatible MCP clients is not an integration inside Flutter. Sources: https://mcp.swiggy.com/builders/docs/start/authenticate/ and https://mcp.swiggy.com/builders/docs/start/enterprise/delegated-auth/.

## 29 October — eggplant parsing and multi-item inputs
Reproduced the user's saved eggplant exclusion: it was missing from the known-food parser, causing a false restriction-clarification hold. Added eggplant/brinjal/aubergine and plural variants, trailing-punctuation normalization, exact no-restriction sentinel handling, and exclusion of stale hidden Other-allergy text after deselection. Unknown active allergens still fail closed; real allergens are not silently ignored. Added 10 backend regression cases. All 76 backend tests and typecheck passed. Guarded Worker deployment: 05657d66-658d-4bc4-ae76-21deaa929eb7.

Live synthetic eggplant profile: remaining-meal plan ready in 2,568 ms, grounded chat reply in 1,875 ms, dinner proposal in 1,311 ms; confirmation and restoration passed. Synthetic account and cascading rows were deleted from Nebius D1. Existing user data was not edited or enumerated.

Added reusable TagField for foods to avoid and Other allergies, cuisines, goals and health-context inputs. Existing string persistence stays compatible: existing lists load as removable chips, Add/Enter commits an item, duplicate values are suppressed case-insensitively, and draft text is also persisted to prevent loss on Done. Input respects existing backend length limits. Fixed misleading cancellation feedback when clearing chat without a proposal. Independent review checked parser safety boundaries, draft persistence, external-value synchronization, length limits, narrow layout and existing onboarding flows; compacted the input so existing onboarding controls remain reachable. New widget tests cover add/remove/deduplicate/restore, drafts and full-length values.

Final tag-input release: Flutter analysis passed, all 53 Flutter tests passed. Signed APK built in 38.9 seconds and verified with apksigner. Artifact: mobile/build/app/outputs/flutter-apk/Valora-Nebius-Preference-Tags-2026-10-29.apk. Physical-device installation and user interaction remain for the user to verify.

## 29 October — autocomplete and pantry voice
All Other tag fields now use local suggestions: custom goals, food exclusions, Other allergies, Other health context and Other cuisines. Alias matching resolves selection to stable canonical values; custom input remains possible and existing persistence is preserved. Backend contract tests verify every selectable food/allergen ID is accepted and every suggested cuisine exists in the catalog.

Added Pantry → Add or remove by voice. Device speech recognition produces an editable command, then a single-item preview and explicit add/update/removal confirmation. Existing pantry persistence is reused; duplicate names are rejected rather than bulk-deleted. Added Android microphone permission/recognition-service visibility and iOS speech/microphone descriptions. No audio is sent to Nebius by Valora; device speech service may use its own network. English pantry command parsing supports numeric/spoken quantities, unit-first/name-first addition, setting quantities and whole-item removal. No always-on capture.

Validation: backend typecheck and all 78 tests passed. Flutter analysis passed; all 59 tests then present passed, followed by an additional duplicate-name voice regression test (all five voice tests passed). Tests cover canonical alias selection, custom entry, length limits, add/remove/deduplication, typed fallback, transcript confirmation, stale pantry rejection, sign-out/late result isolation and duplicate-name rejection. No physical microphone/device runtime claim. Independent review caught and fixed lazy initialization of account snapshot, speech cancellation ordering and canonical-alias length bounds. Existing canonical Valora workspace remained clean.

Autocomplete/voice release built successfully in 83.0 seconds and APK signature verified. Artifact: mobile/build/app/outputs/flutter-apk/Valora-Nebius-Autocomplete-Voice-2026-10-29.apk (97,635,794 bytes).

## 29 October — multi-item pantry and contextual voice chat
New authenticated POST /v1/pantry/interpret extracts a strict review draft from natural language, including multiple items and package sizes. Existing cloud consent is required and rechecked; no database writes occur from inference. Flutter resolves all draft targets against current pantry, rejects duplicates/unknown removals/missing quantities, and applies one atomic local batch using existing versioned persistence only after confirmation. Clear multi-item commands use the local parser; ambiguous natural language uses Nebius without silent provider fallback. Continuing dictation appends rather than replacing previous items.

Added chat microphone: device speech → editable draft → Use in chat → explicit Send. The same typed-message path handles both inputs. ContextAgent proposes allowlisted allergy/exclusion/cuisine/eating-pattern changes and temporary reported symptoms/comfort style. No model-generated arbitrary tools or memory keys. Symptoms are user reports, not diagnoses. Weather cold cannot be stored as an illness. Confirmed comfort style lasts 24 hours; the meal selector prefers suitable warm soups and expiry removes that preference from planning. Permanent allergens still constrain every choice. Raw saved medical notes are not attached to meal inference. Existing profile/memory persistence is reused; actions have stale-profile and account guards, retry without reapplying, and sign-out cleanup. ElizaOS inspiration is architectural only; no framework code/dependency added.

Validation: typecheck, 88 backend tests, Flutter analysis and all 67 Flutter tests passed. Independent pass checked schema/consent boundaries, partial-batch rollback, packaging preservation, snapshot guards, temporary expiry, weather-vs-symptom grounding and persistence. Found and fixed pending-context sign-out cleanup and alias normalization. Worker deployed with isolation guard as version 48abcce7-3271-4997-87f3-90427e09d28a.

Live synthetic inference: exact example “I have a kg of potato and 2 cartons of milk 1 litre each” returned both draft items with packaging in 4,053 ms. Fever/cold returned review-only symptoms and warm style in 2,955 ms; GET memory confirmed no automatic save. Explicit comfort-style persistence followed by regeneration returned carrot/lentil soup in 1,879 ms. Cold weather returned only meal style (995 ms); peanut allergy produced a canonical proposed update (2,704 ms). This tests deployed inference and existing persistence routes, not on-device microphone or full Google login. Synthetic account is removed after verification.

Release APK built in 47.2 seconds and signature verified. Artifact: mobile/build/app/outputs/flutter-apk/Valora-Nebius-Context-Voice-Batch-2026-10-29.apk. Physical-device microphone and end-to-end interaction remain for user testing. No clinical treatment, nutrition guarantees, ordering or activity prescriptions added.

## Saved-restriction regression — 2026-10-29

Deployed Worker version `5b28b882-5bc5-4b37-929f-ae5376b6df69`. Backend type checking and 95 tests passed before deployment. Independent source review checked normalization, preservation of unknown-restriction holds, and mandatory profile allergy/exclusion filtering. Paused profile-reference facts no longer create a blanket hold; separate paused custom safety notes still do. Recognized conversational eggplant exclusions and punctuation are normalized. Unknown entries are identified individually in chat.

Live operator-authenticated synthetic account (not a device/Google-login test): saved vegan profile, Milk allergy, “I don’t eat eggplant…” exclusion, paused allergy/exclusion references. Plan ready in 2189 ms; grounded chat in 2195 ms, both using NVIDIA Nemotron via Nebius. Ingredient checks passed; Italian dinner proposal, explicit confirmation and reload persistence passed. Synthetic account and dependent records deleted afterward. No actual user profile was inspected, so the user-specific cause remains unconfirmed. No Flutter source changed or APK rebuilt for this backend fix.

## Food-name allergy regression — 2026-10-29

Screenshot identified active allergy values paneer and chicken, rejected by the major-allergen-only alias lookup before inference. Known ingredient names now resolve using the existing food vocabulary as well; paneer maps conservatively to milk. Both allergy and exclusion rules use the same recipe tag/ingredient filtering. Unknown entries still fail closed. Independent review checked tag handling, ingredient filtering and unknown-input behavior. Type checking and all 99 backend tests passed.

Deployed isolated Worker version `27dc87b2-c7ad-4725-a919-c9e7fa38f06e`. Live synthetic Omnivore profile with Other allergies “paneer, chicken” and eggplant exclusion produced a ready Nebius plan in 2566 ms and grounded chat in 3307 ms. Ingredient checks, Italian proposal confirmation and reload persistence passed. This was operator-authenticated synthetic testing, not device verification. Synthetic account deleted afterward. No mobile changes or APK rebuild required.

## Unified Qloo + Nebius release — 30 October 2026

Adapted Qloo source commit `6bcd8e0aad6b15e2fa3c0a9d388aad4deb049a29` into the existing Nebius app/backend. Independent review checked main-flow evidence, one-anchor behavior, food filtering, consent boundaries, redirect credentials, account-owned IDs, stale fingerprints/proposals and client ownership. Review fixes included exact restaurant-tag matching, final consent recheck after discovery lookups, deterministic validation against the actual ranked candidate IDs, and preservation of per-meal evidence on single-meal changes. Qloo inference is not introduced: all language-model requests remain on configured NVIDIA Nemotron via Nebius.

Executed: backend type checking; all **132 backend tests**; Flutter analysis with no issues; all **78 Flutter tests**; signed Android release build; APK signature verification (v2, one signer); web release build (compilation only). Existing 99 backend and 67 Flutter tests remain passing. Source, fixtures and deployment config were reviewed in a separate pass after implementation. No physical Android device was attached (`adb devices` empty); microphone, real Google sign-in and complete physical-device acceptance remain pending. Web browser OAuth was not verified.

Live direct Qloo key check: cuisine lookup and Insights HTTP 200; Indian input returned Chinese/Italian, so selected inputs and returned affinities are kept separate. Deployed authenticated synthetic journey: three Mumbai dining leads, three home recipes, canonical server labels despite forged client labels, all three selected cuisines without excluding all results, Qloo evidence consumed in a Nemotron plan (4852 ms), grounded chat (3180 ms), confirmed Italian dinner replacement and persisted evidence, narrower discovery refinement to 20 minutes, two-item packaged pantry parsing, and stale-plan invalidation after ordered taste changes. Discovery took 22177 ms initially and 29123 ms with model refinement. Real private user prompts were not logged. These were short-lived operator-signed synthetic identities, not a Google/device-login test.

A separate live Omnivore profile with reported paneer/chicken allergies, eggplant exclusion and firm Indian preference generated a ready Qloo-informed Nemotron plan (3993 ms) and chat (4327 ms); ingredient checks, confirmed Italian replacement, restart-style reload and research responses passed. Final deployed-source check repeated this case with per-meal evidence required: plan 3954 ms, chat 1737 ms, proposal 2451 ms; confirmation and reload passed. Synthetic accounts and their account-owned data were deleted afterward; rate counters expire through the existing bounded bucket cleanup. Canonical and Qloo reference working trees remained clean.

Migration 0006 applied only to valora-nebius-db. Final Worker: `b10adc44-898c-405f-a022-d096581a68bd`. QLOO_ENABLED=true; Nebius provider/model/OAuth/app ID/signing/API URL unchanged. Qloo key uploaded as its own Worker secret, never from a bulk development-env upload.

APK: `mobile/build/app/outputs/flutter-apk/Valora-Nebius-Qloo-0.2.0-2026-10-30.apk`, version 0.2.0+2, 98012998 bytes. SHA-256: `5EA569C2EA5E1B3965C1325B31C8F5EA76142A0BB2BAA3566EFAFD5A83F8304B`. Prior signed APK/release retained. See QLOO_INTEGRATION.md for truthful catalog coverage, conservative Discover holds and operator rollback.

## Preferences-first UX — 30 October 2026, version 0.2.1

Removed Discover and its separate session adapter. Its feature-specific UI tests were retired with the removed page; shared backend discovery boundary tests remain. Cuisine lookup now runs from the existing preference tag field with 500 ms debounce, bounded account API calls, canonical label selection, stale-response/disposal guards and local options on failure. Main personalization projects only saved cuisine preferences and account-resolved IDs, ignoring legacy Discover tastes. No usable public cuisine signal means no Qloo call and no Qloo attribution; the existing Nebius flow still applies saved restrictions. Valid returned affinities cannot discard a firm local cuisine preference merely because mapping coverage differs. Upstream errors remain explicit.

Underlying names removed from workflow labels, consent explanations and failure prompts; small powered-by credits remain. Android launcher is Valora; app ID, callback, signing and backend unchanged. Allergy Other suggestions now combine the supported allergen list and food aliases, merging duplicate-ID aliases so paneer is suggested as milk/dairy. No user allergy input is sent to taste search. Operator-only live probes of milk/peanut/chicken returned dish, venue and dietary-option tags, not a dependable ingredient dictionary; these were not adopted as allergy values or suitability evidence.

Executed: backend type checking and **135 tests**, Flutter analysis clean and **70 tests**, final signed Android APK build and signature verification. Independent review covered preference projection, supported-cuisine coverage, local alias merging, async race handling and the absence of provider/Discover setup prompts. The branding change intentionally updated one exact-label test; core behavior assertions remain. Live authenticated synthetic journey searched Italian, saved it in Other cuisine without any separate taste save, generated a restriction-checked plan with real taste evidence (3374 ms), and answered chat (1744 ms). After changing cuisine to Anything, a ready Nebius plan was generated in 2023 ms with no false taste attribution; paneer/chicken allergies and eggplant exclusion remained enforced. Synthetic account and account-owned rows were deleted. Worker version `a5f5752d-25c3-445c-8cf9-3e95128c0f19`. Physical-device acceptance remains pending.

APK SHA-256: `A322EF8617DA4E6E8505F19CE96AA5EF5A413A99A95F7E3147B72B65A23C5984`. File: `mobile/build/app/outputs/flutter-apk/Valora-0.2.1-2026-10-30.apk`.
