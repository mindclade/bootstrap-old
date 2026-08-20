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

All changes are pull-request reviewed, subject to CODEOWNERS and required checks, merged through the configured queue for protected repositories, and performed by narrowly scoped identities. Live-system qualification evidence is separate from source completeness.
