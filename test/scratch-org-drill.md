# Scratch-org drill

Annual. Executed by an engineer who did **not** write the code, cold, without help.

## What is actually being tested

Not whether the Terraform works — CI tells us that. The drill tests whether the
*documentation* works: whether someone who was not in the room can rebuild the organization
from the runbooks alone.

Every question the operator has to ask is a defect in the docs, and gets recorded as one.

## Rules

1. **The operator has not worked on `bootstrap`.** Someone who wrote it will fill gaps
   unconsciously and the drill measures nothing.
2. **No help.** An observer takes notes and does not answer questions. Blocked for 30
   minutes is a finding, not a failure — write it down and move on.
3. **Documentation only.** `bootstrap/docs/` and `infrastructure-live/docs/`. Not Slack, not
   the person who wrote it, not a memory of last year.
4. **Timed.** Wall clock per stage, so the recovery estimate in `cold-start.md` stays honest.
5. **A scratch organization.** Never production, never even a copy of production.

## Setup

- A separate GCP organization on a test domain.
- A billing account with a hard cap.
- A scratch GitHub organization.
- A day set aside. Not an afternoon.

## Procedure

Work through `docs/cold-start.md` exactly as written. Record, per stage:

| Field | Notes |
|---|---|
| Start / end time | Wall clock, including waiting |
| Blocked? | For how long, and on what |
| Documentation gap | What was missing, wrong, or ambiguous |
| Deviation | What you had to do that the docs do not mention |

## Success criteria

Not "did it work". A drill where everything works first time and took nine hours has still
told you the estimate is wrong.

| Criterion | Target |
|---|---|
| Completed from docs alone | Yes |
| Questions the operator had to ask | 0 blocking, ≤3 clarifying |
| Total elapsed vs `cold-start.md` estimate | Within 50% |
| Steps needing deviation | ≤2 |
| Steps in the wrong order in the docs | 0 |

## Afterwards

Within one week, or it does not happen:

1. **Fix the documentation.** Every gap the operator hit, in a PR. This is the deliverable —
   not the rebuilt org.
2. **Update the timing table** in `cold-start.md` with the real numbers.
3. **Tear down the scratch org.** Delete the projects, unlink billing, remove the domain.
4. **Record the result** in the table below.

## History

| Date | Operator | Elapsed | Blocking questions | Findings | Notes |
|---|---|---|---|---|---|
| _(not yet run)_ | | | | | First drill due within 12 months of the first production apply |

## A note on why this is worth a day

The alternative to running this is finding out during a real incident that the runbook skips
a step, that the person who knew has left, or that domain verification takes a day nobody
budgeted for.

The recovery estimate in `cold-start.md` is only credible because someone timed it. Without
the drill it is a guess with a table around it.
