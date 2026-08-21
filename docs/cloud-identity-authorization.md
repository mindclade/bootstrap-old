<!-- mindclade-doc: security-control@1 -->

# Cloud Identity export authorization

The `github-config-plan` service account receives no Cloud Identity role through Google Cloud
Resource Manager IAM. `roles/cloudidentity.groups.readonly` is not supported on an organization
resource, and adding it to `google_organization_iam_member` makes bootstrap apply fail.

Workload Identity Federation authenticates `github-config` as that service account, but the
Cloud Identity Groups API authorizes directory reads through Google Workspace/Cloud Identity
administration. These are separate control planes.

## Current fail-closed path

Until a directory authorization path is separately approved, a designated Cloud Identity or
Google Workspace administrator performs the export from a clean `github-config` checkout with
end-user OAuth credentials:

```sh
nix develop --command python3 scripts/export-idp-groups.py --apply
```

The operator reviews `idp/team-members.json`, commits only that generated file through a pull
request, and records the directory audit evidence. CI never receives the human credential. The
scheduled `idp-sync` job is expected to fail closed when directory access is absent; it cannot
write the repository or remove organization members.

## Optional automated path

Automation requires an explicit Google Workspace/Cloud Identity change outside Terraform:

1. Prefer service-account authorization without domain-wide delegation so directory audit logs
   retain the service-account actor.
2. A Workspace super administrator assigns only the approved delegated administrator role or
   exact group ownership needed by the enumerated groups.
3. Prove both group-membership reads and the user custom-schema lookup used by
   `export-idp-groups.py`. Group ownership alone does not authorize unrelated user-directory
   reads.
4. Record positive reads for the named groups and negative reads outside scope before enabling
   scheduled automation.

Do not create a service-account key. Domain-wide delegation is not the default: it permits broad
user impersonation and requires a separate security review, exact OAuth scopes, a dedicated
low-privilege delegated administrator, audit evidence, and an implementation that does not
exist in the current workflow.

## Verification

- Bootstrap contains no Cloud Identity role in an organization IAM binding.
- `github-config-plan` retains only its documented Google Cloud read permissions.
- Manual exports are reviewed and attributable to a named administrator.
- Automated export remains disabled or fail-closed until both required directory APIs pass
  positive and negative authorization tests.
