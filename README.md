<!-- mindclade-doc: repository-home@2 -->
<!-- Brand source: mindclade/.github-private/mindclade-brand-assets (MC family). -->

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)"
            srcset="docs/assets/brand/mc-lockup-horizontal-dark-1520w.png">
    <source media="(prefers-color-scheme: light)"
            srcset="docs/assets/brand/mc-lockup-horizontal-1520w.png">
    <img alt="Mindclade" src="docs/assets/brand/mc-lockup-horizontal-1520w.png" width="380">
  </picture>
</p>

# Mindclade · Bootstrap

> **Platform Foundation · Ring 0**
> Durable state, seed projects, workload federation, automation identities, and audited
> break-glass recovery for the Mindclade control plane.

<p align="center">
  <img alt="class: enterprise-control"
       src="https://img.shields.io/badge/class-enterprise--control-B5673F?style=flat-square&labelColor=201C24">
  <img alt="ring: 0"
       src="https://img.shields.io/badge/ring-0-B5673F?style=flat-square&labelColor=201C24">
  <img alt="terraform: 1.9.x"
       src="https://img.shields.io/badge/terraform-1.9.x-B5673F?style=flat-square&labelColor=201C24">
  <img alt="license: proprietary"
       src="https://img.shields.io/badge/license-proprietary-5B5660?style=flat-square&labelColor=201C24">
</p>

| Repository contract | Value |
| --- | --- |
| Enterprise | [`mindclade`](https://github.com/enterprises/mindclade) |
| Organization | [`mindclade`](https://github.com/mindclade) |
| Repository index | [Mindclade repositories](https://github.com/orgs/mindclade/repositories) |
| Repository | [`mindclade/bootstrap`](https://github.com/mindclade/bootstrap) |
| Class | `enterprise-control` |
| Visibility | `private` |
| Change model | Pull request to `main`; protected exact-plan apply |
| Documentation | [`docs/README.md`](docs/README.md) |

Mindclade's **Ring-0** repository owns only the durable state, seed projects, external
workload federation, control-plane automation identities, and break-glass recovery needed
to operate the rest of the enterprise platform.

## Authority boundary

### This repository creates

- a protected bootstrap folder;
- a seed/state project and CI federation project;
- primary and cross-location replica state buckets with location-compatible CMEKs;
- repository-isolated GitHub Actions WIF providers;
- a no-standing-permission break-glass account with critical alerting.

### This repository does not create

- normal organization folders, policy, billing governance, SCC, contacts, or log sinks;
- networks, workload projects, managed services, or GKE;
- Argo CD, Kubernetes desired state, or application source.

Those authorities remain in `infrastructure-live`, `gitops`, and the internal monorepo.
## Authority boundary

### This repository creates

- a protected bootstrap folder;
- a seed/state project and CI federation project;
- primary and cross-location replica state buckets with location-compatible CMEKs;
- repository-isolated GitHub Actions WIF providers;
- a signer-only monorepo provider restricted to the protected `release` environment and the
  immutable `reusable-binauthz-sign.yml@v3.0.0` workflow identity;
- optional UUID-scoped Buildkite WIF;
- separate bootstrap, GitHub-governance, and infrastructure-live automation identities;
- an empty CMEK-protected module-reader secret container required for clean-room infrastructure initialization;
- a no-standing-permission break-glass account with critical alerting.

### This repository does not create

- normal organization folders, policy, billing governance, SCC, contacts, or log sinks;
- networks, workload projects, managed services, or GKE; or
- artifact signer accounts, KMS signing keys, attestors, or their normal-plane IAM roles; or
- Argo CD, Kubernetes desired state, or application source.

Those authorities remain in `infrastructure-live`, `gitops`, and the internal monorepo.

## Quick start

The safe first action is validation, not planning or applying:

```sh
nix develop
make validate
make lint
make fmt-check
```

The flake intentionally supports `x86_64-linux`, `aarch64-linux`, and
`aarch64-darwin`. Its CI shell is the minimal validation closure; the default shell adds
Terraform and operator tooling. NixOS, nix-darwin, and Home Manager host configuration remain
outside this Ring-0 repository's authority.

Expected result: shell, Terraform, WIF-policy, local-state, repository-contract, and
license checks pass. `make plan-local` is reserved for the documented first apply or
recovery path.

## Lifecycle

1. Export the exact reviewed commit to a dedicated encrypted work directory without
   `backend.tf`, then perform the one-time local-backend first apply there.
2. Migrate local state to the generated GCS bootstrap state bucket.
3. Securely destroy local state and plan copies.
4. Configure repository variables and the protected `plan`, `bootstrap`, and recovery-read
   GitHub environments.
5. All subsequent plans and applies use keyless GitHub OIDC and exact-plan approval.

## Commands

```sh
make validate
make lint
make fmt-check
make fmt
make first-apply-workdir SOURCE_SHA=<full-sha> FIRST_APPLY_WORK_DIR=<new-path>
```

## Repository map

| Path | Responsibility |
| --- | --- |
| `modules/projects/` | Bootstrap folder, seed/state project, CI federation project, APIs, KMS |
| `modules/identity/` | WIF providers, automation accounts, break-glass controls |
| `modules/state/` | State buckets, IAM, retention controls, and replication |
| `contracts/` | Supported output and repository authority contracts |
| `.github/workflows/` | Plan, protected apply, drift, validation, recovery-drill automation |
| `docs/` | First apply, operations, handoff, and recovery procedures |

## Documentation and safety

Start at the [documentation home](docs/README.md). Read the
[first-apply](docs/first-apply.md), [break-glass](docs/break-glass.md),
[state-recovery](docs/state-recovery.md), and
[automation-secret-bootstrap](docs/automation-secret-bootstrap.md) procedures before touching
live Ring-0 state.

Cloud Identity directory reads use the separately governed
[authorization handoff](docs/cloud-identity-authorization.md); they are not organization IAM.

Never commit local state, saved plans, credentials, private keys, or production tfvars. Report
vulnerabilities through [the security policy](SECURITY.md), never a public issue.

## Security

**Do not open a public issue for a vulnerability.** Report through
[a private security advisory](https://github.com/mindclade/bootstrap/security/advisories/new)
or `security@mindclade.com`. Acknowledgement within 2 business days, triage within 5. Full
policy: [`SECURITY.md`](SECURITY.md).

## License

`LicenseRef-Mindclade-Proprietary` — see [`LICENSE`](LICENSE). First-party configuration
and policy files carry the shared header defined in
[`license-header.txt`](license-header.txt).

## Related repositories

| Repository | Holds |
| --- | --- |
| [`infrastructure-live`](https://github.com/mindclade/infrastructure-live) | Folders, org policy, governance, networks, workload projects |
| [`gitops`](https://github.com/mindclade/gitops) | Argo CD and Kubernetes desired state |
| [`.github`](https://github.com/mindclade/.github) | Organization-wide conventions and canonical policies |

---

