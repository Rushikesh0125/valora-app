# Account data integration

## Mapping and architecture

- Local Profile -> existing `/v1/profile`; local notification settings -> `/v1/preferences`.
- Profile-derived facts retain profile as the value authority. `/v1/memory` stores their pause state and provenance; independent memory records remain independent facts.
- Login -> validate/refresh token -> load profile, preferences and memory -> publish all restored state together. An absent profile means onboarding; a failed load means retry, never an empty replacement profile.
- Confirmed onboarding saves before entering the app. Later edits are debounced and serialized, with a visible unsaved state and retry. Writes use existing idempotent PUT/upsert/delete operations. Partial multi-resource failures retain the dirty revision for retry; there is no distributed transaction or background retry guarantee after process termination.
- Sign-out invalidates outstanding operations and clears account-owned in-memory state. Operations bind to a session generation so an old task cannot write using a new account's token.

## Invariants and semantic differences

- Unsaved onboarding is never sent by autosave; only confirmed onboarding enters persistence.
- Profile and memory values do not compete: profile fields are authoritative for generated keys. Removed profile fields do not reappear from stale metadata.
- Pause state for safety facts keeps existing planning holds. Unknown independent facts retain server IDs and provenance.
- Missing profile/preferences are valid first-use results; transport/auth failures are not missing data.
- API time strings with seconds normalize to HH:MM in Flutter. Existing UI field names map explicitly to API fields.
- Demo UI without a connected backend retains its existing synchronous interactions.

## Validation and independent review

Verify serializers, restart restoration, onboarding failure/retry, serialized edits, memory pause/removal and account isolation with a mock HTTP boundary. Run Flutter analysis and relevant tests, then Android debug compilation. Review session generation checks and failure paths independently after implementation. Real-device restart persistence must still be exercised by the signed-in user.
