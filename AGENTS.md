# Nebius hackathon workspace

This repository is the Nebius variant of Valora. Make variant changes only inside this repository. The canonical product lives at R:/Projects/valora and must not be modified as a side effect.

The baseline application configuration still references canonical Valora production services. Before any deployment, remote migration, hosting publish or cloud secret update, replace those references with independently provisioned Nebius-variant resources. This includes backend/wrangler.jsonc, mobile API URLs, OAuth callbacks and landing/.openai/hosting.json. Do not deploy the inherited configuration or use the canonical production database for variant testing.

Do not copy production secrets, local databases, build outputs or dependencies from the canonical workspace. Configure this variant independently.

Preserve baseline provenance and document hackathon changes honestly. Do not claim Nebius inference is implemented until a real runtime integration exists and has been verified.
