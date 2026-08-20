# Terraform state recovery

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

## Option 2 — recover from the independent replica

```sh
REPLICA="gs://<bootstrap-replica-bucket>"
gcloud storage ls --all-versions "${REPLICA}/bootstrap/**"
gcloud storage cp "${REPLICA}/bootstrap/default.tfstate" ./candidate.tfstate
```

The replica can be up to one transfer interval stale. Compare Cloud Audit Logs and Git history
to identify resources created after the replicated generation, then import those resources
before any apply.

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

## Completion

- run a no-change plan;
- verify state object generations and replica health;
- review audit logs;
- record the incident and exact recovered generation;
- update `test/clean-room-recovery.md` if the drill did not cover the failure.
