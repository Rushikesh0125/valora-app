# Valora implementation status and remaining work

Reviewed: 23 October 2026. Based on the PRD, architecture and Flutter plans, current Flutter/Worker sources, and deployment evidence from this chat. This is a source review; no tests or live provider sign-in were rerun for this audit. Google sign-in was reported working by the user.

## Current state

AI test-mode update (23 October 2026): mobile chat now routes both routine and complex requests to on-device Gemma only. Missing model, unsupported platform or inference failure returns an actionable error and never falls back to cloud; saved cloud consent is left untouched. AI settings explains that cloud chat is not used during this test. Restore consent-gated fallback with `localOnly: false` in `ValoraAiService`. Cloudflare Worker AI endpoints are unchanged. Flutter analysis passed and Android APK build succeeded; automated tests were not run and on-device inference remains unverified.

Latest delivery evidence (food records): migration 0003 applied to local and production D1; Worker version `3126e319-f5ef-496d-a3d6-f9589099f2d9` deployed. Flutter static analysis and backend type checking passed, save SQL compiled with SQLite EXPLAIN, and Android debug APK built. Automated tests were not run for this milestone. Signed-in persistence and conflict recovery still need device verification. No new secrets or environment variables are required.

Food-record persistence milestone: pantry ingredients/leftovers, confirmed meal logs and five-day example draft edits now use authenticated `GET/PUT /v1/food-state`. The D1 aggregate commits linked intake/pantry corrections atomically, checks versions across devices, and supports idempotent retry. Native account startup restores these records before allowing edits; logout clears them. Plan start dates persist, and the app offers explicit draft replacement for tomorrow. Conflicts require confirmation before discarding local food edits. See `FOOD_RECORDS_PLAN.md`. Recipe generation, verified nutrition, structured inventory units and event history are still outstanding. Pending unsaved edits are in memory; no offline outbox is implemented. This supersedes the original audit's local-only pantry/consumption/plan persistence gaps below.

Chat integration milestone implemented: all chat entry points use saved-state routing before AI; inference includes bounded successful conversation history with an optional food-preference context switch. Health fields are excluded from automatic context. Added consented local-to-cloud fallback, retry without duplicate user turns, source labels and draft preservation. The Worker changes are deployed. Flutter analysis, 38 Flutter tests and 4 backend tests pass. Live inference remains unverified because provider credentials are not yet configured; model/provider selection is pending. Confirmed edit/action tools and durable chat history remain future work.

Account-data milestone implemented after this audit: confirmed onboarding, profile, preferences and memory now load/save through the existing API. The app blocks on failed loads, shows unsaved changes with retry, restores completed onboarding, and clears account state on logout. Session refresh failures distinguish temporary outages from invalid credentials; late refresh responses cannot restore credentials after logout. Flutter analysis and 28 tests pass. Production persistence still needs a signed-in device restart check. See `ACCOUNT_DATA_PLAN.md`.

Valora has a deployed authentication and user-data backend and a connected account-data foundation. Pantry, plans, consumption and most agent/commerce flows still use local data or examples. The table below is the original audit baseline; the account-data update above supersedes its profile/preferences/memory and session-handling gaps.

| Area | Evidence and status | Remaining work |
| --- | --- | --- |
| Google authentication | Worker OAuth, app callback, secure token storage, refresh/logout, branded auth screen and startup gate exist. User confirmed sign-in works. | Validate expired/revoked sessions on startup; surface callback failures; synchronize UI when a session expires; reset user-owned app state on sign-out/account changes. Verify iOS on device. |
| Onboarding/profile | UI and profile API exist independently. `completeOnboarding` changes an in-memory flag. No Flutter caller invokes profile API methods. | Serialize profile to API; save confirmed onboarding; load it after login; skip onboarding only when a saved completed profile exists; report saving/loading failures and support retry. |
| Preferences | API and editable local state exist. Flutter never calls preference read/write methods. | Persist settings; restore them into one shared state; standardize quiet-hour format (D1 reads currently expose seconds; PUT accepts HH:MM). |
| Memory | D1 CRUD exists. App facts are derived from local profile; pause/remove state is local. | Load memory IDs and provenance; connect edits/pause/resume/delete; define how profile fields and memory facts stay consistent; keep safety holds when facts are paused. |
| Chat routing | Local deterministic router exists, but ChatPage sends every connected text message to AI instead. | Route saved-state reads before AI; use the same shared state in cards and replies; add explicit confirmation for changes. |
| AI conversation | Cloud provider adapters and consent endpoints exist; on-device model integration exists. Chat sends only the current prompt, without history/profile/memory. | Configure and verify provider credentials/models; pass limited approved context and history; handle consent/loading/errors; provide cloud fallback when local inference fails; verify a real Gemma download and inference. |
| Agent actions | AI service explicitly has no tools and cannot change plans or saved data. | Implement typed proposed actions, validation and user confirmation, then execute through the same repositories as screen edits. |
| Plans/recipes | Fixed recipe options, swaps, servings and coverage exist locally; dates/drafts are regenerated in memory. | Durable plan/recipe model and APIs; approved recipe data and quantities; real planning and constraint filtering; save edits/acceptance and invalidate dependent quotes. |
| Pantry/leftovers | Local example items and quantity edits; linked intake correction exists. No tables/endpoints. | Durable inventory lots and events, units/quantities, cooking-to-leftover transitions, reconciliation and idempotent updates. |
| Meal records/insights | Confirmed intake drives a local seven-day count. Records disappear on restart. | Persistent consumption records; historical summaries and source coverage; additional PRD measures only when supporting data exists. |
| Notifications | Category/frequency/quiet-hour UI and template previews exist. | Persist preferences; device permission/token registration; scheduling and delivery; timezone/quiet-hour behavior; category-specific styles, wording and deep links. |
| Nutrition knowledge/admin | User role exists; no nutrition-source tables, admin APIs or source-management UI. | Admin source ingestion, rights/metadata, structured validation, versions and publication; approved recipe/nutrient mappings and deterministic calculations. |
| Document extraction | Sample fact-review UI only. No file processing pipeline. | Phase two: temporary processing, extraction, confirmed fact publication and verified deletion of temporary content. |
| Swiggy/commerce | Example merchants/baskets and approval previews only. No provider integration. | Phase two: provider access, delegated authorization, live offers, cart/checkout, exact approval records, payment/order status and reconciliation. |
| Privacy/account controls | UI and provisional policy exist; no complete export/deletion/retention workflow. | Implement account/data deletion, export and retention behavior before public launch. |
| Verification | Previous static analysis and Android debug build passed; existing tests focus on prototype behavior. | Add integration coverage for account isolation, persistence/restart, saved-state chat, refresh expiry and confirmation flows. Recheck Android; compile/test iOS on macOS. |

