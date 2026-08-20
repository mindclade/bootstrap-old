# Credential and trust rotation

Normal automation is keyless. Rotate trust by changing WIF providers, repository IDs,
service-account bindings, and protected-environment policy—not by distributing JSON keys.

The `bootstrap-plan`, `github-config-plan`, and `infrastructure-live-plan` accounts are bound to
their repository's exact immutable `OWNER@OWNER-ID/REPO@REPO-ID:environment:plan` OIDC
subject. Keep each protected `plan` environment, every plan job's `environment: plan`
declaration, the immutable IDs, and the matching binding synchronized. Do not broaden any of
them back to a repository-wide or legacy name-only principal during rotation.

Scheduled read-only jobs do not wait for plan-environment review. They receive separate exact
`workflow_ref@refs/heads/main` bindings only for:

- `bootstrap/.github/workflows/recovery-drill.yml` on `bootstrap-plan`;
- `bootstrap/.github/workflows/drift.yml` on `bootstrap-drift`;
- `github-config/.github/workflows/{drift,idp-sync}.yml` on `github-config-plan`; and
- `infrastructure-live/.github/workflows/drift.yml` on `infrastructure-live-plan`.

A feature branch, renamed workflow, additional scheduled workflow, or arbitrary workflow in
the same repository must fail token exchange. Add new consumers explicitly and retain a
negative preflight result with the approved trust change.

After a GitHub repository transfer or recreation:

1. obtain its new immutable repository ID;
2. update `github_repository_ids`;
3. apply bootstrap through the protected environment;
4. run WIF preflight from the repository;
5. revoke the old provider/binding;
6. review token-exchange audit logs.

The monorepo provider is a signer-only path. Its provider condition must require all of:

- immutable owner and monorepo repository IDs;
- `repo:mindclade@<owner-id>/mindclade-internal-monorepo@<repository-id>:environment:release`
  as the exact immutable subject;
- `mindclade/.github/.github/workflows/reusable-binauthz-sign.yml@refs/tags/v3.0.0`
  as the exact `job_workflow_ref`; and
- the provider-specific audience.

When the reusable signer workflow is released at a new protected tag, change bootstrap trust
first, verify allowed and denied token exchanges, then update callers. Never temporarily widen
the condition to a branch, repository-wide principal, or wildcard workflow. The builder and
qualifier use separate Buildkite trust and must never receive the exported signer principal.

Buildkite federation has an exact token-generation contract. Every Google Cloud credential
exchange must request:

```sh
buildkite-agent oidc request-token \
  --audience "$BUILDKITE_WIF_PROVIDER" \
  --subject-claim pipeline_id \
  --claim organization_id \
  --format gcp
```

The provider maps the immutable pipeline UUID to `google.subject`, requires the separately
included organization UUID, allowlists the pipeline UUID, and requires the exact audience.
Do not use Buildkite's default compound subject: organization, pipeline, ref, commit, and step
can exceed Google Cloud's 127-byte mapped-subject limit. Step-level service-account bindings
remain an additional restriction. Treat any pipeline that does not request this exact token
shape as denied, then prove positive and wrong-pipeline/wrong-step exchanges before activation.

After break-glass use, remove temporary IAM grants, review audit logs, rotate any exposed
recovery material, and record a post-incident review.
