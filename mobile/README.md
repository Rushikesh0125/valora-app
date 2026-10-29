# Valora mobile app

Flutter implementation of the approved mobile design, with Android, iOS, and web runners. Google sign-in is connected. Confirmed onboarding, profile, preferences, saved facts, pantry, meal logs and example plan edits are restored from the account API and saved after edits. Chat is in Gemma only test mode: routine and complex requests both use Gemma 4 E2B on-device, with no cloud fallback. Profile → AI & model settings downloads Gemma directly into Valora; users do not need a Hugging Face account or separate model app. Tokens are stored securely and refreshed through the Worker. Upload processing, push delivery, live provider quotes, and payments are not connected.

## Run

From this directory:

```powershell
flutter pub get
flutter run -d chrome --dart-define=VALORA_API_URL=http://localhost:8787
```

Android and iOS default to the deployed Valora API. Run `flutter run` on a connected device. `VALORA_API_URL` can override the API origin for a separate configured environment. Native account flows require Google sign-in; local unauthenticated development identities are for direct API development requests. Web and desktop are UI previews and do not connect the mobile OAuth flow.

Confirmed onboarding saves before entering the main app. Later changes show a saving/unsaved banner, with retry on failure. Wait for saving to finish before force-closing the app: pending edits are held in memory, without an offline outbox. A failed account load blocks editing and offers retry instead of replacing saved data with defaults. Pantry corrections and linked meal logs save atomically. Conflicting edits from another device require confirmation before loading the saved food records; profile edits stay queued. Plan dates persist, and Start a new draft for tomorrow explicitly replaces the five-day example draft. Quotes and purchase review remain transient.

Flutter 3.47.7 and Dart 3.13.5 were used here. The SDK is installed at `C:\Users\hello\develop\flutter` and its bin directory was added to the user PATH; newly opened terminals will pick it up.

### Device check for saved food records

1. Sign in, add a pantry item, and log a meal using it with an explicit remaining amount.
2. Change a plan serving count or swap a meal. Wait for the saving banner to disappear.
3. Close and reopen the app. Check the pantry amount, meal log, plan dates and edited slots.
4. For a conflict check, load the same account on two devices before editing. Save on one, then edit on the other. The second device should offer Load saved and ask before discarding local food edits.

This flow has not yet been checked on a signed-in device for the food-record milestone.

## Screens and interactions

- One-page onboarding with five questions, conditional Other fields, one food-exclusion input for every eating pattern, budget/time sliders, and profile confirmation.
- Chat workspace routes explicit saved-profile, memory, pantry, limit and plan reads to current shared state before AI. Other messages use local inference or consented cloud AI with bounded conversation history.
- Independent daily drafts with recipe details, per-meal portions, swaps, removals, and text-based sample rotation.
- Grocery comparison and exact example-basket review; prepared-food examples ranked for cuisine fit and full delivery cost.
- Pantry ingredients and leftovers; confirmed meal logging with optional explicit correction of the linked pantry quantity.
- Insights based only on confirmed meal records.
- Profile and preferences, memory provenance/pause/removal, sample report-fact review, notification templates and controls, privacy, and payment status.

All meal/provider values are examples. Changing meals, portions, pantry, or relevant profile details invalidates the grocery quote. The preview cannot regenerate a verified quote. Allergy/exclusion details and relevant health context hold meal proposals until reviewed; pausing a safety fact does not bypass it. No approval button submits an order.

## Structure

- `lib/app.dart` owns the app shell and navigation.
- `lib/core/` contains typed models, a session controller, theme, and shared widgets.
- `lib/features/` contains screens and supporting sheets.
- `test/` covers routing, state invariants, responsive layouts, chat, shopping, and linked meal/pantry interactions.

Gemma inference uses `flutter_edge_ai` and its LiteRT-LM engine on Android/iOS. The app downloads the pinned Gemma 4 E2B LiteRT model when the user taps Get model in Valora. The artifact is about 2.59 GB; recommend Wi-Fi and sufficient free storage. It is not embedded in the APK, and users do not need a Hugging Face account or separate model app. The model source and Apache 2.0 license are available from AI & model settings. In Gemma only test mode, all requests and retries stay on-device, independent of the request complexity or saved cloud AI consent. Without Gemma installed or when inference fails, the app shows an error and does not call the cloud AI endpoint. Override `VALORA_API_URL` using `--dart-define` when needed; never pass provider keys to Flutter. `GoogleSignInService` handles tokens directly in Dart using platform secure storage.

The shared icon source is `assets/brand/valora-mark.svg`. Regenerate platform launcher icons with `python tool/generate_icons.py` (requires Pillow); do not edit the generated PNGs.

## Validation

```powershell
flutter analyze
flutter test
flutter build web
flutter build apk --debug --no-android-gradle-daemon
```

Static analysis and all 38 Flutter tests pass after the account-data and chat integration. Tests include fresh-session restoration, save failures/retry, memory pause/removal, quiet-hour normalization, logout races and the auth gate. Web and Android debug builds have succeeded. The Flutter web preview was exercised in the browser; native Android device interaction and iOS compilation have not been verified on this Windows host.

The debug APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`. The web preview can be served from `build/web`.

On this Windows workspace, Kotlin incremental caching fails across the project/cache drives. The verified Android debug build uses:

```powershell
cd android
.\gradlew.bat assembleDebug "-Pkotlin.incremental=false"
```

Account persistence is verified against a mock HTTP boundary. Check the production path on a signed-in device by saving a preference, restarting, and confirming it is restored without onboarding.

## Chat integration

The composer and suggestion chips share one router. Saved-data reads require no model. Other requests include recent successful conversation turns; this history is session-only and can be cleared from chat. AI responses are labeled by provider/device location.

The Include food preferences option is off by default. Turning it on attaches selected active food preferences, reported allergies and practical limits. Health-context fields, arbitrary saved memory, pantry quantities and example plans are not attached automatically. Previous conversation messages are included regardless of that toggle, as described in the interface.

Retry keeps the existing user message. Sending while busy preserves the draft. AI cannot execute profile edits, generate a persisted plan, or place orders. Real Gemma inference still needs runtime verification on a supported device with the model installed. Restore cloud fallback by setting `localOnly: false` when the on-device test is complete.
