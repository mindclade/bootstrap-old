# bootstrap production blueprint

**Repository class:** `enterprise-control`  
**Visibility:** `private`  
**Default branch:** `main`

## Authoritative responsibilities

- `ring0-state`
- `automation-federation`
- `seed-projects`
- `break-glass-recovery`

## Explicit exclusions

- `normal-folders`
- `normal-org-policy`
- `workload-projects`
- `networks`
- `gke`
- `kubernetes-desired-state`

## Operating invariant

All changes are pull-request reviewed, subject to CODEOWNERS and required checks, and performed by narrowly scoped identities. The enterprise-control class deliberately does not use the production merge queue; its critical changes require qualified independent approvals instead. Live-system qualification evidence is separate from source completeness.
