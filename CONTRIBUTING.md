<!-- mindclade-doc: contributing@1 -->

# Contributing to Mindclade · `bootstrap`

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


## Contributor authorization and intellectual property

A contribution may be submitted only by a person authorized under a current
written employment, contractor, assignment, or other contribution agreement
with Mindclade, LLC. Before opening or updating a pull request, the contributor
must confirm that:

- they have the right and authority to submit every part of the contribution;
- first-party work is covered by the contributor's controlling written
  agreement with Mindclade, LLC.;
- third-party code, data, models, media, fonts, specifications, and generated
  material are identified with their source, version, license, provenance, and
  required notices;
- the contribution contains no material whose confidentiality, license,
  consent, acceptable-use terms, export controls, or other restrictions
  prohibit submission; and
- the change description and validation evidence are complete and accurate.

By submitting or updating a pull request, the contributor represents that these
statements are true. Submission is not acceptance and does not by itself alter
ownership, grant a license, or replace the controlling written agreement.
Signed commits establish source identity and integrity; they are not a
substitute for the required written agreement.

If authorization or ownership is unclear, stop before submission and use the
legal or contract channel named in the applicable agreement. Do not place
confidential material in a public issue or an unapproved email.
