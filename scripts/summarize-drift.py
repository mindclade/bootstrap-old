#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

"""Emit a sanitized, address-free drift summary from Terraform plan JSON."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def summarize(plan: dict, commit: str) -> dict:
    counts = {name: 0 for name in ("create", "update", "delete", "replace", "read", "noOp")}
    critical = 0
    for entry in plan.get("resource_changes", []):
        actions = entry.get("change", {}).get("actions", [])
        aset = set(actions)
        if "create" in aset and "delete" in aset:
            kind = "replace"
        elif "delete" in aset:
            kind = "delete"
        elif "create" in aset:
            kind = "create"
        elif "update" in aset:
            kind = "update"
        elif "read" in aset:
            kind = "read"
        else:
            kind = "noOp"
        counts[kind] += 1
        if kind != "noOp" and entry.get("type") in {
            "google_storage_bucket",
            "google_kms_crypto_key",
            "google_iam_workload_identity_pool",
            "google_iam_workload_identity_pool_provider",
            "google_service_account",
        }:
            critical += 1
    return {
        "schemaVersion": 1,
        "commit": commit,
        "status": "drift" if any(counts[name] for name in ("create", "update", "delete", "replace")) else "clean",
        "actions": counts,
        "risk": {
            "destructive": counts["delete"] + counts["replace"] > 0,
            "criticalChangeCount": critical,
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("plan", type=Path)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        plan = json.loads(args.plan.read_text(encoding="utf-8"))
        if not isinstance(plan, dict):
            raise ValueError("Terraform plan JSON must be an object")
        args.output.write_text(json.dumps(summarize(plan, args.commit), indent=2, sort_keys=True) + "\n", encoding="utf-8")
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
