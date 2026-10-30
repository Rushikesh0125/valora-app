# Valora

**Eat right, every day.**

<img src="mobile/assets/brand/valora-app-icon-512.png" alt="Valora app icon" width="96">

Valora is a personal meal companion that turns saved food preferences, reported allergies, cooking time and cuisine choices into practical meals. Ask what to eat, change dinner, or update your pantry through text and voice—without explaining your preferences from scratch each time.

[Download the Android app](https://github.com/Rushikesh0125/valora-app/releases/latest) · [Demo recording script](NEBIUS_DEMO_SCRIPT.md) · [Verification record](NEBIUS_VALIDATION.md)

## Why we built it

Eating more consciously can turn an ordinary meal into another research task. We found ourselves repeatedly explaining the same restrictions and preferences to search engines and chatbots, then trying to turn scattered answers into something we could cook.

Valora brings that context into one place. The goal is to make everyday healthy eating easier to follow—not to prescribe a clinical diet.

## What the MVP does

- **Plans the rest of today.** After onboarding, saving preferences and consent, it prepares the remaining meal slots and shows the saved result in Plan.
- **Remembers your food rules.** Supported allergies, foods to avoid, eating pattern, cuisine preferences and cooking-time limits constrain recipe choices.
- **Adapts through conversation.** Ask “What is my plan today?” or “I want Italian tonight.” Review a proposed replacement before saving it; other meals stay in place.
- **Makes preferences easier to enter.** Multiple-item chips, aliases and cuisine suggestions replace long comma-separated lists.
- **Manages pantry updates through chat and voice.** “I bought half a kilo of potatoes and a dozen eggs” becomes an editable batch of proposed changes. Confirmation is required before saving.
- **Keeps your account state.** Saved preferences, pantry records and meal plans are account-scoped and restored on later sessions.

## Try it

1. Install the latest **valora.apk** on Android 11 or newer. Existing users can install over the previous release.
2. Sign in with Google and save your food preferences, including reported allergies and foods to avoid.
3. Enable cloud AI consent and prepare today's remaining meals. Keep the app open while the plan is generated.
4. Open **Plan**, review a recipe's ingredients and preparation steps, then ask for a dinner change in **Chat**.
5. Review and confirm the replacement. Try a pantry update through chat or the pantry screen, then restart to check the saved result.

For a quick demonstration, use synthetic preferences and pantry items. There is no separate discovery or taste-setup screen.

## Technology and how we use it

The two intelligence services have complementary roles; application code owns food-rule validation and persistence.

| Technology | Role in Valora |
| --- | --- |
| **Qloo** | Resolves cuisine searches in preferences and supplies related-cuisine taste intelligence from public cuisine IDs. Actual returned affinities enter the meal-selection context and are kept separate from saved cuisine inputs. It receives no account identifiers, allergy fields, health notes or raw chat. Its cultural and dietary tags are not treated as an allergen dictionary. |
| **Nebius Token Factory + NVIDIA Nemotron** | Provides the language-model layer for interpreting meal requests, selecting from eligible recipes, proposing supported context changes and extracting pantry updates. Requests go through the backend with consent, bounded input/output and validated responses. Pantry interpretation produces review drafts; the model never directly writes account data or places orders. |
| **Flutter + Dart** | Android app, shared interface, accessible preference controls and confirmation flows. System speech recognition supplies editable transcripts. |
| **Cloudflare Workers + D1** | Authenticated API, account-scoped storage, request limits, recipe filtering, saved plans and confirmation checks. |
| **Google OAuth + secure token storage** | One account session for the application. |
| **Vitest + Flutter Test** | Backend boundary, persistence, restriction, conversation and interface regression checks. |

**How the pieces work together:** saved profile → eligible recipes → public cuisine analysis when a usable signal exists → language-model interpretation/selection → deterministic validation → saved plan or a confirmation proposal.

Qloo supplies taste context; Nebius supplies conversational understanding. Neither can override saved food restrictions. When no usable cuisine signal exists, Valora can still plan from saved food rules without claiming taste analysis occurred. Provider failures are surfaced rather than silently switching providers. Credentials stay on the server and are never bundled in the APK.

## Development

See the [setup and deployment notes](NEBIUS_SUBMISSION.md) and [integration operations](QLOO_INTEGRATION.md) for environment variables, authentication and isolated resources. Historical entries are dated; the latest verification entry records the current release.

```sh
# Backend
cd backend
npm ci
npm run typecheck
npm test

# Mobile
cd ../mobile
flutter pub get
flutter analyze
flutter test
```

Configure a development API and account flow before running the app. Never commit credentials or signing keys. On Windows, the release build used:

```sh
flutter build apk --release --no-pub -P kotlin.incremental=false -P kotlin.compiler.execution.strategy=in-process
```

## Verification and MVP boundaries

Recorded checks include **138 backend tests**, **73 Flutter tests**, clean Flutter analysis, a signed Android APK and a successful web build. Live synthetic-account checks exercised cuisine lookup, personalized plans, confirmed replacements, persistence and natural-language pantry quantities. The latest branding APK's packaged logo and launcher resources were also inspected.

Physical-device acceptance, including microphone behavior and the complete external-account sign-in journey, remains pending. Web compilation does not establish a working browser sign-in journey; Android is the submission target. See the [verification record](NEBIUS_VALIDATION.md) for executed checks and their limits.

The recipe catalog and ingredient vocabulary are finite. Product labels and cross-contact must still be checked. Valora does not provide clinical diets, verified nutrition or prices, or ordering/checkout. Cloud features need connectivity; pending edits have no offline outbox. A small [published-study knowledge layer](KNOWLEDGE_LAYER.md) retains citations and applicability limits rather than presenting research as individualized treatment.

## What's next

Broader regional recipes and food terminology, stronger personalization evaluation, and an optional specialized on-device model—while keeping users in control of what is saved and changed.

## Provenance and license

Built on the original [Valora codebase](https://github.com/Rushikesh0125/valora), baseline commit `6c3645d`, with subsequent hackathon implementation documented in this repository. This app maintains its own deployment resources.

Original code is [MIT licensed](LICENSE). Fonts, supplied brand artwork and other third-party materials retain their applicable terms; see [third-party notices](THIRD_PARTY_NOTICES.md).
