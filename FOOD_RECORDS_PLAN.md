# Account food records implementation plan

## Mapping and architecture

| Current in-memory value | Persistent target |
| --- | --- |
| PantryItem list (integer account-local IDs, names, amounts, kind) | food_state.pantry |
| Intake list (name, portion, timestamp, source-name snapshot, remaining amount) | food_state.intake |
| Five DayDraft values / three MealSlot values each | food_state.plan.days |
| firstDate (previously recomputed tomorrow on launch) | food_state.plan.startDate |

Add one D1 food_states row per authenticated user, holding a strictly validated versioned JSON document. GET/PUT /v1/food-state is an aggregate boundary: a meal log and its remaining-pantry change commit atomically. The existing examples remain examples, identified by recipeSet example-v1; recipe generation is outside this change.

## Invariants and lifetime

- No seed pantry data is uploaded to a real account. An empty account restores empty records and a default example draft.
- Resolve ownership from authentication only. No request accepts another user ID.
- PUT requires the last server version and a unique mutation ID. Compare-and-swap rejects stale devices. Repeating the identical accepted mutation is idempotent.
- Client retains the exact in-flight snapshot and mutation ID across failed requests. Later local edits save in a subsequent version.
- Load all account data before permitting writes. Clear records, write snapshots and version on logout; ignore late callbacks from earlier accounts.
- Existing global unsaved/retry banner covers these edits. Conflicts require an explicit reload of saved food records; never silently overwrite the remote copy. Profile changes remain queued.
- Plan dates remain fixed across restart; merchant quotes and review acknowledgement remain transient and stale on restore.
- No destructive migration of existing tables. Existing local-only records from an earlier process cannot be recovered. Preview remains in memory.

## Bounds and validation strategy

Bound requests to 512 KiB, pantry to 500 items, meal logs to 5000 entries, fields to explicit lengths, plan to five days and valid slots/options/servings. Surface limits before mutating app state. Fail loading malformed documents instead of replacing them with empty data.

Review schema, SQL ownership/version checks, serialization and every mutation path independently. Run static analysis/type checking and compile the Android APK. Automated tests will not be added or run unless requested. Apply the additive migration locally before production; deploy the Worker before distributing the updated app.

## Delivery evidence — 23 October 2026

- Flutter static analysis: no issues; backend TypeScript checking: passed.
- Save SQL compiled with SQLite EXPLAIN using literal stand-ins for parameters (no write executed by that check).
- Migration 0003 applied locally and to the configured Rushikesh account's production D1 database.
- Worker deployed as version `3126e319-f5ef-496d-a3d6-f9589099f2d9`.
- Android debug APK built successfully at `mobile/build/app/outputs/apk/debug/app-debug.apk`.
- Existing account API mock updated for the new food-state contract; no automated tests added or executed. Signed-in device restart, conflict UI and authenticated production writes have not been runtime verified.
- Independent source review covered ownership, lost-response retry, account changes, all food mutation paths and conflict recovery. Fixed a queued-profile-save stall after conflict reload and guarded open editors against replaced food records.
