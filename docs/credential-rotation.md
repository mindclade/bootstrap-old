<!-- mindclade-doc: how-to@1 -->

# Rotate automation trust

> **Audience:** platform and security engineers rotating federated CI trust.
> **Outcome:** move each consumer to a new immutable trust binding while preserving negative
> authorization guarantees and leaving no legacy principal active.
> **Risk:** critical—an overly broad binding can grant unintended cloud automation authority.

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
- `refs/heads/main` as the exact `ref`;
- `mindclade/.github/.github/workflows/reusable-binauthz-sign.yml@refs/tags/v5.0.0`
  as the exact `job_workflow_ref`; and
- the provider-specific audience.

When the reusable signer workflow is released at a new protected tag, change bootstrap trust
first, verify allowed and denied token exchanges, then update callers. Never temporarily widen
the condition to another ref, a repository-wide principal, or a wildcard workflow. The builder
and qualifier use separate ARC capability providers and must never receive the exported signer principal.

The deprecated Buildkite source is permanently disabled and retained only through the ARC
acceptance window. Historical recovery evidence used this token-generation contract. Every
Google Cloud credential
exchange must request:

```sh
buildkite-agent oidc request-token \
  --audience "$BUILDKITE_WIF_PROVIDER" \
  --subject-claim pipeline_id \
  --claim organization_id \
  --format gcp
```

The provider maps the immutable pipeline UUID to `google.subject`, requires the separately
included organization UUID, allowlists the exact pipeline-ID/step-key pair, requires a
  `self-hosted` runner on `main` from a webhook build, and requires the exact audience.
Do not use Buildkite's default compound subject: organization, pipeline, ref, commit, and step
can exceed Google Cloud's 127-byte mapped-subject limit. Step-level service-account bindings
remain an additional restriction. Treat any pipeline that does not request this exact token
shape as denied, then prove positive and wrong-pipeline/wrong-step exchanges before activation.

After break-glass use, remove temporary IAM grants, review audit logs, rotate any exposed
recovery material, and record a post-incident review.

## Verify

- Every intended consumer succeeds with the new exact subject, workflow, environment, and audience.
- Wrong-repository, wrong-workflow, wrong-environment, and wrong-audience exchanges remain denied.
- Old providers and IAM bindings are revoked after the new path is proven.
- Token-exchange audit evidence and the protected change are linked in the rotation record.

Run `make validate` before merging configuration changes. If the new path cannot be proven without
broadening a condition, stop and escalate to the security owner; do not use a wildcard as a
temporary bridge.

## Roll back or recover

Keep the previous provider and binding only for the approved overlap window. If the new exact
consumer fails, return callers to the last known-good binding, preserve positive and negative
exchange evidence, and correct the new trust definition before retrying. Never restore a revoked
credential suspected of compromise; use [break-glass](break-glass.md) under an incident instead.
