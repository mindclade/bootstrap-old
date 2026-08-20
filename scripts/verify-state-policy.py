#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
primary = (root / "modules/state/main.tf").read_text()
replica = (root / "modules/state/replication.tf").read_text()
seed = (root / "modules/projects/seed.tf").read_text()
cicd = (root / "modules/projects/cicd.tf").read_text()
break_glass = (root / "modules/identity/break-glass.tf").read_text()
variables = (root / "variables.tf").read_text()
first_apply = (root / "docs/first-apply.md").read_text()
prepare_first_apply = (root / "scripts/prepare-first-apply.py").read_text()
makefile = (root / "Makefile").read_text()
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
        errors.append(
            f"{name} state bucket has a retention policy that can block state replacement"
        )

require(
    'google_storage_bucket_iam_member" "bootstrap_replica_recovery_reader',
    replica,
    "read-only bootstrap replica recovery binding",
)
reader_marker = 'resource "google_storage_bucket_iam_member" "reader"'
lock_marker = 'resource "google_storage_bucket_iam_member" "reader_lock_object_admin"'
writer_marker = 'resource "google_storage_bucket_iam_member" "writer"'
reader_binding = (
    primary.split(reader_marker, 1)[1].split(lock_marker, 1)[0]
    if reader_marker in primary and lock_marker in primary
    else ""
)
lock_binding = (
    primary.split(lock_marker, 1)[1].split(writer_marker, 1)[0]
    if lock_marker in primary and writer_marker in primary
    else ""
)
require(
    'role     = "roles/storage.objectViewer"',
    reader_binding,
    "unconditional state read/list role",
)
for token, label in (
    (
        'google_storage_bucket_iam_member" "reader_lock_object_admin',
        "read-only identity lock-object binding",
    ),
    ('role     = "roles/storage.objectAdmin"', "lock-object create/delete role"),
    (
        "expression  = \"resource.type == 'storage.googleapis.com/Object' && resource.name.endsWith('.tflock')\"",
        "typed lock-object-only IAM condition",
    ),
):
    require(
        token, primary if token.startswith("google_storage") else lock_binding, label
    )
if ".tfstate" in lock_binding:
    errors.append("read-only identity IAM condition permits Terraform state writes")
for token, label in (
    ("Activate native-lock IAM without deadlocking", "lock-IAM activation ordering"),
    ("before enabling mandatory locking", "lock-IAM pre-grant order"),
    ("must remain denied", "negative state-write activation test"),
):
    require(token, first_apply, label)

for token, label in (
    (
        "exact clean-commit export that deliberately omits `backend.tf`",
        "backend-free clean-commit first-apply procedure",
    ),
    (
        'git -C "${SOURCE_ROOT}" show "${SOURCE_SHA}:backend.tf"',
        "exact-commit backend restoration before migration",
    ),
    (
        'terraform -chdir="${FIRST_APPLY_DIR}" init',
        "isolated first-apply initialization",
    ),
):
    require(token, first_apply, label)
if "terraform init -backend=false -input=false\nterraform plan" in first_apply:
    errors.append("first-apply guide still plans after validation-only backend initialization")
for token, label in (
    ('command("status", "--porcelain=v1", "--untracked-files=all")', "clean checkout guard"),
    ('if relative == "backend.tf"', "root backend omission"),
    ('--commit must resolve exactly to the checkout\'s current HEAD', "exact HEAD guard"),
    ('--work-dir already exists', "new work-directory guard"),
):
    require(token, prepare_first_apply, label)
require("first-apply-workdir:", makefile, "safe first-apply Make target")
if "plan-local:" in makefile or "terraform init -backend=false\n\tterraform plan" in makefile:
    errors.append("Makefile retains an unsafe local plan target")
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
require(
    '"iam.googleapis.com"', seed, "IAM-backed service-account credential audit logging"
)
if (
    '"iamcredentials.googleapis.com"'
    in seed.split('resource "google_project_iam_audit_config" "ring0_data_access"', 1)[
        -1
    ]
):
    errors.append(
        "Service Account Credentials audit logging is incorrectly configured on iamcredentials.googleapis.com"
    )

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
