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

## Establish an exclusive recovery window

1. Disable or hold every bootstrap apply workflow and record the last completed run. A GitHub
   concurrency group is not evidence that no external operator is writing state.
2. Authenticate through the approved recovery path on encrypted, non-synchronized storage.
3. Export the exact reviewed source commit with the pinned Terraform version and create the
   untracked `terraform.tfvars` needed to reproduce the protected CI inputs.
4. Initialize the authoritative backend, acquire/release its native lock with a read-only plan,
   and retain the current state before selecting any candidate:

```sh
STATE_BUCKET="<bootstrap-state-bucket>"
terraform init -input=false -lockfile=readonly -backend-config="bucket=${STATE_BUCKET}"
terraform plan -input=false -lock-timeout=20m -refresh=false
terraform state pull > current-authoritative.tfstate
python3 -m json.tool current-authoritative.tfstate >/dev/null
sha256sum current-authoritative.tfstate
```

Store the current state and checksum in the access-controlled incident workspace. State is
sensitive even when Terraform outputs are marked sensitive.

## Option 1 — restore an earlier generation

```sh
BUCKET="gs://<bootstrap-state-bucket>"
OBJECT="bootstrap/default.tfstate"

gcloud storage ls --all-versions --long "${BUCKET}/${OBJECT}"
gcloud storage cp "${BUCKET}/${OBJECT}#<generation>" ./candidate.tfstate
python3 -m json.tool candidate.tfstate >/dev/null
```

Initialize an isolated working copy against a temporary backend/prefix or inspect the state
locally. Do not use `gcloud storage cp` to overwrite the authoritative object; that bypasses
Terraform's backend lock and lineage/serial safety checks.

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

## Qualify and promote a candidate

Use a second backend-free export of the same reviewed commit as the isolated candidate workspace.
Place the candidate at `terraform.tfstate`, reproduce the exact protected input values, and plan
without any remote backend:

```sh
CANDIDATE_DIR="<approved-encrypted-candidate-directory>"
cp candidate.tfstate "${CANDIDATE_DIR}/terraform.tfstate"

python3 -m json.tool "${CANDIDATE_DIR}/terraform.tfstate" >/dev/null
jq -e '.version == 4 and (.terraform_version | type == "string") and
       (.serial | type == "number") and
       (.lineage | type == "string" and length > 0)' \
  current-authoritative.tfstate "${CANDIDATE_DIR}/terraform.tfstate" >/dev/null
test "$(jq -r .lineage current-authoritative.tfstate)" = \
     "$(jq -r .lineage "${CANDIDATE_DIR}/terraform.tfstate")"
sha256sum "${CANDIDATE_DIR}/terraform.tfstate"
terraform -chdir="${CANDIDATE_DIR}" init -input=false -lockfile=readonly
terraform -chdir="${CANDIDATE_DIR}" state list > candidate-addresses.txt
terraform -chdir="${CANDIDATE_DIR}" plan -input=false -out=candidate-review.tfplan
terraform -chdir="${CANDIDATE_DIR}" show -no-color candidate-review.tfplan \
  > candidate-review.txt
```

Explain every planned change against Git history and Cloud Audit Logs. Add reviewed import blocks
for live resources created after a stale replica; do not accept replacement of protected buckets,
keys, projects, providers, or service accounts. An independent reviewer must approve the lineage,
serial, state-address inventory, plan, generation, checksum, and imports.

When imports are required, the approved isolated plan must contain only the expected import actions
and no creates, updates, replacements, or deletes. Apply that saved plan to the isolated local state,
then prove a second local plan is empty before promotion:

```sh
terraform -chdir="${CANDIDATE_DIR}" apply -input=false candidate-review.tfplan
terraform -chdir="${CANDIDATE_DIR}" plan -input=false -detailed-exitcode
```

The second command must exit `0`. Exit `2` means the candidate is not qualified. Copy the resulting
`${CANDIDATE_DIR}/terraform.tfstate` back to the incident evidence location and record its checksum;
that post-import file, not the original stale replica, is the promotion candidate.

Only then push through Terraform so the GCS backend lock is held. A prior generation normally has
a lower serial, so `-force` is expected here and is authorized only for the exact independently
reviewed candidate:

```sh
terraform state push -lock-timeout=20m -force "${CANDIDATE_DIR}/terraform.tfstate"
terraform state pull > recovered-authoritative.tfstate
sha256sum recovered-authoritative.tfstate
terraform plan -input=false -lock-timeout=20m -out=recovery-verification.tfplan
```

The verification plan must be empty after any approved imports. If it is not, keep applies frozen.
If the push selected the wrong reviewed candidate and no subsequent writer has run, restore
`current-authoritative.tfstate` with the same locked, independently approved `terraform state push`
procedure; never copy an object directly over `bootstrap/default.tfstate`.

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
