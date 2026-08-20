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
terraform init -migrate-state -input=false -backend-config="bucket=${STATE_BUCKET}"
terraform state pull > remote-state-verification.json
terraform plan -lock=false
```

The plan must be empty. Verify the remote state object and version history:

```sh
gcloud storage ls --all-versions "gs://${STATE_BUCKET}/bootstrap/**"
```

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
- protected `bootstrap` environment;
- `WIF_PROVIDER_PLAN` / `WIF_PROVIDER_APPLY`;
- `SA_BOOTSTRAP_PLAN`, `SA_BOOTSTRAP_DRIFT`, and `SA_BOOTSTRAP_APPLY`;
- `TFSTATE_BUCKET` and required non-secret Terraform variables;
- exact workflow authorization for `.github/workflows/apply.yml`.

Run `plan.yml`, then a no-op protected `apply.yml` execution. Normal changes are Git-mediated
from this point onward.

## Prohibited

Do not enable an irreversible bucket retention lock. State protection is supplied by narrow
IAM, native locking, versioning, soft delete, lifecycle controls, CMEK, and independent
replication.
