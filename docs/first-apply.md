# First apply and state migration

The first apply is the only time this repository may use local Terraform state.

## Prerequisites

- Google Cloud organization and billing ownership.
- A named recovery identity protected by phishing-resistant MFA.
- Immutable numeric GitHub organization and repository IDs.
- Immutable Buildkite organization/pipeline UUIDs if Buildkite WIF is enabled.
- A secure local workstation and encrypted operations vault.
- No service-account JSON keys.

## 1. Prepare and review

```sh
cp terraform.tfvars.example terraform.tfvars
# Replace every example value; terraform.tfvars remains untracked.
terraform init -backend=false -input=false
terraform fmt -check -recursive -diff
terraform validate
terraform plan -out=bootstrap-first.tfplan
terraform show -no-color bootstrap-first.tfplan > bootstrap-first.tfplan.txt
sha256sum bootstrap-first.tfplan
```

Have a second qualified reviewer inspect the plan, especially folder/project placement, IAM,
WIF attribute conditions, state-bucket locations, and KMS locations.

## 2. Apply locally once

```sh
terraform apply bootstrap-first.tfplan
terraform output -json > bootstrap-outputs.json
```

Store the outputs in the approved encrypted operations vault. They contain identifiers, not
credentials, but still describe Ring-0 infrastructure.

## 3. Migrate to remote state

Read the `state_buckets.bootstrap` output and run:

```sh
STATE_BUCKET="<bootstrap-state-bucket>"
REPLICA_BUCKET="<bootstrap-replica-bucket>"
terraform init -migrate-state -input=false -backend-config="bucket=${STATE_BUCKET}"
terraform state pull > remote-state-verification.json
terraform plan -lock-timeout=20m
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

## 4. Bootstrap the private-module reader

Before `infrastructure-live` can initialize, inject the GitHub App private key into the empty
Ring-0 secret container using `docs/automation-secret-bootstrap.md`. The key payload never
passes through Terraform or GitHub Actions configuration.

## 5. Destroy local copies

After independent verification:

```sh
rm -f terraform.tfstate terraform.tfstate.backup
rm -f bootstrap-first.tfplan bootstrap-first.tfplan.txt
rm -f bootstrap-outputs.json remote-state-verification.json
```

Confirm no copies remain in shell history, cloud-sync folders, downloads, editor backups, or
unapproved artifact stores.

## 6. Enable protected automation

Configure in `github-config`/GitHub Enterprise:

- protected `main` and critical paths;
- protected `plan`, `bootstrap`, and `break-glass` environments;
- `WIF_PROVIDER_PLAN` / `WIF_PROVIDER_APPLY`;
- `artifact_signer_wif_provider` as `WIF_PROVIDER_SIGNER`; the matching
  `artifact_signer_principal` is consumed only by `infrastructure-live` when binding its
  normal-plane signer service account;
- `SA_BOOTSTRAP_PLAN`, `SA_BOOTSTRAP_DRIFT`, and `SA_BOOTSTRAP_APPLY`;
- `TFSTATE_BUCKET`, `TFSTATE_REPLICA_BUCKET`, and required non-secret Terraform variables;
- `GH_ORGANIZATION`, `GH_ORGANIZATION_ID`, and `GH_REPOSITORY_IDS_JSON`;
- at least one named human in `BREAK_GLASS_PRINCIPALS_JSON`;
- exact workflow authorization for `.github/workflows/apply.yml`.

Before enabling release signing, verify a monorepo token from the protected `release`
environment and `reusable-binauthz-sign.yml@v3.0.0` can exchange through the signer provider.
Also record negative tests showing a builder job, an unprotected ref, a different environment,
and a different reusable workflow are rejected.

Run `plan.yml`, then a no-op protected `apply.yml` execution. Normal changes are Git-mediated
from this point onward.

The `plan` environment is part of the Google Cloud identity, not presentation-only metadata.
Record successful plan token exchange plus failed exchange from an arbitrary workflow and
branch. The scheduled recovery drill authenticates through its separate exact-main workflow
binding while its optional state inspection waits behind the governed `bootstrap` environment.

Also verify that a credentialed plan can create and delete only its GCS backend `.tflock`
object. The plan identity must be able to read state and complete with locking enabled, but a
direct write to the `.tfstate` object must be denied by IAM.

## Prohibited

Do not enable an irreversible bucket retention lock. State protection is supplied by narrow
IAM, native locking, versioning, soft delete, lifecycle controls, CMEK, and independent
replication.
