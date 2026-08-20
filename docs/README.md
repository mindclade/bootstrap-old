<!-- mindclade-doc: documentation-home@1 -->

# Mindclade · Bootstrap documentation

> **Platform Foundation · Ring 0**  
> Create, operate, and recover the durable state and trust needed by every higher platform
> layer.

## Choose your path

| If you need to... | Start with | You will... |
| --- | --- | --- |
| Understand Ring 0 | [Architecture](architecture.md) | Learn the ownership boundary, identity flow, and failure domains |
| Create Ring 0 for the first time | [First apply](first-apply.md) | Build the seed resources and migrate local state safely |
| Recover damaged state | [State recovery](state-recovery.md) | Restore a prior generation, replica, or reconstructed state |
| Use emergency access | [Break-glass](break-glass.md) | Grant, use, revoke, and review time-bound recovery access |
| Rebuild the platform from zero | [Cold-start recovery](cold-start.md) | Restore control repositories in dependency order |
| Plan and evidence recovery drills | [DR drill program](drill-program.md) | Use defined objectives, protected two-operator dispatch, and immutable reports |

## Getting started and handoff

- [Initial import and activation](initial-import.md) — import, validate, and prepare the
  repository without enabling automation prematurely.
- [First apply and state migration](first-apply.md) — the only supported local-state apply.
- [Automation secret bootstrap](automation-secret-bootstrap.md) — inject the first private
  module-reader credential without passing it through Terraform.
- [Cloud Identity export authorization](cloud-identity-authorization.md) — keep directory reads
  outside unsupported organization IAM and define the fail-closed/manual handoff.
- [Ownership handoff](ownership-handoff.md) — migrate non-Ring-0 resources into
  `infrastructure-live` without dual ownership.

## Operations and recovery

- [Break-glass](break-glass.md) — audited emergency elevation.
- [State recovery](state-recovery.md) — state restoration and reconstruction.
- [Credential and trust rotation](credential-rotation.md) — rotate keyless trust after a
  repository identity change or incident.
- [Ring-0 disaster recovery](disaster-recovery.md) — incident-level recovery entry point.
- [DR drill program](drill-program.md) — estate schedule, objectives, operator separation, and
  report/evidence acceptance criteria.
- [Clean-room recovery drill](../test/clean-room-recovery.md) — validate recovery on an
  isolated workstation.
- [Scratch-organization drill](../test/scratch-org-drill.md) — prove the documentation works
  without author assistance.

## Reference and governance

- [Bootstrap contracts](../contracts/README.md) — supported machine-readable output boundary.
- [Repository production blueprint](../BLUEPRINT.md) — authority and exclusions.
- [Enterprise platform foundation blueprint](MINDCLADE_ENTERPRISE_PLATFORM_FOUNDATION_BLUEPRINT.md)
  — estate-wide architecture and acceptance gates.
- [Contributing](../CONTRIBUTING.md) and [security](../SECURITY.md) — review and handling rules.

## Source of truth

Terraform resources and outputs, `contracts/outputs.schema.json`, protected workflows, and
`contracts/repository.yaml` are authoritative. The first-apply, state-recovery, and break-glass
procedures explain those artifacts and must be re-qualified when their implementation changes.

## Validate documentation changes

Run from the repository root:

```sh
nix develop
make validate
terraform fmt -check -recursive -diff
```

Check local links and execute changed recovery procedures only in the documented scratch or
isolated environment. New pages follow the canonical
[Mindclade documentation templates](https://github.com/mindclade/.github/tree/main/docs/templates).
