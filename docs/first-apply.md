<!-- mindclade-doc: how-to@1 -->

# Perform the first apply and state migration

> **Audience:** named bootstrap operators establishing Ring 0 in a clean organization.
> **Outcome:** create bootstrap resources once, migrate immediately to protected remote state,
> prove recovery evidence, and activate keyless automation.
> **Risk:** critical—this one-time procedure establishes organization-wide state and trust.

The first apply is the only time this repository may use local Terraform state. The configured
root backend is GCS, so `terraform init -backend=false` is suitable for validation only: it does
not initialize a plan-capable local backend. The first plan and apply therefore run from an
exact clean-commit export that deliberately omits `backend.tf`.

## Prerequisites

- Google Cloud organization and billing ownership.
- A named recovery identity protected by phishing-resistant MFA.
- Immutable numeric GitHub organization and repository IDs.
- Immutable GitHub organization and repository IDs for every WIF subject.
- A secure local workstation and encrypted operations vault.
- No service-account JSON keys.

## 1. Prepare an exact backend-free working directory

Start from the reviewed commit in a clean source checkout. Choose a **new** directory on
approved encrypted, non-cloud-synchronized storage. The helper rejects a dirty checkout, a
moving or abbreviated commit, an existing destination, a destination inside the repository,
symlinks, and any exported Terraform backend block. It exports Git objects rather than copying
the checkout, so local credentials, caches, ignored files, and uncommitted changes cannot enter
the first-apply directory.

```sh
SOURCE_ROOT="$(pwd -P)"
SOURCE_SHA="$(git rev-parse HEAD)"
FIRST_APPLY_DIR="/approved/encrypted/path/bootstrap-first-apply-${SOURCE_SHA}"

make first-apply-workdir \
  SOURCE_SHA="${SOURCE_SHA}" \
  FIRST_APPLY_WORK_DIR="${FIRST_APPLY_DIR}"

test "$(jq -r .source_commit "${FIRST_APPLY_DIR}/.mindclade-first-apply.json")" = "${SOURCE_SHA}"
test "$(jq -r .backend_omitted "${FIRST_APPLY_DIR}/.mindclade-first-apply.json")" = "true"
test ! -e "${FIRST_APPLY_DIR}/backend.tf"
```

Do not use `/tmp`, a cloud-synchronized directory, or the source checkout for live first-apply
state. Keep the directory until remote-state migration and independent verification finish.

## 2. Initialize, plan, and review locally

Create the untracked input file **inside the exported directory**, then use the repository-pinned
toolchain from that directory. Because `backend.tf` is absent, ordinary `terraform init`
initializes Terraform's local backend.

```sh
cp "${FIRST_APPLY_DIR}/terraform.tfvars.example" "${FIRST_APPLY_DIR}/terraform.tfvars"
# Replace every example value without printing secrets or identifiers into shell history.

terraform -chdir="${FIRST_APPLY_DIR}" init -input=false -lockfile=readonly
terraform -chdir="${FIRST_APPLY_DIR}" fmt -check -recursive -diff
terraform -chdir="${FIRST_APPLY_DIR}" validate
terraform -chdir="${FIRST_APPLY_DIR}" plan -input=false -out=bootstrap-first.tfplan
terraform -chdir="${FIRST_APPLY_DIR}" show -no-color bootstrap-first.tfplan \
  > "${FIRST_APPLY_DIR}/bootstrap-first.tfplan.txt"
sha256sum "${FIRST_APPLY_DIR}/bootstrap-first.tfplan"
```

Have a second qualified reviewer verify the source SHA marker and inspect the plan, especially
folder/project placement, IAM, WIF attribute conditions, state-bucket locations, and KMS
locations.

## 3. Apply locally once

```sh
terraform -chdir="${FIRST_APPLY_DIR}" apply -input=false bootstrap-first.tfplan
terraform -chdir="${FIRST_APPLY_DIR}" output -json \
  > "${FIRST_APPLY_DIR}/bootstrap-outputs.json"
```

Store the outputs in the approved encrypted operations vault. They contain identifiers, not
credentials, but still describe Ring-0 infrastructure.

## 4. Add the exact backend and migrate the same state

Read the `state_buckets.bootstrap` output. Export `backend.tf` from the same reviewed source
commit—not from the potentially changed working tree—then migrate the local state in place:

```sh
STATE_BUCKET="<bootstrap-state-bucket>"
REPLICA_BUCKET="<bootstrap-replica-bucket>"

git -C "${SOURCE_ROOT}" show "${SOURCE_SHA}:backend.tf" \
  > "${FIRST_APPLY_DIR}/backend.tf"
terraform -chdir="${FIRST_APPLY_DIR}" init \
  -migrate-state \
  -input=false \
  -lockfile=readonly \
  -backend-config="bucket=${STATE_BUCKET}"
terraform -chdir="${FIRST_APPLY_DIR}" state pull \
  > "${FIRST_APPLY_DIR}/remote-state-verification.json"
terraform -chdir="${FIRST_APPLY_DIR}" plan -input=false -lock-timeout=20m
```

The plan must be empty. Verify the remote state object and version history:

```sh
gcloud storage ls --all-versions "gs://${STATE_BUCKET}/bootstrap/**"
```

After the first scheduled transfer completes, verify that the independently located replica
contains the expected state object and generation:

```sh
gcloud storage ls --all-versions "gs://${REPLICA_BUCKET}/bootstrap/**"
```

Record the primary generation, replica generation, observed replication lag, and successful
lock acquisition/release in the protected bootstrap recovery evidence. A readable bucket is
not sufficient evidence that state locking and restore behavior work.

## 5. Bootstrap the private-module reader

