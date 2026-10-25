# Remaining mobile flow fixes

## Source to target

| Current behavior | Target behavior |
| --- | --- |
| Meal coverage select is ignored | Store it, show it in the profile, and render only the selected meal slots |
| Pantry edits can reopen the original basket | Track pantry revisions and block the fixed quote after any change |
| Edited plans stop at a stale message | Show the changed draft and its ingredient checklist; require a fresh provider quote for prices |
| Meal reports have no source | Let the user link a report to a pantry ingredient or prepared leftover and confirm the amount remaining |
| Memory is edited in broad groups | Offer per-detail inspect, pause, resume, and remove controls |
| Notification controls are mostly fixed text | Expose routine categories, frequency, and quiet hours |
| Voice, attachments, and prepared food look more complete than they are | Provide capability-gated voice capture and explicit unavailable or review states |

## Architecture and invariants

- Keep one in-memory personal profile and the existing single-page mobile prototype.
- Never claim a new nutritional calculation, safe recipe match, provider quote, upload extraction, payment, or order.
- A pantry or plan change invalidates the fixed example basket. The changed ingredient checklist can still be reviewed without a price.
- Eating and inventory remain separate events. Inventory changes only when the user confirms a remaining amount for a linked source.
- Pausing a safety fact must pause planning until the fact is resolved; it must not silently remove a protective restriction.
- No uploaded file bytes or full extracted text are retained.

## Validation approach

- Inspect the affected screens and interactions in a fresh browser session.
- Check the dinner-only path, pantry revision block, linked meal report, per-fact memory controls, notification settings, and unavailable provider states.
- Review the changed code independently against these invariants.

## Implemented prototype behavior

- Meal coverage is retained in onboarding, profile, and the visible draft.
- Each day retains its own meal swaps, removed slots, and servings. A swap affects only its meal.
- Every pantry correction invalidates the fixed example basket. Changed drafts expose an ingredient checklist without invented quantities or prices.
- Pantry entries distinguish ingredients from prepared leftovers. A meal report can link to a source and explicitly correct the amount remaining.
- Optional remembered facts have individual inspection, pause/resume, and removal controls. A paused safety fact holds planning.
- Notification categories, frequency, and quiet hours are editable for the session. Disabled categories disappear from notification previews.
- Sample fact review supports editing and type selection before confirmation. Real file selection does not process or retain bytes.
- Speech recognition is capability gated and leaves the transcript for review before sending.

## Service dependencies

Actual recipe quantities, nutritional calculations, extraction, provider quotes, ordering, scheduled notifications, and durable memory still require their production services. Voice capture requires browser support and microphone permission; microphone capture was not exercised in the review.
