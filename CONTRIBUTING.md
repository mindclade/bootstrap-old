# Contributing to `bootstrap`

Organization-wide conventions live in the internal `mindclade/.github` repository. This file
adds Ring-0 requirements.

## Before editing

Read:

- `BLUEPRINT.md`;
- `docs/first-apply.md`;
- `docs/state-recovery.md`;
- `docs/break-glass.md`.

A bootstrap mistake can remove the identities and state needed to repair every other control
repository.

## Change path

The first creation and state migration are performed by a named recovery operator. After that,
normal changes use the protected workflow:

```text
pull-request validation + speculative plan
-> merge
-> plan exact main SHA
-> protected bootstrap environment approval
-> apply exact integrity-checked plan
```

Never bypass Git for routine changes.

## Pull-request evidence

A Ring-0 pull request includes:

- the speculative plan summary;
- explicit identification of creates, replacements, and destroys;
- the state, identity, or recovery blast radius;
- a recovery/rollback approach;
- migration instructions for any renamed Terraform address;
- two qualified approvals for state, WIF, break-glass, KMS, or workflow authorization changes.

## Critical changes

Treat these as critical:

```text
backend.tf
modules/state/**
modules/identity/**
modules/projects/folder.tf
.github/workflows/apply.yml
.github/workflows/recovery-drill.yml
```

Do not add a bucket retention lock that can prevent Terraform from replacing its state object.
Do not remove KMS or bucket `prevent_destroy` safeguards without a documented decommission
procedure.

## Local checks

```sh
nix develop
make validate
make lint
terraform fmt -check -recursive -diff
terraform init -backend=false -input=false -lockfile=readonly
terraform validate
```

`make plan-local` is for first apply or documented recovery only.

## Never commit

- local state or plan files;
- `.terraform/`;
- credentials, private keys, or service-account key JSON;
- production values in `terraform.tfvars`;
- AppleDouble or editor-generated metadata.
