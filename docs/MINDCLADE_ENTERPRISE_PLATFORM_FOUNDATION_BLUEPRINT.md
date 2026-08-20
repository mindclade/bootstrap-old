<!-- mindclade-doc: canonical-pointer@1 -->

# Mindclade Enterprise Platform Foundation Blueprint

> **Platform Foundation · Canonical architecture pointer**
> Use the organization-wide blueprint for trust rings, repository authority, production
> invariants, and acceptance gates.

The canonical blueprint is maintained in
[`mindclade/.github`](https://github.com/mindclade/.github/blob/main/docs/MINDCLADE_ENTERPRISE_PLATFORM_FOUNDATION_BLUEPRINT.md).
This compatibility page preserves the established path without duplicating a long-lived
architecture contract that could drift between repositories.

## Bootstrap-specific guidance

- [Bootstrap architecture](architecture.md) defines the current Ring-0 implementation.
- [Repository production blueprint](../BLUEPRINT.md) is the compact authority contract.
- [Documentation home](README.md) routes first apply, handoff, and recovery work.

When repository behavior and the enterprise target differ, treat code, tests,
`contracts/repository.yaml`, and the repository-specific documentation as current evidence;
the enterprise blueprint remains the approved target architecture.
