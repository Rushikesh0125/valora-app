# Valora mobile design prototype

This is an interactive design prototype for the option 2 direction selected in the product discussion. It uses a compact, practical visual system with warm neutrals, dark green actions, clear cards, and a chat-first flow.

Open `index.html` in a browser, or serve this directory locally with a static file server. No install or build step is needed.

## Screens and interactions

- One-page, five-question onboarding with conditional “Other” fields, one food-avoidance field for every eating pattern, budget and cooking-time sliders, and profile confirmation
- A card-led chat workspace that opens saved plan, pantry, food details, and budget directly; plan review and meal rotation
- Meal coverage carried from onboarding into plan review; recipe and serving review, pantry correction, linked meal confirmation, and coverage-aware insights
- Grocery comparison and exact basket review examples
- Notification templates, grouped profile and memory controls, report fact review, privacy and settings

The prototype uses illustrative content and session-only in-memory state. It does not call a model, access provider prices, process uploads, persist medical files or facts, or submit purchases. Reported allergies or health context pause meal proposals because this prototype cannot verify a suitable plan. Changing meals, servings, days, preferences, or pantry contents marks the fixed example grocery estimate as needing a refresh before basket review. Edited drafts expose an ingredient checklist but cannot show a recalculated quote. Voice capture is available only in browsers that expose speech recognition; users review the transcript before sending. Report uploads are not processed or retained.

Design inputs: [Product requirements](PRD.md) and [Agent system design](AGENT_SYSTEM_DESIGN.md).

The interactive prototype is browser-based and does not determine the production client framework. The production mobile framework decision is **Flutter**; see the product and agent design documents for integration boundaries and on-device AI caveats.

The Flutter implementation is in [mobile](mobile/README.md), with Android, iOS, and web runners. It uses session-only demo data. Run instructions and validation details are in the mobile README.
