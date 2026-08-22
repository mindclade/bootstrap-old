#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

import re
import sys
from pathlib import Path

root = Path(__file__).resolve().parent.parent
primary = (root / "modules/state/main.tf").read_text()
replica = (root / "modules/state/replication.tf").read_text()
seed = (root / "modules/projects/seed.tf").read_text()
cicd = (root / "modules/projects/cicd.tf").read_text()
break_glass = (root / "modules/identity/break-glass.tf").read_text()
variables = (root / "variables.tf").read_text()
root_main = (root / "main.tf").read_text()
project_outputs = (root / "modules/projects/outputs.tf").read_text()
automation_secret = (root / "modules/identity/automation-secrets.tf").read_text()
first_apply = (root / "docs/first-apply.md").read_text()
prepare_first_apply = (root / "scripts/prepare-first-apply.py").read_text()
makefile = (root / "Makefile").read_text()
recovery_drill = (root / ".github/workflows/recovery-drill.yml").read_text()
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

for token, label in (
    (
        'google_storage_bucket_iam_member" "bootstrap_legacy_replica_recovery_reader',
        "read-only legacy replica recovery binding",
    ),
    (
        'google_storage_bucket_iam_member" "bootstrap_us_replica_recovery_reader',
        "read-only U.S. replica recovery binding",
    ),
):
    require(token, replica, label)
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
    (
        "preserve_legacy_eu_state_replicas = false",
        "greenfield legacy-replica opt-out",
    ),
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
    (
        "bootstrap/negative-write-probe.tfstate",
        "exact non-lock recovery-drill probe",
    ),
    ("gcloud storage cp - \"$probe\"", "negative object-create attempt"),
    ("gcloud storage rm \"$probe\"", "unexpected-write cleanup"),
    ("upload_status", "negative-write result gate"),
    ("reason other than an IAM denial", "fail-closed denial classification"),
    ("cleanup failed", "failed-cleanup critical error"),
):
    require(token, recovery_drill, label)

for token, text, label in (
    (
        'resource "google_kms_key_ring" "automation_secrets"',
        seed,
        "dedicated automation-secret key ring",
    ),
    (
        "location = var.automation_secret_location",
        seed,
        "regional automation-secret key ring location",
    ),
    (
        'resource "google_kms_crypto_key" "automation_secrets_regional"',
        seed,
        "dedicated regional automation-secret CMEK",
    ),
    (
        "key_ring        = google_kms_key_ring.automation_secrets.id",
        seed,
        "automation-secret CMEK key ring",
    ),
    (
        "from = google_kms_crypto_key.automation_secrets",
        seed,
        "non-destructive partial-apply key state removal",
    ),
    ("destroy = false", seed, "preserved partial-apply key"),
    (
        "google_kms_crypto_key.automation_secrets_regional.id",
        project_outputs,
        "regional automation-secret CMEK output",
    ),
    (
        "location = var.automation_secret_location",
        automation_secret,
        "Secret Manager regional replica",
    ),
    (
        "kms_key_name = var.automation_secret_kms_key_id",
        automation_secret,
        "Secret Manager regional replica CMEK",
    ),
    (
        'condition     = var.automation_secret_location == "us-central1"',
        variables,
        "U.S.-resident automation-secret input validation",
    ),
):
    require(token, text, label)
if not re.search(
    r"(?m)^\s*automation_secret_location\s*=\s*var\.automation_secret_location\s*$",
    root_main,
):
    errors.append("missing shared secret replica and CMEK location")
for token, label in (
    ('condition     = var.region == "us-central1"', "U.S. primary region"),
    ('condition     = var.residency_profile == "us-only-v1"', "residency profile"),
    ('condition     = var.state_bucket_location == "US"', "U.S. state multi-region"),
    ('condition     = var.state_kms_location == "us"', "U.S. state KMS multi-region"),
    ('condition     = var.state_replica_location == "us-east4"', "U.S. state recovery region"),
    ('condition     = var.state_replica_kms_location == "us-east4"', "recovery-region state KMS"),
):
    require(token, variables, label)
require('repeat_interval = "3600s"', replica, "hourly state recovery copy")
for token, label in (
    (
        'name     = "${var.prefix}-tfstate-${each.key}-replica-us-${var.suffix}"',
        "distinct U.S. replica bucket identity",
    ),
    ('location = "europe-west4"', "explicit legacy replica location"),
    (
        "for_each = var.preserve_legacy_eu_state_replicas ? local.state_buckets : {}",
        "legacy replica preservation gate",
    ),
    ("from = google_storage_bucket.replica", "legacy bucket state move"),
    (
        "to   = google_storage_bucket.legacy_replica",
        "legacy bucket destination",
    ),
    ("from = google_storage_transfer_job.state", "legacy transfer-job state move"),
    (
        "to   = google_storage_transfer_job.state_legacy",
        "legacy transfer-job destination",
    ),
):
    require(token, replica, label)
if "automation_secret_location   = var.state_kms_location" in root_main:
    errors.append("Secret Manager replica still reuses the state multi-region KMS location")
if 'resource "google_kms_crypto_key" "automation_secrets" {' in seed:
    errors.append("unsupported multi-region automation-secret key remains managed")
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
require(
    '"orgpolicy.googleapis.com"',
    seed,
    "seed Org Policy API quota service",
)
require(
    '"cloudidentity.googleapis.com"',
    cicd,
    "CI/CD Cloud Identity API quota service",
)

narrow_kms_dependency = (
    'project  = google_project_service.seed["cloudkms.googleapis.com"].project'
)
for key_ring in (
    "state_primary",
    "automation_secrets",
    "state_replica_legacy",
    "state_replica_us",
):
    marker = f'resource "google_kms_key_ring" "{key_ring}"'
    block = seed.split(marker, 1)[-1].split("\n}", 1)[0] if marker in seed else ""
    require(
        narrow_kms_dependency,
        block,
        f"service-specific Cloud KMS dependency for {key_ring}",
    )

storage_service_agent = (
    'member        = "serviceAccount:${data.google_storage_project_service_account.seed.email_address}"'
)
if seed.count(storage_service_agent) != 3:
    errors.append(
        "primary, legacy replica, and U.S. replica KMS bindings must use the authoritative GCS service agent"
    )
storage_data_marker = 'data "google_storage_project_service_account" "seed"'
storage_data = (
    seed.split(storage_data_marker, 1)[-1].split("\n}", 1)[0]
    if storage_data_marker in seed
    else ""
)
require(
    'depends_on = [google_project_service.seed["storage.googleapis.com"]]',
    storage_data,
    "service-specific Storage dependency for the GCS service agent",
)
if "depends_on = [google_project_service.seed]" in seed:
    errors.append("seed resources retain a broad dependency on every project service")

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
