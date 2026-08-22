#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

"""Validate the complete, scheduled, two-operator DR drill matrix."""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "bootstrap-clean-room": ("scratch", 86400, 28800, "annual"),
    "terraform-state-recovery": ("scratch", 86400, 14400, "semiannual"),
    "github-idp-outage": ("scratch", 3600, 14400, "semiannual"),
    "org-policy-rollback": ("staging", 0, 7200, "quarterly"),
    "vpc-sc-lockout": ("staging", 0, 7200, "quarterly"),
    "gke-reconstruction": ("staging", 3600, 14400, "semiannual"),
    "argocd-rebootstrap": ("staging", 0, 7200, "quarterly"),
    "cloud-sql-restore": ("staging", 3600, 14400, "quarterly"),
    "protected-bucket-restore": ("staging", 3600, 14400, "quarterly"),
    "compromised-artifact-revocation": ("staging", 0, 3600, "quarterly"),
}


def main() -> int:
    matrix = json.loads((ROOT / "contracts/drill-matrix.json").read_text(encoding="utf-8"))
    if set(matrix) != {
        "schemaVersion",
        "reportSchema",
        "evidenceWorkflow",
        "operatorPolicy",
        "drills",
    } or matrix["schemaVersion"] != 1:
        raise SystemExit("drill matrix root fields are not exact")
    if matrix["evidenceWorkflow"] != (
        "mindclade/.github/.github/workflows/"
        "reusable-dr-evidence.yml@refs/tags/v5.0.0"
    ):
        raise SystemExit("DR evidence workflow must use immutable v5.0.0")
    if matrix["operatorPolicy"] != {
        "requiredRoles": ["primary", "observer"],
        "distinctIdentities": True,
        "preventSelfReview": True,
        "changeReferenceRequired": True,
    }:
        raise SystemExit("two-operator protected-review policy differs")
    drills = matrix["drills"]
    if not isinstance(drills, list) or len(drills) != len(EXPECTED):
        raise SystemExit("drill matrix must contain exactly ten objectives")
    by_id = {item.get("id"): item for item in drills if isinstance(item, dict)}
    if set(by_id) != set(EXPECTED):
        raise SystemExit("drill objective inventory differs")
    today = dt.date.today()
    exact_fields = {
        "id",
        "environment",
        "rpoSeconds",
        "rtoSeconds",
        "cadence",
        "nextExecution",
    }
    for drill_id, expected in EXPECTED.items():
        item = by_id[drill_id]
        if set(item) != exact_fields:
            raise SystemExit(f"{drill_id}: fields are not exact")
        actual = (
            item["environment"],
            item["rpoSeconds"],
            item["rtoSeconds"],
            item["cadence"],
        )
        if actual != expected:
            raise SystemExit(f"{drill_id}: objective or cadence differs")
        try:
            next_execution = dt.date.fromisoformat(item["nextExecution"])
        except (TypeError, ValueError) as exc:
            raise SystemExit(f"{drill_id}: invalid nextExecution") from exc
        if next_execution <= today:
            raise SystemExit(f"{drill_id}: nextExecution must be future; reschedule through review")
    print("DR drill matrix validation passed: 10 objectives, two operators, future schedule")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