## Recommended implementation sequence

1. **Account data foundation:** restore/validate session, load profile/preferences/memory, save onboarding, synchronize screen edits, handle retry and account changes. Completion: a preference survives restart and re-login and appears consistently in every screen.
2. **Useful chat:** deterministic saved-state reads first, then consented AI with selected context/history. Completion: pantry/profile questions show actual saved state; reasoning requests return a real response; failures give an actionable message.
3. **Confirmed chat edits:** typed proposals and confirmation, applied through shared repositories. Completion: a confirmed preference change updates both chat and profile and remains after restart.
4. **Durable core records:** pantry, consumption and plan APIs plus app integration. Completion: meal logging and pantry reconciliation survive restart and drive historical insights.
5. **Real planning and knowledge:** admin-managed approved sources, recipes, quantities and deterministic constraints/calculations. Completion: a plan is generated from approved inputs rather than fixed examples.
6. **Notification delivery:** scheduled plans and category-specific prompts that honor stored timing, timezone and quiet hours.
7. **Phase-two integrations:** document extraction and Swiggy after their access and data contracts are available.

## Specific implementation concerns to fix during the relevant milestone

- Startup currently considers a stored refresh token sufficient to mark the user signed in; it does not validate that session first.
- Refresh failure can clear stored tokens without updating `SessionController.signedIn`. A temporary non-200 response also triggers sign-out; distinguish invalid credentials from a transient outage.
- Sign-out clears tokens and consent but leaves profile, pantry, intake, chat and onboarding state in memory. Account switching must not expose another account's data.
- OAuth callback exceptions are swallowed in `app.dart`; users can return to the auth screen without an explanation.
- `submitAiChat` does not pass profile, memory or chat history to inference. Its keyword-based complexity routing is basic scaffolding.
- Local model availability/inference errors can fail a routine request before reaching cloud fallback.
- Last inspected Cloudflare secret inventory contained signing and Google secrets only. Cloud AI credentials and actual model availability must be checked before claiming cloud chat works.
- Mobile auth is enabled only on Android/iOS. The web/desktop preview does not exercise the production auth gate.

## Plan/document drift

- `FLUTTER_IMPLEMENTATION_PLAN.md`, `mobile/README.md` and `backend/README.md` still describe a missing MethodChannel auth bridge; the app now uses the Dart Google sign-in service and secure storage.
- Backend README incorrectly says all `/v1` routes require bearer authentication; OAuth start/callback/exchange/refresh/logout have their own public contracts.
- The PRD phase description defers AI while AI adapters are already present. Record this as an implemented foundation with incomplete integration, not a finished agent.
- `REMAINING_FLOW_FIX_PLAN.md` is a prototype flow checklist, not the remaining production implementation backlog.
- Existing README test/build claims refer to earlier checks. They do not establish coverage for the newly added native auth and persistence paths.
- The user's explicit decisions take precedence: Google active; ChatGPT disabled; Cloudflare D1; all ages without guardian flow; simple admin role; extraction and Swiggy deferred; no AI budget/exchange-rate/request-rate environment controls.

Use this document as the current implementation backlog. Keep the PRD as the product requirement source and treat older UI milestone plans as historical context.

### Confirmed chat preferences

Implemented explicit weekly-budget, cooking-time and eating-pattern proposals, confirmation/cancellation, stale-profile checks, shared account saving and save retry. See CHAT_ACTIONS_PLAN.md and CHAT_INTEGRATION_PLAN.md. Broader AI-generated actions remain outstanding. This milestone has not been runtime verified on a device.
