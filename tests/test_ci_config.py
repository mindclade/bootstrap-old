#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "validate_ci_config", ROOT / "scripts/validate-ci-config.py"
)
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


def valid_environment() -> dict[str, str]:
    return {
        "TF_VAR_org_id": "123456789012",
        "TF_VAR_billing_account": "ABCDEF-ABCDEF-ABCDEF",
        "TF_VAR_prefix": "mc",
        "TF_VAR_region": "us-central1",
        "TF_VAR_residency_profile": "us-only-v1",
        "TF_VAR_state_bucket_location": "US",
        "TF_VAR_state_kms_location": "us",
        "TF_VAR_automation_secret_location": "us-central1",
        "TF_VAR_state_replica_location": "us-east4",
        "TF_VAR_state_replica_kms_location": "us-east4",
        "TF_VAR_preserve_legacy_eu_state_replicas": "false",
        "TF_VAR_state_soft_delete_days": "30",
        "TF_VAR_noncurrent_version_days": "90",
        "TF_VAR_noncurrent_version_count": "100",
        "TF_VAR_kms_protection_level": "SOFTWARE",
        "TF_VAR_github_org": "mindclade",
        "TF_VAR_github_org_id": "12345678",
        "TF_VAR_github_repository_ids": (
            '{"bootstrap":"1","github-config":"2","infrastructure-live":"3",'
            '"gitops":"4","mindclade-internal-monorepo":"5"}'
        ),
        "TF_VAR_break_glass_principals": '["recovery@example.net"]',
        "TF_VAR_security_contact": "security@mindclade.com",
        "STATE_BUCKET": "mc-tfstate-bootstrap-abc123",
    }


class CiConfigTests(unittest.TestCase):
    def test_complete_contract_passes(self) -> None:
        self.assertEqual(validator.validate(valid_environment(), True), [])

    def test_missing_replica_disposition_fails_closed(self) -> None:
        env = valid_environment()
        del env["TF_VAR_preserve_legacy_eu_state_replicas"]
        self.assertIn(
            "missing protected variable for TF_VAR_preserve_legacy_eu_state_replicas",
            validator.validate(env),
        )

    def test_invalid_repository_contract_is_rejected(self) -> None:
        env = valid_environment()
        env["TF_VAR_github_repository_ids"] = '{"bootstrap":"not-numeric"}'
        errors = validator.validate(env)
        self.assertIn("TF_VAR_github_repository_ids is missing required repositories", errors)
        self.assertIn("TF_VAR_github_repository_ids values must be numeric strings", errors)

    def test_unapproved_location_and_missing_bucket_are_rejected(self) -> None:
        env = valid_environment()
        env["TF_VAR_state_replica_location"] = "europe-west4"
        env["STATE_BUCKET"] = ""
        errors = validator.validate(env, True)
        self.assertIn(
            "TF_VAR_state_replica_location must equal the approved us-east4 contract", errors
        )
        self.assertIn("missing protected variable for STATE_BUCKET", errors)


if __name__ == "__main__":
    unittest.main()
