# Confirmed chat changes

Implement explicit single-field commands for weekly budget (INR), cooking minutes, and eating pattern (Omnivore, Vegetarian, Vegan). Parse only whole commands; conversational or compound requests stay with AI. AI output cannot authorize writes.

Show current and proposed values before confirmation. Confirm rechecks the original profile snapshot and account session, then uses the same profile update and save path as settings. Cancel makes no change. A failed save retains the visible unsaved edit and retries persistence without applying the command again. Account changes and clearing chat discard proposals. Preview mode labels changes as session only.

No schema migration, new backend endpoint, clinical changes, purchases, or pantry writes. Validate parser boundaries, confirmation, cancellation, stale edits and persistence outcomes; independently inspect changes. Existing API validation limits remain authoritative.
