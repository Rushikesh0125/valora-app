# Valora Nebius

Eat right, every day—with personalized meal planning based on saved food preferences, reported allergies, cooking time and cuisine choices.

## Project

- [Flutter app and local setup](mobile/README.md)
- [Worker API and backend setup](backend/README.md)
- [Landing page](landing/README.md)
- [Submission, deployment and judge instructions](NEBIUS_SUBMISSION.md)
- [Executed validation and known limitations](NEBIUS_VALIDATION.md)
- [Research sources and applicability limits](KNOWLEDGE_LAYER.md)
- [Demo script](NEBIUS_DEMO_SCRIPT.md)

Flutter connects to an authenticated Cloudflare Worker and D1 database. NVIDIA Nemotron via Nebius Token Factory interprets requests and selects from eligible recipes. Application logic validates food restrictions and requires confirmation before proposed updates are saved.

This is an Android MVP for everyday meal assistance. Clinical diets, verified nutrition and Swiggy ordering are not provided. See the validation record for actual verification results.

Baseline: [Valora](https://github.com/Rushikesh0125/valora), commit `6c3645d`. This variant uses independent deployment resources.

Original code is MIT licensed; see [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md).
