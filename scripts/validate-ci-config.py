#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

"""Fail closed before cloud authentication when protected CI inputs are incomplete."""

from __future__ import annotations

import argparse
import json
import os
import re
from collections.abc import Mapping


REQUIRED = (
    "TF_VAR_org_id",
    "TF_VAR_billing_account",
    "TF_VAR_prefix",
    "TF_VAR_region",
    "TF_VAR_residency_profile",
    "TF_VAR_state_bucket_location",
    "TF_VAR_state_kms_location",
    "TF_VAR_automation_secret_location",
    "TF_VAR_state_replica_location",
    "TF_VAR_state_replica_kms_location",
    "TF_VAR_preserve_legacy_eu_state_replicas",
    "TF_VAR_state_soft_delete_days",
    "TF_VAR_noncurrent_version_days",
    "TF_VAR_noncurrent_version_count",
    "TF_VAR_kms_protection_level",
    "TF_VAR_github_org",
    "TF_VAR_github_org_id",
    "TF_VAR_github_repository_ids",
    "TF_VAR_break_glass_principals",
    "TF_VAR_security_contact",
)

FIXED = {
    "TF_VAR_region": "us-central1",
    "TF_VAR_residency_profile": "us-only-v1",
    "TF_VAR_state_bucket_location": "US",
    "TF_VAR_state_kms_location": "us",
    "TF_VAR_automation_secret_location": "us-central1",
    "TF_VAR_state_replica_location": "us-east4",
    "TF_VAR_state_replica_kms_location": "us-east4",
    "TF_VAR_github_org": "mindclade",
}

REPOSITORIES = {
    "bootstrap",
    "github-config",
    "infrastructure-live",
    "gitops",
    "mindclade-internal-monorepo",
}

EMAIL = re.compile(r"^[^@\s]+@[^@\s]+$")


def parse_json(name: str, value: str, expected_type: type, errors: list[str]):
    try:
        parsed = json.loads(value)
    except json.JSONDecodeError:
        errors.append(f"{name} must be valid JSON")
        return None
    if not isinstance(parsed, expected_type):
        errors.append(f"{name} must be a JSON {expected_type.__name__}")
        return None
    return parsed


def validate(env: Mapping[str, str], require_state_bucket: bool = False) -> list[str]:
    errors = [f"missing protected variable for {name}" for name in REQUIRED if not env.get(name)]

    for name, expected in FIXED.items():
        value = env.get(name)
        if value and value != expected:
            errors.append(f"{name} must equal the approved {expected} contract")

    for name in ("TF_VAR_org_id", "TF_VAR_github_org_id"):
        value = env.get(name, "")
        if value and not value.isdigit():
            errors.append(f"{name} must be numeric")

    billing = env.get("TF_VAR_billing_account", "")
    if billing and not re.fullmatch(r"[0-9A-Fa-f]{6}(?:-[0-9A-Fa-f]{6}){2}", billing):
        errors.append("TF_VAR_billing_account must use XXXXXX-XXXXXX-XXXXXX format")

    prefix = env.get("TF_VAR_prefix", "")
    if prefix and not re.fullmatch(r"[a-z][a-z0-9]{1,3}", prefix):
        errors.append("TF_VAR_prefix must be 2-4 lowercase alphanumerics beginning with a letter")

    preserve = env.get("TF_VAR_preserve_legacy_eu_state_replicas", "")
    if preserve and preserve not in {"true", "false"}:
        errors.append("TF_VAR_preserve_legacy_eu_state_replicas must be true or false")

    kms = env.get("TF_VAR_kms_protection_level", "")
    if kms and kms not in {"SOFTWARE", "HSM"}:
        errors.append("TF_VAR_kms_protection_level must be SOFTWARE or HSM")

    number_contracts = {
        "TF_VAR_state_soft_delete_days": (7, 90),
        "TF_VAR_noncurrent_version_days": (30, None),
        "TF_VAR_noncurrent_version_count": (10, None),
    }
    for name, (minimum, maximum) in number_contracts.items():
        raw = env.get(name, "")
        if not raw:
            continue
        try:
            value = int(raw)
        except ValueError:
            errors.append(f"{name} must be an integer")
            continue
        if value < minimum or (maximum is not None and value > maximum):
            upper = f" and at most {maximum}" if maximum is not None else ""
            errors.append(f"{name} must be at least {minimum}{upper}")

    repositories = parse_json(
        "TF_VAR_github_repository_ids",
        env.get("TF_VAR_github_repository_ids", "{}"),
        dict,
        errors,
    )
    if repositories is not None:
        missing = sorted(REPOSITORIES - repositories.keys())
        if missing:
            errors.append("TF_VAR_github_repository_ids is missing required repositories")
        if any(not isinstance(value, str) or not value.isdigit() for value in repositories.values()):
            errors.append("TF_VAR_github_repository_ids values must be numeric strings")

    principals = parse_json(
        "TF_VAR_break_glass_principals",
        env.get("TF_VAR_break_glass_principals", "[]"),
        list,
        errors,
    )
    if principals is not None and (
        not principals
        or any(not isinstance(principal, str) or not EMAIL.fullmatch(principal) for principal in principals)
    ):
        errors.append("TF_VAR_break_glass_principals must contain named user email addresses")

    contact = env.get("TF_VAR_security_contact", "")
    if contact and not EMAIL.fullmatch(contact):
        errors.append("TF_VAR_security_contact must be an email address")

    if require_state_bucket:
        bucket = env.get("STATE_BUCKET", "")
        if not bucket:
            errors.append("missing protected variable for STATE_BUCKET")
        elif not re.fullmatch(r"[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]", bucket):
            errors.append("STATE_BUCKET is not a valid bucket name")

    return sorted(set(errors))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--require-state-bucket", action="store_true")
    args = parser.parse_args()
    errors = validate(os.environ, require_state_bucket=args.require_state_bucket)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("protected CI input contract passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
