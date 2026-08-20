<!-- mindclade-doc: runbook-index@1 -->

# Ring-0 disaster recovery

> **Use when:** Bootstrap state, KMS, federation, or automation is unavailable or untrusted.
> **Outcome:** Route the incident to the least invasive authoritative recovery procedure.

## First response

1. Declare the incident and stop all bootstrap and downstream infrastructure applies.
2. Preserve the failing commit, workflow runs, Cloud Audit Logs, state object generations, and
   affected identifiers.
3. Determine which control is damaged before mutating anything.

## Choose the recovery path

| Symptom | Procedure | First safe action |
| --- | --- | --- |
| State is missing, corrupt, or inconsistent | [Terraform state recovery](state-recovery.md) | Copy a candidate generation to an isolated file and validate it |
| WIF or normal IAM blocks repair | [Break-glass](break-glass.md) | Record the intended scope and grant the narrowest conditional role |
| Repository identity or trust claims changed | [Credential and trust rotation](credential-rotation.md) | Record old/new immutable IDs and update the cloud side first |
| Entire control plane must be rebuilt | [Cold-start platform recovery](cold-start.md) | Recover external ownership, then proceed in dependency order |
| First private-module credential is unavailable | [Automation secret bootstrap](automation-secret-bootstrap.md) | Verify the empty container and approved vault source |

## Completion gate

Recovery is not complete until the remote-state plan is understood and empty, replication is
healthy, allowed WIF paths succeed, unauthorized paths fail, temporary grants are revoked,
audit evidence is retained, and all higher control repositories can authenticate without a
service-account key.

Use the [clean-room recovery drill](../test/clean-room-recovery.md) and
[scratch-organization drill](../test/scratch-org-drill.md) to qualify these procedures. Ring-0
recovery must never depend on the failed Kubernetes runtime.
