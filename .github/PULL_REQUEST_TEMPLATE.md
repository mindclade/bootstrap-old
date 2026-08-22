## Ring-0 change

Describe the outcome, affected state or identity boundary, and why the change
belongs in `bootstrap`.

## Risk and authority

- Change class: routine / high / critical
- State, KMS, WIF, seed-project, break-glass, or workflow impact:
- Creates, replacements, and destroys:
- Named recovery operator:
- Required approvers:

## Validation evidence

List the exact commands and results, then link the access-controlled plan
artifact. Do not paste state or raw plan values.

```text
nix develop --command make validate
nix develop --command make lint
```

## Recovery

State how the exact reviewed change is rolled back or recovered if state,
identity, KMS, or the protected workflow is unavailable.

## Checklist

- [ ] The applied plan will be generated from and bound to the reviewed main SHA.
- [ ] State, KMS, and recovery safeguards remain intact.
- [ ] No credential, private key, state, plan, or sensitive value is committed.
- [ ] Critical changes have two qualified approvals and code-owner review.

## Contributor authorization

- [ ] I am authorized under a current written agreement with Mindclade, LLC. to
      submit every part of this contribution.
- [ ] I identified every third-party component, specification, or generated
      artifact and preserved its source, license, provenance, and notices.
- [ ] I updated `LICENSE`, `NOTICE`, the SBOM, or other license evidence when
      the included or distributed material changed.

