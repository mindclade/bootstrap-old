<!-- mindclade-doc: runbook@1 -->

# Migrate Terraform state replicas to us-east4

> **Use when:** reconciling the deployed Europe recovery estate with the `us-only-v1`
> platform contract.
> **Impact:** Ring-0 recovery topology changes; primary state is not moved.
> **Primary owner:** bootstrap recovery operator with an independent reviewer.
> **No-go:** any plan that deletes or replaces a bucket, key ring, crypto key, transfer job,
> state object, or IAM binding.

This migration is additive. Existing `europe-west4` buckets, CMEK, transfer jobs, and read-only
recovery access remain Terraform-managed under explicit `legacy` addresses. New `us-east4`
resources use distinct immutable bucket names and location-scoped KMS identities. The supported
platform contract points only to the U.S. replicas after the protected apply.

## Preconditions

- The exact source revision and protected plan are reviewed.
- Primary and legacy replica state generations are recorded.
- The current legacy transfer jobs have a recent successful run.
- The U.S. recovery region and CMEK location are both `us-east4`.
- A named recovery operator and independent reviewer own the change window.

## Plan acceptance

Run only the protected pull-request plan. Accept the plan only when:

- all existing replica, key, IAM, and transfer-job addresses move to their `legacy` addresses
  without remote-object changes;
- changes contain creates for the U.S. key ring/key, five U.S. buckets, sink IAM, recovery read
  access, and five transfer jobs;
- deletes and replacements are exactly zero; and
- no primary state, backend, WIF, organization IAM, billing IAM, or break-glass resource changes.

Abort on an unknown value that prevents those counts from being proven. Never remove
`prevent_destroy`, edit state manually, or use `terraform state rm` to make the plan pass.

## Apply and populate

After protected approval, apply the exact integrity-checked plan through
`.github/workflows/apply.yml`. Do not apply from a workstation. Allow each new transfer job to
complete before treating its bucket as a recovery source.

Record for every state scope:

1. primary object generation and checksum;
2. U.S. replica object generation and checksum;
3. observed replication lag;
4. CMEK identity and enabled key version;
5. successful read through the protected recovery identity; and
6. audit evidence for copy and read operations.

The migration is incomplete if any scope is absent, stale beyond the objective, unreadable, or
encrypted by a different key.

## Recovery qualification

Use an isolated recovery environment to copy one selected U.S. replica generation, validate its
JSON, initialize against a temporary prefix, and prove a no-change plan or an explicitly reviewed
import delta. Do not point a drill at the authoritative backend. Capture measured RPO and RTO in
the approved DR evidence destination.

## Legacy disposition

Keep `preserve_legacy_eu_state_replicas = true` until all U.S. scopes pass recovery qualification
and the retention period approved by Legal, Security, and Platform has elapsed. Decommissioning
requires a separate reviewed procedure that:

- retains final generation/checksum and transfer history evidence;
- disables legacy transfer jobs before considering bucket disposition;
- proves no runbook or consumer references legacy outputs;
- handles KMS key and bucket retention requirements; and
- uses an explicitly approved state transition without weakening `prevent_destroy`.

This migration does not authorize legacy deletion.

## Rollback

Before apply, close the change and retain the existing legacy estate. After U.S. resources are
created, rollback means stop their transfer jobs and investigate while leaving both recovery
copies intact. Never roll back by deleting a bucket, key, or state generation.

## Completion evidence

- exact merged commit and protected apply run;
- accepted create-only plan and plan digest;
- primary/U.S./legacy generation inventory;
- U.S. CMEK and transfer-job identities;
- measured RPO/RTO and recovery-test result;
- approvers, operators, timestamps, and next drill date; and
- an owned corrective action for every failed or missing check.
