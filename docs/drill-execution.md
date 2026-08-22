<!-- mindclade-doc: runbook@1 -->

# Execute and archive a disaster-recovery drill

This runbook is the operator protocol for every objective in `contracts/drill-matrix.json`.
It authorizes scratch or staging exercises only. It does not authorize production mutation,
destructive teardown, registrar changes, tag publication, or bypass of a protected environment.

## Preflight

1. Create an approved `DR-`, `CHG-`, `INC-`, or `SEC-` record naming one primary and one
   different observer. The protected GitHub environment must prevent self-review.
2. Select the due matrix objective and copy its exact RPO/RTO into a new report-v2 document.
3. Record full 40-character source revisions for every repository in scope, the scratch/staging
   resource identifiers, success criteria, abort conditions, budget, and teardown owner.
4. Prove the evidence bucket, key, writer identity, access-log destination, and no-overwrite
   policy are healthy with a harmless preflight object. Never put raw state, credentials, tokens,
   private DNS data, or unredacted plans in the report.
5. The observer confirms the environment and abort boundary before the primary begins timing.

## Objective routing

| Objective | Procedure authority | Required proof |
| --- | --- | --- |
| Bootstrap clean-room | `docs/cold-start.md`, `test/scratch-org-drill.md` | independent scratch org and GitHub org rebuilt from documentation |
| Terraform-state recovery | `docs/state-recovery.md` | selected generation, replica provenance, serial/lineage, zero-drift plan |
| GitHub/IdP outage | `docs/cloud-identity-authorization.md`, `docs/break-glass.md` | automation denied, manual export/authorization bounded, emergency access revoked |
| Organization-policy rollback | `infrastructure-live/docs/runbooks/org-policy-rollback.md` | exact policy rollback and re-apply with simulator evidence |
| VPC SC lockout | `infrastructure-live/docs/runbooks/vpc-sc-denial.md` | denied path identified, reviewed exception/rollback, perimeter restored |
| GKE reconstruction | `infrastructure-live/docs/runbooks/gke-reconstruction.md` | regional cluster and workload identity reconstructed, GitOps reconciliation healthy |
| Argo CD rebootstrap | GitOps bootstrap/recovery documentation | signed desired-state revision reconciled without manual workload edits |
| Cloud SQL restore | `infrastructure-live/docs/runbooks/cloud-sql-restore.md` | PITR timestamp, restored instance integrity, application read check |
| Protected-bucket restore | `infrastructure-live/docs/runbooks/protected-bucket-restore.md` | selected generation restored without weakening retention/public-access controls |
| Compromised-artifact revocation | `infrastructure-live/docs/runbooks/binauthz-blocked-deploy.md` | digest blocked, attestation revoked, prior known-good digest selected |

## Execution and abort

Start the monotonic and UTC timers immediately before the injected failure. The primary executes;
the observer records commands, results, deviations, recovery point, and abort decisions. Abort on
any production target, uncontrolled cost, loss of audit/evidence write capability, ambiguous
resource identity, retention/DNSSEC weakening, or an action outside the approved change. An abort
is a valid failed drill and must still be reported.

Do not improve the system while timing recovery. Restore first, capture the result, then create
separately reviewed corrective actions. For every recovery, run the procedure's integrity and
zero-drift checks before stopping the RTO timer.

## Archive and close

1. Complete report v2 with measured RPO/RTO, timestamps, evidence digests, failures, corrective
   actions with owners/dates, and the next scheduled execution.
2. Validate with the immutable `.github` report validator and dispatch this repository's
   `dr-evidence.yml` from the matching protected environment. The primary must be the dispatching
   actor; the observer must approve and must be a distinct login.
3. Confirm the append-only `gs://` object can be read by an authorized reviewer and that access
   logs contain the write. Retain the workflow artifact as complementary evidence.
4. Teardown only the explicitly identified scratch resources using the separately approved
   teardown procedure. Staging rollback restores the exact pre-drill reviewed state.
5. The capability passes only when measured objectives pass, failures are empty, corrective
   actions are complete, and the next date is future. Otherwise it remains blocked.
