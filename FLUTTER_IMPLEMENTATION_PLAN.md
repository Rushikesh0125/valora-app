# Valora Flutter implementation plan

## Source to target mappings

| Browser prototype | Flutter target |
| --- | --- |
| Onboarding and profile confirmation | One-page Flutter onboarding with all five questions and a confirmation page |
| Chat workspace and focused conversation | Chat tab with direct saved-state widgets and custom-message conversation |
| Plan, recipe, rotation, and meal log | Plan tab and focused detail sheets |
| Grocery and prepared-food comparisons | Shop flows with explicit example labels and approval preview |
| Insights | Insights tab with honest illustrative data and empty states |
| You/profile, memory, reports, settings, payments | Profile tab and grouped detail routes |
| CSS tokens and responsive phone frame | Flutter theme, reusable components, and native safe-area/layout behavior |

## Architecture changes

- Keep the web prototype as a reference; build a dedicated Flutter app in `mobile/`.
- Use a feature-oriented structure: `app`, `core/theme`, `core/widgets`, and `features/{onboarding,chat,plan,shop,insights,profile}`.
- Keep local in-memory design state and its mutations in a separate `SessionController`, with typed models for profile, pantry, consumption, plans, and offers. Backend repositories will be introduced against the actual API contract; no placeholder network methods are included.
- Add no nonessential Flutter packages for the initial UI. Use Flutter SDK components until a concrete device integration requires a package.
- On-device AI, network APIs, payment, nutrition calculations, and commerce remain disconnected in this UI milestone. Never represent sample values as live results or claim an order was placed.

## Invariants

- Preserve the approved warm-neutral/deep-green design and the chat-first 4-tab navigation.
- Keep profile facts, preferences, inventory, and consumed meals semantically distinct.
- Uploaded reports/photos are not stored; this milestone only represents the review path and does not process files.
- Allergy and exclusion details remain distinct from cuisine preferences; no health diagnosis or supplement recommendation.
- User must review exact merchant, basket, and total before any purchase integration is later enabled.
- Swiggy phase-two target is in-app discovery, cart review, and checkout using delegated OAuth/MCP, subject to Swiggy production approval. Do not design around a Swiggy-app basket handoff; allow an external UPI app or QR payment step when Swiggy returns it.
- One personal profile only; family linking remains out of scope.

## Validation strategy

- Confirm Flutter/Dart SDK availability before claiming a successful build.
- Build and launch on an available emulator/device; inspect onboarding, chat, plan, shop, insights, and profile layouts at phone dimensions.
- Exercise navigation, text entry, selection, sliders, meal rotation, pantry/profile edits, and example approval states.
- Run `flutter analyze` and relevant widget tests only if Flutter tooling is available; report precisely which checks ran.

## Implemented structure

- `mobile/lib/app.dart`: adaptive app shell, native back behavior, four-tab navigation.
- `mobile/lib/core/`: visual tokens, reusable widgets, typed session models, deterministic request routing and state changes.
- `mobile/lib/features/`: onboarding, chat, plans, shopping, insights, profile, and supporting sheets.
- `mobile/android`, `mobile/ios`, `mobile/web`: generated platform runner sources, then app-owned platform configuration. Build-generated outputs remain untouched.
- Bundled Manrope and DM Sans fonts with their licenses; launcher icons generated from the shared SVG source by `mobile/tool/generate_icons.py`.

## Integration boundaries

This milestone implements the UI and its local interactions. Confirmed profile data, preferences and memory now load/save through the authenticated API; pantry, plans and meal records remain session-only. A hybrid AI path is now available when `VALORA_API_URL` is configured: Gemma 4 E2B runs routine requests on-device after an explicit model download, while complex cloud requests require backend setup and user consent. Google authentication and the branded first-run screen are connected; tokens use platform secure storage. Upload processing, push delivery, provider quotes, and payments are not connected. Disabled integrations and sample actions identify their actual state in the interface. An order never becomes a consumed meal; a linked meal corrects inventory only from the user's explicit remaining-amount entry.
