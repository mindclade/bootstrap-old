<!-- mindclade-doc: how-to@1 -->

# Import and activate the bootstrap repository

> **Audience:** Ring-0 recovery operators, platform, and security maintainers
> **Outcome:** `mindclade/bootstrap` is imported, validated, and ready for the documented first
> apply without enabling an unqualified automation path.
> **Risk:** Critical—this repository creates the state and trust required to recover every
> higher control repository.

## Before you begin

- Publish and protect the `.github` workflow contract at the full version referenced by this
  repository; the current ARC platform baseline is `v5.0.0`.
- Preserve the destination repository's `.git` directory and existing audit history.
- Confirm the repository is `private`, uses `main`, and matches `contracts/repository.yaml`.
- Identify a named recovery operator and an independent qualified reviewer.
- Do not configure protected apply until the first apply, state migration, WIF conditions, and
  negative authorization tests are complete.

## Import and validate

From the repository root:

```sh
nix develop
make validate
terraform fmt -check -recursive -diff
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
```

Expected result: the repository contract, Terraform configuration, WIF policy, license
headers, and local-state safety checks pass without contacting an authoritative backend.

## Continue with first apply

Follow [First apply and state migration](first-apply.md) exactly. It is the only supported path
that begins with local state. Do not improvise backend migration or inject a GitHub App private
key through Terraform variables.

After migration, populate the empty module-reader secret container through
[Automation secret bootstrap](automation-secret-bootstrap.md), then configure protected
GitHub environments and non-secret variables from verified Terraform outputs.

## Verify

- `terraform plan` against the remote bootstrap backend reports no changes.
- Primary state version history and independent replica health are visible.
- The WIF preflight succeeds for allowed plan/apply paths and fails for unauthorized
  repositories, refs, workflows, and audiences.
- A protected no-op apply plans and applies the exact reviewed `main` commit.
- No local state, saved plan, output JSON, credential, or private key remains on disk.

## Roll back or recover

If the remote-state verification plan is not empty, stop before enabling automation. Preserve
the local and remote copies, record their checksums, and use [State recovery](state-recovery.md)
to reconcile ownership. Never apply merely to make the plan quiet.
