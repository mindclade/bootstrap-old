<!-- mindclade-doc: how-to-guide@1 -->

# Disaster-recovery drill program

This program defines objectives and cadence; it is not evidence that recovery works. Every drill
runs only in scratch or staging, uses a primary operator and a distinct observer, and publishes a
measured report v2 to the protected append-only archive. Production mutation is outside this drill
program.

## Objectives and next executions

| Drill | Environment | RPO | RTO | Cadence | Next execution |
| --- | --- | ---: | ---: | --- | --- |
| Bootstrap clean-room | scratch | 24 h | 8 h | annual | 2026-10-13 |
| Terraform-state recovery | scratch | 24 h | 4 h | semiannual | 2026-09-22 |
| GitHub/IdP outage | scratch | 1 h | 4 h | semiannual | 2026-10-06 |
| Organization-policy rollback | staging | 0 | 2 h | quarterly | 2026-09-15 |
| VPC Service Controls lockout | staging | 0 | 2 h | quarterly | 2026-09-29 |
| GKE reconstruction | staging | 1 h | 4 h | semiannual | 2026-11-03 |
| Argo CD rebootstrap | staging | 0 | 2 h | quarterly | 2026-10-20 |
| Cloud SQL restore | staging | 1 h | 4 h | quarterly | 2026-11-10 |
| Protected-bucket restore | staging | 1 h | 4 h | quarterly | 2026-11-17 |
| Compromised-artifact revocation | staging | 0 | 1 h | quarterly | 2026-09-08 |

Zero RPO means recovery must return to the exact reviewed policy, Git selection, or admission state;
it does not assert zero data loss for an application data store. Dates move only through review, and
a delayed execution must record the reason and a new date.

## Operators and protected dispatch

The incident-management roster assigns an actual GitHub login to each role before dispatch; those
identities remain protected operational values rather than source defaults. The primary login must
equal the dispatching actor. The observer login must differ, approve the protected GitHub
environment, witness abort/success checks, and review evidence hashes. Environment protection must
prevent self-review. The completed report permanently records both identities.

## Evidence contract

Before execution, record the exact source commits, objective, success criteria, abort conditions,
and destination. During execution, retain UTC timestamps, commands and outputs, recovery-point
evidence, and every deviation. After execution, record observed RPO/RTO, failures, corrective
actions with owners/dates, and the next drill date.

Validate against `mindclade/.github/schemas/drill-report-v2.schema.json` and its semantic validator.
The shared `reusable-dr-evidence.yml` workflow binds report environment, caller commit, primary, and
observer before authentication. It publishes a content-addressed object using a no-overwrite
precondition and retains a complementary GitHub Actions artifact.

The durable destination is a protected US multi-region Cloud Storage bucket with versioning,
uniform access, public-access prevention, customer-managed encryption, access logging, retention
locked for seven years, and a writer identity unable to overwrite, delete, or change retention.
Real project, bucket, provider, and service-account identifiers are injected only through protected
environment variables.

## Qualification rule

A source-only check may verify schemas, rendering, and runbook completeness. Disaster recovery is
qualified only when a real scratch/staging report passes semantic validation, its evidence objects
are retrievable by authorized reviewers, measured RPO/RTO meet the objective, all failures are
absent, all corrective actions are complete, and the next drill date is future. Until then, report
the capability as blocked or not run—never inferred from documentation.
