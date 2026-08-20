# Bootstrap contracts

The `platform_contract` Terraform output is the only supported machine interface from Ring 0.
It exports non-secret state, federation, recovery, and automation-identity identifiers.
Consuming repositories must not read bootstrap implementation details or remote state directly.

Contract `1.1.0` added the signer-only GitHub trust tuple: `WIF_PROVIDER_SIGNER`, the exact
protected-release principal for the normal-plane signer service account, and the immutable
`v4.0.0` reusable workflow reference. The signer service account, KMS key, attestor, and their
roles remain owned by `infrastructure-live`; bootstrap owns only the federation trust anchor.

Contract `1.2.0` moves every GitHub principal to GitHub Cloud's immutable default subject
format, `repo:OWNER@OWNER-ID/REPO@REPO-ID:context`, and exports the owner ID with each
repository identity. Consumers must reject the pre-2026 name-only signer principal. Buildkite
federation maps the immutable pipeline UUID to Google's bounded subject and requires callers to
request the `pipeline_id` subject plus `organization_id` claim; the existing provider output is
the required token audience.

Contract `1.3.0` adds `artifact_release_identities`: distinct canary, builder,
qualification-reader, qualifier, signer, and promoter provider/principal contracts. Every path
binds a protected-main push, exact caller, exact v4 reusable workflow, and immutable repository
IDs. Buildkite activation is prohibited. Normal-plane service accounts remain outside Ring 0.

Retrieve and validate the value after an approved apply:

```sh
terraform output -json platform_contract > platform-contract.json
check-jsonschema --schemafile contracts/outputs.schema.json platform-contract.json
```

The generated `platform-contract.json` contains internal infrastructure identifiers. Keep it in
an approved, access-controlled evidence store; do not commit it or publish it as a public CI
artifact. Schema changes require a contract-version change and a coordinated consumer migration.
