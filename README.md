# `bootstrap`

Mindclade's **Ring-0** repository. It owns only the durable state, seed projects, external
workload federation, control-plane automation identities, and break-glass recovery needed to
operate the rest of the enterprise platform.

It does not own normal folders, organization policy, billing governance, Essential Contacts,
SCC, normal log sinks, networks, workload projects, GKE, or Kubernetes. Those belong to
`infrastructure-live` and `gitops`.

## What it creates

- a protected bootstrap folder;
- a seed/state project and CI federation project;
- primary and cross-location replica state buckets with location-compatible CMEKs;
- repository-isolated GitHub Actions WIF providers;
- optional UUID-scoped Buildkite WIF;
- separate bootstrap, GitHub-governance, and infrastructure-live automation identities;
- an empty CMEK-protected module-reader secret container required for clean-room infrastructure initialization;
- a no-standing-permission break-glass account with critical alerting.

## Lifecycle

1. Perform the one-time first apply with `terraform init -backend=false`.
2. Migrate local state to the generated GCS bootstrap state bucket.
3. Securely destroy local state and plan copies.
4. Configure repository variables and the protected `bootstrap` GitHub environment.
5. All subsequent plans and applies use keyless GitHub OIDC and exact-plan approval.

## Commands

```sh
make validate
make fmt
make plan-local       # only during documented recovery/first apply
```

Read `BLUEPRINT.md`, `docs/first-apply.md`, `docs/break-glass.md`, and
`docs/state-recovery.md`, and `docs/automation-secret-bootstrap.md` before touching live Ring-0 state.
