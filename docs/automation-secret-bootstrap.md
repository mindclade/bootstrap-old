<!-- mindclade-doc: how-to@1 -->

# Bootstrap the private-module reader secret

> **Audience:** the named bootstrap operator provisioning or rotating the Terraform GitHub App key.
> **Outcome:** add a Secret Manager version without exposing key material to Terraform, GitHub
> Actions, repository files, or logs.
> **Risk:** high—the private key can read protected module source if exposed or overscoped.

`infrastructure-live` consumes private Terraform modules from
`mindclade/mindclade-internal-monorepo`. A clean organization has no normal security project
until infrastructure-live runs, so its module-reader credential cannot be created by that
repository without a dependency cycle.

Ring 0 resolves that cycle by creating exactly one empty, CMEK-protected Secret Manager
container:

```text
github-app-terraform-pem
```

Terraform never receives the GitHub App private key and never creates a secret version. The
container is accessible only to the bootstrap-created infrastructure-live plan and scoped
apply service accounts.

The user-managed Secret Manager replica and its dedicated CMEK use the same single region
(`automation_secret_location`, `us-central1` by default). Do not reuse the `us` multi-region
Terraform-state key: the user-managed regional Secret Manager replica rejected that location,
and Secret Manager requires a user-managed replica's CMEK location to match the replica exactly.
A partially applied legacy multi-region `automation-secrets` key is preserved in Google Cloud
but deliberately removed from Terraform state without destruction; it never protected a secret
version.

## Provision the first version

1. Create a dedicated GitHub App with read-only `Contents` access.
2. Install it in the Mindclade organization (`mindclade`) using **Only select repositories**.
   Select `mindclade-internal-monorepo`; add another explicitly named module-source repository
   only through a reviewed governance change. Never grant **All repositories** access.
3. Store the App ID as the `TF_APP_ID` non-secret Actions variable through `github-config`.
4. Obtain the private key through the approved credentials vault and add it directly to
   Secret Manager:

```sh
PROJECT_ID="$(terraform output -raw automation_secret_project_id)"
SECRET_ID="$(terraform output -raw github_app_terraform_secret_id)"

gcloud secrets versions add "${SECRET_ID}" \
  --project "${PROJECT_ID}" \
  --data-file /secure/path/to/github-app-private-key.pem
```

Do not put the key in `terraform.tfvars`, Terraform state, a GitHub Actions secret, shell
history, PR output, or a repository file. Delete temporary local copies after the approved
vault and Secret Manager version have been independently verified.

## Rotation

1. Generate a new GitHub App private key.
2. Add it as a new Secret Manager version.
3. Run an infrastructure-live plan and a harmless private-module fetch;
4. disable the previous version;
5. observe for the documented rollback window;
6. destroy the previous version and revoke the old GitHub key;
7. record the rotation in the security log.

The GitOps render App uses a separate key and a separate secret container in the normal
`mc-common-security` project owned by `infrastructure-live`.

## Verify

Verify the enabled version metadata without printing the payload, then run a harmless
`infrastructure-live` private-module initialization through its protected plan identity. Confirm
that unrelated identities cannot access the secret. Also inspect the secret metadata and confirm
the replica location and CMEK resource name contain the same region:

```sh
gcloud secrets describe "${SECRET_ID}" \
  --project "${PROJECT_ID}" \
  --format='yaml(replication.userManaged.replicas)'
```

## Roll back or recover

If the new version fails, re-enable the last known-good version during the approved rollback window
and investigate the App installation, permissions, and Secret Manager IAM binding before destroying
either version.
