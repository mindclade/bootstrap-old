<!-- mindclade-doc: runbook@1 -->

# Terraform state recovery

> **Use when:** Ring-0 Terraform state is missing, corrupt, stale, or inaccessible.
> **Impact:** an incorrect recovery can orphan or replace organization-level resources.
> **Primary owner:** bootstrap recovery operator with an independent reviewer.
> **Escalate:** use [break-glass](break-glass.md) only when ordinary recovery access is insufficient.

This runbook covers Ring-0 bootstrap state only. Stop all applies before beginning.

## Safety rules

- Do not apply against missing or partial state.
- Copy the damaged state before attempting repair.
- Recover into an isolated local file or temporary object first.
- Inspect and plan before replacing the authoritative object.
- Use break-glass only when ordinary read/recovery identities cannot perform the operation.

## Option 1 — restore an earlier generation

```sh
BUCKET="gs://<bootstrap-state-bucket>"
OBJECT="bootstrap/default.tfstate"

gcloud storage ls --all-versions --long "${BUCKET}/${OBJECT}"
gcloud storage cp "${BUCKET}/${OBJECT}#<generation>" ./candidate.tfstate
python3 -m json.tool candidate.tfstate >/dev/null
```

Initialize an isolated working copy against a temporary backend/prefix or inspect the state
locally. After selecting the correct generation, copy it to the authoritative object and run a
read-only plan. Expect no changes.

## Option 2 — recover from an independent replica

```sh
REPLICA="gs://<bootstrap-replica-bucket>"
gcloud storage ls --all-versions "${REPLICA}/bootstrap/**"
gcloud storage cp "${REPLICA}/bootstrap/default.tfstate" ./candidate.tfstate
```

Use the authoritative U.S. bucket from `state_replica_buckets` first. During the additive
migration, `legacy_state_replica_buckets` exposes the preserved Europe copy as a secondary
recovery source. Record which output, location, object generation, and CMEK produced the
candidate. Never choose between copies only by timestamp.

A replica can be up to one transfer interval stale. Compare Cloud Audit Logs and Git history
to identify resources created after the replicated generation, then import those resources
before any apply.

The replica is independent by location, not by organization, seed project, KMS administration,
or bootstrap apply authority. Treat a compromise of those shared control surfaces as a scenario
that may require state reconstruction from live resources or a separately protected evidence
backup.

## Option 3 — reconstruct state from live resources

Use Cloud Asset Inventory to enumerate only bootstrap-owned resources:

```sh
gcloud asset search-all-resources \
  --scope="organizations/${ORG_ID}" \
  --asset-types="cloudresourcemanager.googleapis.com/Folder,cloudresourcemanager.googleapis.com/Project,storage.googleapis.com/Bucket,iam.googleapis.com/ServiceAccount,cloudkms.googleapis.com/CryptoKey" \
  --format="table(name,assetType)"
```

Use reviewable Terraform `import` blocks and work in dependency order:

1. bootstrap folder;
2. seed and CI federation projects;
3. enabled APIs and KMS resources;
4. WIF pools/providers and service accounts;
5. state buckets, IAM, and transfer jobs;
6. break-glass alert resources.

Useful import ID forms:

| Resource | Import ID |
|---|---|
| `google_folder` | `folders/123456789012` |
| `google_project` | `project-id` |
| `google_storage_bucket` | `bucket-name` |
| `google_service_account` | `projects/PROJECT/serviceAccounts/EMAIL` |
| `google_iam_workload_identity_pool` | `projects/PROJECT/locations/global/workloadIdentityPools/POOL` |
| `google_kms_crypto_key` | `projects/P/locations/L/keyRings/R/cryptoKeys/K` |

The random suffix is part of existing project/bucket names. Preserve it; do not regenerate
names and accidentally plan replacement.

## Corrupt JSON

```sh
terraform state pull > current.tfstate
python3 -m json.tool current.tfstate >/dev/null
```

Do not hand-edit malformed state while a valid version or replica exists.

## Stale lock

```sh
terraform force-unlock <LOCK_ID>
```

Force-unlock only after proving no plan/apply still owns the lock.

## Verify recovery

- run a no-change plan;
- verify state object generations and replica health;
- record observed replication lag and the exact primary/replica generations inspected;
- review audit logs;
- record the incident and exact recovered generation;
- update `test/clean-room-recovery.md` if the drill did not cover the failure.

Do not resume protected applies until the reviewer accepts the no-change plan, state generation,
replica comparison, and audit evidence. Escalate unresolved ownership, unexplained drift, or a
primary/replica mismatch to the incident commander rather than selecting the newest object by
timestamp alone.

## Escalation and handoff

Hand the incident commander the affected bucket/object, every inspected generation, replica lag,
audit timeline, imports, state mutations, no-change plan, reviewers, and remaining drift. Escalate a
missing generation, unexplained live resource, or suspected control-plane compromise before
restoring any candidate.
