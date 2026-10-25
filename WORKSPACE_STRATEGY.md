# Valora and hackathon variants

## Repository ownership

- Canonical product: `Rushikesh0125/valora`, workspace `R:/Projects/valora`.
- Nebius submission: `Rushikesh0125/valora-nebius`, workspace `R:/Projects/valora-nebius`.
- Future submissions: create a separate repository and clone for each substantially different entry. Record the source commit and changes for each event.

Both repositories start from the same baseline history. Changes do not synchronize automatically. Transfer selected generic fixes with reviewed cherry-picks; keep sponsor integrations, branding and submission materials in the relevant repository. Avoid copying entire folders back over the canonical product.

## Isolation requirements

Separate folders isolate source edits, not deployed services. Before deploying any variant, provision its own Worker, D1 database, secrets, OAuth callbacks, app identifiers and hosting target. Never deploy a variant using the canonical Valora resource bindings or landing hosting identity.

Ignored local credentials, build outputs, dependency caches and local databases are deliberately excluded from Git and from new clones. Configure each workspace independently. Do not copy production secrets into hackathon repositories.

Keep repositories private during preparation. Before a submission requiring public source, review assets and credentials, choose an appropriate open-source license and explicitly publish the submission repository. A new name alone does not establish compliance with another event's originality rules.

## Validation

Verify separate Git directories and origins, clean working trees and matching baseline commits after cloning. Application behavior is unchanged by repository setup; this does not verify runtime behavior.
