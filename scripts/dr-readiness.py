#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

"""Derive DR schedule and evidence readiness without consulting live systems."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
MATRIX = ROOT / "contracts/drill-matrix.json"
EVIDENCE = ROOT / "contracts/dr-evidence-index.json"
DOC = ROOT / "docs/generated/dr-readiness.md"


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain an object")
    return value


def derive(as_of: dt.date) -> dict[str, Any]:
    matrix = load(MATRIX)
    index = load(EVIDENCE)
    if set(index) != {"schemaVersion", "warningDays", "criticalDays", "evidence"}:
        raise ValueError("DR evidence index root fields are not exact")
    if index["schemaVersion"] != 1:
        raise ValueError("unsupported DR evidence index schema")
    warning = index["warningDays"]
    critical = index["criticalDays"]
    if not isinstance(warning, int) or not isinstance(critical, int) or not 0 < critical < warning:
        raise ValueError("DR readiness thresholds must satisfy 0 < criticalDays < warningDays")

    drills = {item["id"]: item for item in matrix["drills"]}
    records = index["evidence"]
    if not isinstance(records, list) or len(records) != len(drills):
        raise ValueError("DR evidence index must contain exactly one record per drill")
    indexed = {item.get("drillId"): item for item in records if isinstance(item, dict)}
    if set(indexed) != set(drills):
        raise ValueError("DR evidence index inventory differs from the drill matrix")

    results: list[dict[str, Any]] = []
    for drill_id in sorted(drills):
        drill = drills[drill_id]
        record = indexed[drill_id]
        if set(record) != {"drillId", "qualifiedAt", "expiresAt", "reportSha256", "evidenceUri"}:
            raise ValueError(f"{drill_id}: evidence fields are not exact")
        evidence_values = [record[name] for name in ("qualifiedAt", "expiresAt", "reportSha256", "evidenceUri")]
        if all(value is None for value in evidence_values):
            evidence_status = "not-run"
        elif any(value is None for value in evidence_values):
            raise ValueError(f"{drill_id}: qualified evidence metadata is incomplete")
        else:
            qualified = dt.date.fromisoformat(str(record["qualifiedAt"])[:10])
            expires = dt.date.fromisoformat(str(record["expiresAt"])[:10])
            if expires <= qualified:
                raise ValueError(f"{drill_id}: evidence expiry must follow qualification")
            due = dt.date.fromisoformat(drill["nextExecution"])
            if expires > due:
                raise ValueError(f"{drill_id}: evidence expiry must not outlive the next execution")
            digest = str(record["reportSha256"])
            uri = str(record["evidenceUri"])
            if len(digest) != 64 or any(char not in "0123456789abcdef" for char in digest):
                raise ValueError(f"{drill_id}: reportSha256 is invalid")
            if not uri.startswith("gs://"):
                raise ValueError(f"{drill_id}: evidenceUri must use the protected GCS archive")
            evidence_status = "expired" if expires < as_of else "qualified"

        due = dt.date.fromisoformat(drill["nextExecution"])
        days = (due - as_of).days
        if days < 0:
            schedule_status = "overdue"
        elif days <= critical:
            schedule_status = "critical"
        elif days <= warning:
            schedule_status = "warning"
        else:
            schedule_status = "scheduled"
        results.append(
            {
                "drillId": drill_id,
                "environment": drill["environment"],
                "nextExecution": drill["nextExecution"],
                "daysUntilExecution": days,
                "scheduleStatus": schedule_status,
                "evidenceStatus": evidence_status,
                "productionReady": evidence_status == "qualified" and schedule_status != "overdue",
            }
        )
    return {
        "schemaVersion": 1,
        "evaluatedAt": as_of.isoformat(),
        "thresholds": {"warningDays": warning, "criticalDays": critical},
        "summary": {
            "productionReady": sum(item["productionReady"] for item in results),
            "notRun": sum(item["evidenceStatus"] == "not-run" for item in results),
            "expired": sum(item["evidenceStatus"] == "expired" for item in results),
            "overdue": sum(item["scheduleStatus"] == "overdue" for item in results),
            "critical": sum(item["scheduleStatus"] == "critical" for item in results),
            "warning": sum(item["scheduleStatus"] == "warning" for item in results),
        },
        "drills": results,
    }


def render_doc() -> str:
    matrix = load(MATRIX)
    index = load(EVIDENCE)
    evidence = {item["drillId"]: item for item in index["evidence"]}
    lines = [
        "<!-- generated by scripts/dr-readiness.py; do not edit -->",
        "",
        "# DR readiness inventory",
        "",
        "This source view is generated from the drill matrix and evidence index. It does not prove a drill ran.",
        "Runtime urgency is evaluated daily with warning and critical thresholds of "
        f"{index['warningDays']} and {index['criticalDays']} days.",
        "",
        "| Drill | Environment | RPO | RTO | Cadence | Next execution | Evidence | Production ready |",
        "| --- | --- | ---: | ---: | --- | --- | --- | --- |",
    ]
    for drill in matrix["drills"]:
        record = evidence[drill["id"]]
        state = "not run" if record["qualifiedAt"] is None else f"expires {record['expiresAt']}"
        ready = "no" if record["qualifiedAt"] is None else "subject to runtime expiry check"
        lines.append(
            f"| `{drill['id']}` | {drill['environment']} | {drill['rpoSeconds']} s | {drill['rtoSeconds']} s | {drill['cadence']} | {drill['nextExecution']} | {state} | {ready} |"
        )
    lines.extend(
        [
            "",
            "A capability remains blocked when evidence is missing or expired, a drill is overdue, measured RPO/RTO fails, or corrective actions remain open.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--as-of", type=dt.date.fromisoformat, default=dt.date.today())
    parser.add_argument("--output", type=Path)
    parser.add_argument("--write-doc", action="store_true")
    parser.add_argument("--check-doc", action="store_true")
    args = parser.parse_args()
    try:
        result = derive(args.as_of)
        document = render_doc()
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        else:
            print(json.dumps(result, indent=2, sort_keys=True))
        if args.write_doc:
            DOC.parent.mkdir(parents=True, exist_ok=True)
            DOC.write_text(document, encoding="utf-8")
        if args.check_doc and (not DOC.is_file() or DOC.read_text(encoding="utf-8") != document):
            raise ValueError("generated DR readiness documentation is stale; run scripts/dr-readiness.py --write-doc")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
