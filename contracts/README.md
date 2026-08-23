# Bootstrap contracts

`drill-matrix.json` is the machine-readable estate DR objective, cadence, RPO/RTO, environment,
and two-operator evidence contract. It schedules work; it is never itself runtime evidence.

`dr-evidence-index.json` is the reviewed, non-secret index of qualified report digests, protected
archive URIs, and expiry dates. `scripts/dr-readiness.py` joins it to the drill matrix, generates
`docs/generated/dr-readiness.md`, and emits the sanitized runtime JSON consumed by the daily alert.

The `platform_contract` Terraform output is the only supported machine interface from Ring 0.
It exports non-secret state, federation, recovery, and automation-identity identifiers.
Consuming repositories must not read bootstrap implementation details or remote state directly.

Contract `1.1.0` added the signer-only GitHub trust tuple: `WIF_PROVIDER_SIGNER`, the exact
protected-release principal for the normal-plane signer service account, and the immutable
`v5.0.0` reusable workflow reference. The signer service account, KMS key, attestor, and their
roles remain owned by `infrastructure-live`; bootstrap owns only the federation trust anchor.

Contract `1.2.0` moves every GitHub principal to GitHub Cloud's immutable default subject
format, `repo:OWNER@OWNER-ID/REPO@REPO-ID:context`, and exports the owner ID with each
repository identity. Consumers must reject the pre-2026 name-only signer principal. Buildkite
federation maps the immutable pipeline UUID to Google's bounded subject and requires callers to
request the `pipeline_id` subject plus `organization_id` claim; the existing provider output is
the required token audience.

Contract `1.3.0` adds `artifact_release_identities`: distinct canary, builder,
qualification-reader, qualifier, signer, and promoter provider/principal contracts. Every path
binds a protected-main push, exact caller, exact v5 reusable workflow, and immutable repository
IDs. Buildkite activation is prohibited. Normal-plane service accounts remain outside Ring 0.

Contract `1.4.0` adds `dr_evidence_identity`: one capability-specific provider and eight exact
scratch/staging principals for the four repositories that own recovery drills. It accepts only a
manual dispatch from each repository's protected `main` caller and the immutable v5 shared evidence
workflow. The normal-plane writer service account and evidence bucket remain outside Ring 0.

Contract `1.5.0` adds `bazel_cache_identity`: one provider dedicated to the internal monorepo's
Bazel cache. Pull requests receive a read-only route; protected-main pushes, merge-queue runs, and
scheduled nightly runs receive three distinct write routes. Every route binds the immutable owner
and repository IDs, exact event ref, exact workflow path at that ref, workflow commit SHA, and a
provider-specific audience. Reader/writer service accounts, bucket IAM, CMEK access, and the cache
bucket remain normal-plane resources owned by `infrastructure-live`.

Contract `1.6.0` adds `workstation_image_identity`: a dedicated provider for create-only NixOS
raw-disk publication. It binds the immutable monorepo ID, the
`workstation-image-publication` environment subject, protected `main`, manual dispatch, the exact
`.github/workflows/nixos-image.yml` caller, and
`reusable-nixos-gce-image-publish.yml@v5.0.0`. The service account, bucket IAM, Compute Image,
workstation selection, and rollout remain normal-plane resources owned by `infrastructure-live`.

Retrieve and validate the value after an approved apply:

```sh
terraform output -json platform_contract > platform-contract.json
check-jsonschema --schemafile contracts/outputs.schema.json platform-contract.json
```

The generated `platform-contract.json` contains internal infrastructure identifiers. Keep it in
an approved, access-controlled evidence store; do not commit it or publish it as a public CI
artifact. Schema changes require a contract-version change and a coordinated consumer migration.