Before `infrastructure-live` can initialize, inject the GitHub App private key into the empty
Ring-0 secret container using `docs/automation-secret-bootstrap.md`. The key payload never
passes through Terraform or GitHub Actions configuration.

Before adding a secret version, verify the user-managed replica and its CMEK are both in
`automation_secret_location`. Do not reuse the state key's multi-region `us` location for this
global Secret Manager resource.

## 6. Destroy local copies

After independent verification:

```sh
test "$(jq -r .source_commit "${FIRST_APPLY_DIR}/.mindclade-first-apply.json")" = "${SOURCE_SHA}"
find "${FIRST_APPLY_DIR}" -maxdepth 2 -type f -print
# After migration and independent verification, securely remove this exact dedicated directory
# using the approved workstation procedure.
```

Confirm no copies remain in shell history, cloud-sync folders, downloads, editor backups, or
unapproved artifact stores.

## 7. Activate native-lock IAM without deadlocking

A greenfield first apply creates the read-only state grant and its typed `.tflock`-only grant
together, before automation takes over. An existing estate may have plan and drift identities
with only `roles/storage.objectViewer`; those identities cannot create the GCS backend lock
object and therefore cannot produce the plan that adds their own lock permission.

For an existing estate, freeze bootstrap changes and use a named, explicitly approved recovery
operator or apply identity that already has bucket object administration to pre-grant the exact
Terraform-managed conditional binding before enabling mandatory locking in plan workflows. The
condition must require both `resource.type == 'storage.googleapis.com/Object'` and a resource
name ending in `.tflock`. Record the approver, bucket, service-account identity, condition, and
audit event. Then run the protected locked plan, apply the exact reviewed change so Terraform
records the binding, and revoke any temporary elevated human grant. Do not remove the
`.tflock` binding itself: it is durable desired state.

Qualification requires a locked plan to succeed, lock creation/deletion to appear in audit
logs, and a direct write by the plan identity to the `.tfstate` object to remain denied. Never
temporarily restore `-lock=false` to work around a failed rollout.

## 8. Enable protected automation

Configure in `github-config`/GitHub Enterprise:

- protected `main` and critical paths;
- protected `plan`, `bootstrap`, `bootstrap-recovery-read`, and `break-glass` environments;
- `WIF_PROVIDER_PLAN` / `WIF_PROVIDER_APPLY`;
- `artifact_release_identities` as the six capability-specific ARC provider/principal
  contracts; `infrastructure-live` binds each only to its matching normal-plane service account;
- `SA_BOOTSTRAP_PLAN`, `SA_BOOTSTRAP_DRIFT`, and `SA_BOOTSTRAP_APPLY`;
- `TFSTATE_BUCKET`, `TFSTATE_REPLICA_BUCKET`, and required non-secret Terraform variables;
- `GH_ORGANIZATION`, `GH_ORGANIZATION_ID`, and `GH_REPOSITORY_IDS_JSON`;
- at least one named human in `BREAK_GLASS_PRINCIPALS_JSON`;
- exact workflow authorization for `.github/workflows/apply.yml`.

Before enabling release signing, protect the monorepo's `main` branch and create the `release`
environment with required reviewers and a protected-branch deployment policy. Then verify a
monorepo token from the exact `refs/heads/main` ref, protected `release` environment, and
`reusable-binauthz-sign.yml@v5.0.0` can exchange through the signer provider. Also record
negative tests showing a builder job, an unprotected ref, a different environment, and a
different reusable workflow are rejected.

Before the first federated speculative plan or scheduled drift run, the protected bootstrap
apply must have granted `roles/browser` at the organization and `roles/billing.viewer` on the
configured billing account to both read identities. These are refresh permissions only:
`bootstrap-plan` and `bootstrap-drift` must not receive Billing Account User, a folder writer,
or an organization administrator role.

Run `plan.yml`, then a no-op protected `apply.yml` execution. Normal changes are Git-mediated
from this point onward.

The `plan` environment is part of the Google Cloud identity, not presentation-only metadata.
Record successful plan token exchange plus failed exchange from an arbitrary workflow and
branch. The scheduled recovery drill authenticates through its separate exact-main workflow
binding while retaining the dedicated governed `bootstrap-recovery-read` environment.

Also verify that a credentialed plan can create and delete only its GCS backend `.tflock`
object. The plan identity must be able to read state and complete with locking enabled, but a
direct write to the `.tfstate` object must remain denied by IAM. The opt-in `inspect-state`
recovery drill permanently checks the negative half of this contract by attempting the exact
`bootstrap/negative-write-probe.tfstate` path and accepting only an explicit IAM denial. It
refuses to overwrite a pre-existing probe; if creation ever succeeds, it immediately attempts
to delete the harmless probe and fails the drill either way.

## Prohibited

Do not enable an irreversible bucket retention lock. State protection is supplied by narrow
IAM, native locking, versioning, soft delete, lifecycle controls, CMEK, and independent
replication.

## Verify

- Remote state and its replica contain the recorded generations and a no-change plan succeeds.
- Native locking is observed in audit logs while direct plan-identity writes to `.tfstate` fail.
- Protected plan/apply and scheduled recovery identities pass their positive and negative WIF tests.
- The private-module reader works without key material entering Terraform or GitHub Actions.
- Local plans, state, output files, and temporary credential material have been securely removed.

If any criterion fails, keep automation disabled and follow [Terraform state recovery](state-recovery.md)
or [break-glass](break-glass.md) as appropriate. Do not repeat the local first apply against an
existing estate.

## Roll back or recover

Before state migration, stop and review the local state and live resources rather than repeating an
apply. After migration, remote state is authoritative: use [Terraform state recovery](state-recovery.md)
to select a verified generation or reconstruct imports. Never copy an older object over remote state
without stopping automation, retaining the current generation, and obtaining independent review.
