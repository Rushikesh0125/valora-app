# Chat integration

## Mapping and architecture

- Chat composer and suggestion chips -> one controller entry point. Explicit saved-data reads use the shared account state before any AI request.
- Existing pantry/rules/limits/plan cards stay live. Add profile and memory views for preference and saved-fact questions.
- Other text -> local Gemma for routine tasks when installed; cloud fallback only after cloud consent. Local initialization/inference/cleanup failures cannot silently block an otherwise consented cloud request.
- Current mobile test mode overrides that routing: every request, including complex requests, uses Gemma on-device only. It does not call cloud AI when Gemma is unavailable or fails. `localOnly: false` restores the consented cloud fallback after testing.
- Each inference receives the current message plus a bounded window of earlier successful conversation turns. Failed attempts and interface status messages stay out of model history.
- Saved-food context is an explicit per-session toggle, off by default. Include active eating/cuisine preferences and practical limits; exclude health fields, arbitrary memory and paused facts. Never silently attach pantry quantities or example plans as verified data.
- The existing API context field carries bounded structured JSON for history and optional food context. No new persistence schema. Model output is conversational guidance, not an executed change or saved plan.

## Invariants and semantic differences

- Saved reads make no inference calls and never require cloud consent or a model download.
- Edits/compound requests must not be misclassified as reads. Typed action proposals/confirmation remain the next milestone.
- Only one inference at a time. A busy composer preserves its draft; failures offer retry without duplicating the user turn. Logout invalidates pending responses and clears context sharing/history.
- Provider secrets stay on the Worker. Explicit cloud consent is checked by the server on every inference.
- Conversation context includes only turns actually sent/answered by AI, preserving user/assistant roles and bounded sizes. It is ephemeral and cleared on logout.

## Validation

Test connected saved reads without network inference; multi-turn history; context opt-in and health/paused-field exclusion; local absence/failure with cloud consent on/off; send/retry behavior and account isolation. Review code separately, run Flutter tests/analysis and backend checks, then build Android. Verify provider credentials before claiming live cloud inference succeeds.

## Confirmed chat preference commands

Chat now recognizes explicit whole commands for weekly budget in INR, cooking minutes, and eating pattern. It presents current → proposed values and requires Confirm change. Cancel leaves data unchanged; stale profile snapshots require a new request. Confirmation uses shared profile persistence. Failed saves expose Retry saving without reapplying the edit. Preview changes are labelled session only. AI-generated prose does not execute writes.

Examples: `Set my weekly budget to INR 3000`, `Set my cooking time to 20 minutes`, `Set my eating pattern to vegetarian`.

Scope remains narrow: free-form AI action proposals, allergy/health changes, pantry/intake/plan persistence and purchases are not implemented by this milestone. No cloud key is needed for these explicit commands. Automated tests were not added or run for this milestone; static analysis and Android build results are reported separately.
