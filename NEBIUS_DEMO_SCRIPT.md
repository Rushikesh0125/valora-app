# Demo recording script — target 2 minutes 40 seconds

Record only after real Nebius inference and Google sign-in are verified. Use
synthetic data, original app visuals and no third-party music or reference images.
Do not expose tokens, key files, OAuth codes or cloud console secret values.

- 0:00–0:15: Explain Valora: a food-planning assistant that remembers confirmed
  preferences and keeps the user in control of changes.
- 0:15–0:35: Show saved vegetarian preferences, budget and cooking time. Explain
  these are synthetic examples. Show the Nebius consent disclosure and enable it.
- 0:35–1:10: Enable food-preference sharing. Ask for a simple lunch idea and then
  a quicker substitution. Show actual replies and the Nemotron/Nebius model label.
- 1:10–1:40: Request a supported cooking-time preference change. Show confirmation,
  confirm, then show the profile. Relaunch and show that the preference persists.
- 1:40–2:00: Ask a saved-state question and explain it uses saved data directly.
  Disable cloud consent and show the actionable response to a new AI request.
- 2:00–2:25: Show the architecture: Flutter → isolated Cloudflare Worker/D1 →
  Nebius Token Factory → NVIDIA Nemotron. Show code/config without secrets.
- 2:25–2:40: State the implemented limits: advisory suggestions, explicit confirmed
  edits, no clinical claims or real ordering. End with source and APK access.

Submission description draft:

Valora helps users think through everyday food choices using confirmed preferences
and bounded conversation context. This Nebius variant adds NVIDIA Nemotron through
Token Factory to an existing Flutter/Cloudflare application. Saved-data questions
remain deterministic, cloud inference requires consent, and supported changes
require review before persistence. The hackathon work includes the provider adapter,
cloud-first routing, source/model disclosure, failure handling, isolated resources
and integration tests. Add measured results and working links after verification.
