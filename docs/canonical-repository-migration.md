# Canonical monorepo WIF identity

The supported repository identity is `mindclade/mindclade-internal-monorepo`. The immutable
repository ID is the security boundary; a matching name alone is not sufficient.

`github_repository_ids.mindclade-internal-monorepo` is the canonical input. The canonical
signer provider ID is `gh-mindclade-internal-monorepo`, and its condition requires the canonical
repository name, immutable owner and repository IDs, exact audience, protected `release`
environment, and exact v3.0.0 signer workflow.

Migration sequence:

1. Resolve `mindclade/mindclade-internal-monorepo` through the API and record its immutable
   repository database ID. Stop if an old `mindclade` state address points to a different ID.
2. Set `github_repository_ids.mindclade-internal-monorepo` to that ID.
3. Review the plan: any compatibility resource must move back to the canonical
   `github["mindclade-internal-monorepo"]` address, and no repository-ID condition may broaden.
4. Apply through the protected bootstrap environment. Publish the canonical provider output,
   then prove allowed and wrong-repository, wrong-workflow, wrong-environment, and
   wrong-audience exchanges.

Neither this configuration nor this runbook renames a GitHub repository or applies Terraform.
