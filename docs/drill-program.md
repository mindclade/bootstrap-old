<!-- mindclade-doc: how-to-guide@1 -->

# Disaster-recovery drill program

This program defines objectives and cadence; it is not evidence that recovery works. Every drill
runs only in scratch or staging, uses a primary operator and a distinct observer, and publishes a
measured report v3 to the protected append-only archive. Production mutation is outside this drill
program.

## Objectives, evidence, and next executions

The checked-in [generated readiness inventory](generated/dr-readiness.md) is derived from the
machine-readable matrix and evidence index. The daily readiness workflow evaluates due dates at
runtime, opens one deduplicated issue at 30 days, escalates the same issue at seven days or when
overdue, and treats missing or expired evidence as blocked. The generated inventory is the only
checked-in rendering of objective, cadence, schedule, and evidence state; edit the contracts, not
the table.

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

Validate against `mindclade/.github/schemas/drill-report-v3.schema.json` and its semantic validator.
Report v3 is a strict extension of the historical v2 contract and binds every execution to a
Mindclade pull request or issue through `change_reference`. Historical v2 evidence remains valid.
The shared `reusable-dr-evidence.yml` workflow binds report environment, caller commit, primary, and
observer before authentication. It publishes a content-addressed object using a no-overwrite
precondition and retains a complementary GitHub Actions artifact.

The durable destination is a protected US multi-region Cloud Storage bucket with versioning,
uniform access, public-access prevention, customer-managed encryption, access logging, retention
locked for seven years, and a writer identity unable to overwrite, delete, or change retention.
Real project, bucket, provider, and service-account identifiers are injected only through protected
environment variables.

Use the `Prepare DR drill` workflow from protected `main` to create the non-mutating source packet.
It fixes the matrix objective, exact caller revision, distinct operators, change reference, success
criteria, and abort conditions before an operator runs a command. Complete the measured v3 report
after execution, validate it through the shared v5 workflow, then update
`contracts/dr-evidence-index.json` with the protected URI, digest, qualification date, and expiry in
a reviewed follow-up. The source packet is preparation, never evidence.

## Qualification rule

A source-only check may verify schemas, rendering, and runbook completeness. Disaster recovery is
qualified only when a real scratch/staging report passes semantic validation, its evidence objects
are retrievable by authorized reviewers, measured RPO/RTO meet the objective, all failures are
absent, all corrective actions are complete, and the next drill date is future. Until then, report
the capability as blocked or not run—never inferred from documentation.
