#!/usr/bin/env bash
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$root" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
primary = (root / "modules/state/main.tf").read_text()
replica = (root / "modules/state/replication.tf").read_text()
seed = (root / "modules/projects/seed.tf").read_text()
cicd = (root / "modules/projects/cicd.tf").read_text()
break_glass = (root / "modules/identity/break-glass.tf").read_text()
variables = (root / "variables.tf").read_text()
errors: list[str] = []


def require(token: str, text: str, label=None) -> None:
    if token not in text:
        errors.append(f"missing {label or token}")


for name, text in (("primary", primary), ("replica", replica)):
    for token in (
        "uniform_bucket_level_access = true",
        'public_access_prevention    = "enforced"',
        "force_destroy               = false",
        "versioning {",
        "soft_delete_policy {",
        "default_kms_key_name",
        "days_since_noncurrent_time",
        "num_newer_versions",
        "prevent_destroy = true",
    ):
        require(token, text, f"{name} state safeguard: {token}")
    if "retention_policy {" in text or "is_locked = true" in text:
        errors.append(f"{name} state bucket has a retention policy that can block state replacement")

require(
    'google_storage_bucket_iam_member" "bootstrap_replica_recovery_reader',
    replica,
    "read-only bootstrap replica recovery binding",
)
for token in (
    "logging_config {",
    'log_actions       = ["FIND", "COPY"]',
    'log_action_states = ["SUCCEEDED", "FAILED"]',
):
    require(token, replica, f"state replication safeguard: {token}")
for token in ('"ADMIN_READ"', '"DATA_READ"', '"DATA_WRITE"'):
    require(token, seed, f"seed Ring-0 audit class {token}")
    require(token, cicd, f"CI federation audit class {token}")
for service in ('"iam.googleapis.com"', '"sts.googleapis.com"'):
    require(service, cicd, f"CI federation audit service {service}")
require('"iam.googleapis.com"', seed, "IAM-backed service-account credential audit logging")
if '"iamcredentials.googleapis.com"' in seed.split('resource "google_project_iam_audit_config" "ring0_data_access"', 1)[-1]:
    errors.append("Service Account Credentials audit logging is incorrectly configured on iamcredentials.googleapis.com")

if 'resource "google_project_service" "monitoring"' in break_glass:
    errors.append("Monitoring API has duplicate ownership in the identity module")
require(
    "length(var.break_glass_principals) > 0",
    variables,
    "non-empty break-glass principal validation",
)

if errors:
    for error in sorted(set(errors)):
        print(f"ERROR: {error}", file=sys.stderr)
    raise SystemExit(1)
print("bootstrap state, audit, and recovery policy passed")
PY
