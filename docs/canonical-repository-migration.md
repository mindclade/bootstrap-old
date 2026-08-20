# Canonical monorepo WIF identity

The supported repository identity is `mindclade/mindclade-internal-monorepo`. The immutable
repository ID is the security boundary; a matching name alone is not sufficient.

`github_repository_ids.mindclade-internal-monorepo` is the canonical input. The canonical
signer provider ID is `gh-mindclade-internal-monorepo`, and its condition requires the canonical
repository name, immutable owner and repository IDs, exact audience, exact `refs/heads/main`
ref, protected `release` environment, and exact v3.0.0 signer workflow.

## Greenfield activation

The documented first activation has no legacy signer provider or legacy Terraform state address.
The provider is created directly at
`google_iam_workload_identity_pool_provider.github["mindclade-internal-monorepo"]`; a
speculative `moved` block is prohibited.

1. Resolve `mindclade/mindclade-internal-monorepo` through the API and record its immutable
   repository database ID.
2. Set `github_repository_ids.mindclade-internal-monorepo` to that ID.
3. Review the plan: it must create only the canonical provider address and must not contain a
   signer-provider move, replacement, or broadened repository-ID condition.
4. Apply through the protected bootstrap environment. Publish the canonical provider output,
   then prove allowed and wrong-repository, wrong-ref, wrong-workflow, wrong-environment, and
   wrong-audience exchanges.

## Existing-state exception

If an estate later contains a signer provider under a different Terraform state address, stop
normal automation and capture `terraform state list`, the remote provider resource name, and its
immutable repository-ID condition through the approved recovery process. Add a `moved` block only
when that evidence proves one exact source and destination address. Never infer a state migration
from a repository name or add compatibility state metadata to a greenfield configuration.

Neither this configuration nor this runbook renames a GitHub repository or applies Terraform.
