# Agent operating guide

## Purpose and authority

This repository is Ring 0. It owns state foundations, initial automation federation, seed
projects, and break-glass recovery. Read BLUEPRINT.md, README.md, and CONTRIBUTING.md before
editing. Normal organization infrastructure belongs in infrastructure-live; Kubernetes desired
state belongs in gitops.

## Working rules

- Keep state, WIF, recovery, and automation identities minimal and independently recoverable.
- Never add service-account keys, local state, plan files, credentials, or sensitive outputs.
- Do not apply, migrate state, activate break-glass access, or change live trust from an agent
  session. Produce reviewed source and explicit operator steps.
- Preserve prevent-destroy and recovery controls. Any address or trust migration needs a
  rollback/recovery plan and qualified review.
- Keep reusable Google Cloud modules in mindclade-internal-monorepo.

## Validation

Run the pinned source checks:

    nix develop .#ci --command make validate
    nix flake check --no-update-lock-file

Connected state locking, WIF exchange, first-apply, and recovery drills are separate protected
qualification gates and must not be inferred from local success.

## Done

The smallest relevant checks pass, documentation and contracts match the change, rollback is
documented for trust/state changes, and every unavailable connected check is called out.
