# Remaining mobile flow design pass

## Source to target mappings

| Existing surface | Target in this pass |
| --- | --- |
| `You` screen with raw profile rows | Grouped profile summary with clear paths to edit food rules, practical limits, reports, memory, and privacy |
| Generic memory sheet | Reviewable user facts with source labels and a deliberate correction/removal path |
| Static plan page | Reviewable draft with visible status, meal actions, pantry use, cost estimate, and an explicit route to shopping |
| Simple pantry sheet | Editable estimated inventory, distinct from confirmed consumption |
| Fixed grocery page and basket sheet | Merchant comparison showing estimated full cost and a final exact example basket before any approval |
| Decorative insights chart | Confirmed meal log, coverage, and honest empty states |
| Settings and privacy sheets | Understandable controls for notifications, uploads, and payment status |

## Architecture and invariants

- Keep the existing single-page prototype and its warm neutral / deep green visual language.
- The prototype has no agent, merchant, payment, or file processing integration. Example content must be labelled, and no action may claim a real order or calculation happened.
- Reported allergy and food exclusions remain separate from cuisine preferences. A change to safety-relevant details invalidates an accepted draft.
- A newly reported health context pauses the illustrative draft until an appropriate planning workflow can review it.
- Pantry inventory and consumed food remain separate. Recording a meal does not subtract inventory unless a specific ingredient or leftover link exists.
- A basket review binds the visible merchant, items, quantities, delivery window, and total; approval remains a demo action.
- One person's profile is in scope. No family controls are added.

## Lifetime and semantic differences

- All prototype state remains in browser memory and is lost on refresh.
- Profile and pantry edits update only this preview. Extracted facts remain proposed until the user confirms them.
- Illustrative plan and price data do not recalculate from a real recipe or commerce service. Changes to meals, servings, days, preferences, or pantry amounts mark the example basket as stale instead of implying a new calculation.

## Review approach

- Inspect each changed flow against the current screen and action paths in a separate pass.
- Check that primary actions lead to the intended screen or sheet and that empty, changed, and safety-constrained states have honest copy.
- Inspect mobile layout visually in the existing local preview after implementation.
