<!-- mindclade-doc: governance@1 -->

# Mindclade governance · `bootstrap`

| Document control | Value |
| --- | --- |
| Owner | Mindclade Platform |
| Version | 1.0 |
| Last reviewed | August 21, 2026 |
| Authority | Ring-0 state, automation federation, seed projects, and break-glass recovery |

## Authority boundary

The authoritative scope is declared in
[contracts/repository.yaml](contracts/repository.yaml). This repository creates
the state and identity prerequisites needed to operate the rest of the estate.
It does not own normal folders, org policy, workload projects, networks, GKE,
or Kubernetes desired state.

## Decisions and approvals

Routine changes use a pull request, passing required checks, one approval, and
code-owner review. State, KMS, WIF, break-glass, seed-project, or workflow-
authorization changes require two qualified approvals and explicit recovery
evidence. The protected apply environment authorizes only the exact reviewed
main-branch plan.

## Evidence and publication

The pull request must identify creates, replacements, destroys, trust changes,
blast radius, rollback or recovery, and exact validation commands. A speculative
plan informs review; it is not authorization to apply. Apply evidence must bind
the plan, commit, actor, and protected environment.

## Exceptions and review

Break-glass is for recovery, never routine change. Each use is time-bounded,
alerted, recorded, and reviewed after the event. It does not waive security,
confidentiality, licensing, or evidence requirements.

State recovery and identity are reviewed quarterly. A cold-start recovery drill
is executed at least annually by a qualified operator who did not author the
procedure. Organization-wide defaults are defined in
[`mindclade/.github/GOVERNANCE.md`](https://github.com/mindclade/.github/blob/main/GOVERNANCE.md).

