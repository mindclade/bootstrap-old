#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

"""Create a non-mutating, source-bound execution packet for one DR drill."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOGIN = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$")
CHANGE = re.compile(r"^https://github[.]com/mindclade/[A-Za-z0-9_.-]+/(?:pull|issues)/[1-9][0-9]*$")
SHA = re.compile(r"^[0-9a-f]{40}$")

SUCCESS = [
    "The target remained inside the matrix-declared scratch or staging boundary.",
    "Measured recovery point and recovery time met the declared objectives.",
    "Evidence hashes, deviations, and corrective actions were independently reviewed.",
]
ABORT = [
    "The resolved target leaves the declared scratch or staging boundary.",
    "The observer is unavailable or is the primary operator.",
    "A command would mutate production, overwrite evidence, or bypass protected review.",
]


def create_packet(
    drill_id: str,
    primary: str,
    observer: str,
    change_reference: str,
    source_sha: str,
    prepared_at: dt.datetime,
) -> dict:
    matrix = json.loads((ROOT / "contracts/drill-matrix.json").read_text(encoding="utf-8"))
    drills = {item["id"]: item for item in matrix["drills"]}
    if drill_id not in drills:
        raise ValueError(f"unknown drill id: {drill_id}")
    if not LOGIN.fullmatch(primary) or not LOGIN.fullmatch(observer) or primary == observer:
        raise ValueError("primary and observer must be distinct valid GitHub logins")
    if not CHANGE.fullmatch(change_reference):
        raise ValueError("change reference must be a Mindclade GitHub pull request or issue URL")
    if not SHA.fullmatch(source_sha):
        raise ValueError("source SHA must be an exact lowercase commit SHA")
    if prepared_at.tzinfo is None:
        raise ValueError("prepared-at must include a timezone")
    drill = drills[drill_id]
    return {
        "schemaVersion": 1,
        "reportSchema": matrix["reportSchema"],
        "drillId": drill_id,
        "environment": drill["environment"],
        "preparedAt": prepared_at.isoformat().replace("+00:00", "Z"),
        "nextExecution": drill["nextExecution"],
        "reportSeed": {
            "schema_version": 3,
            "drill_type": drill_id,
            "environment": drill["environment"],
            "operators": [
                {"identity": primary, "role": "primary"},
                {"identity": observer, "role": "observer"},
            ],
            "source_revisions": {"mindclade/bootstrap": source_sha},
            "objectives": {
                "rpo_seconds": drill["rpoSeconds"],
                "rto_seconds": drill["rtoSeconds"],
            },
            "success_criteria": SUCCESS,
            "abort_conditions": ABORT,
            "change_reference": change_reference,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--drill-id", required=True)
    parser.add_argument("--primary", required=True)
    parser.add_argument("--observer", required=True)
    parser.add_argument("--change-reference", required=True)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--prepared-at", required=True, type=dt.datetime.fromisoformat)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        packet = create_packet(
            args.drill_id,
            args.primary,
            args.observer,
            args.change_reference,
            args.source_sha,
            args.prepared_at,
        )
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(packet, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
