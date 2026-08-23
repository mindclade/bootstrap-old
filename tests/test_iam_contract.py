#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SERVICE_ACCOUNTS = (ROOT / "modules/identity/service-accounts.tf").read_text(
    encoding="utf-8"
)


def identity_block(identity: str, next_identity: str) -> str:
    return SERVICE_ACCOUNTS.split(f"{identity} = {{", 1)[1].split(
        f"{next_identity} = {{", 1
    )[0]


class IamContractTests(unittest.TestCase):
    def test_automation_has_no_basic_roles(self) -> None:
        for role in ('"roles/owner"', '"roles/editor"', '"roles/viewer"'):
            with self.subTest(role=role):
                self.assertNotIn(role, SERVICE_ACCOUNTS.lower())

    def test_bootstrap_readers_use_granular_project_roles(self) -> None:
        plan = identity_block("bootstrap-plan", "bootstrap-drift")
        drift = identity_block("bootstrap-drift", "bootstrap-apply")
        for block in (plan, drift):
            for role in (
                "roles/cloudkms.viewer",
                "roles/iam.serviceAccountViewer",
                "roles/iam.workloadIdentityPoolViewer",
                "roles/serviceusage.serviceUsageViewer",
                "roles/storage.legacyBucketReader",
                "roles/storagetransfer.viewer",
            ):
                with self.subTest(role=role):
                    self.assertIn(role, block)

    def test_cloud_identity_quota_consumer_is_explicit(self) -> None:
        block = identity_block("github-config-plan", "github-config-apply")
        self.assertIn("roles/serviceusage.serviceUsageConsumer", block)
        self.assertNotIn('seed = ["roles/viewer"]', block)

    def test_billing_iam_is_manageable_without_financial_admin(self) -> None:
        self.assertIn(
            'resource "google_billing_account_iam_member" "bootstrap_billing_iam_admin"',
            SERVICE_ACCOUNTS,
        )
        self.assertIn('role               = "roles/iam.securityAdmin"', SERVICE_ACCOUNTS)
        self.assertNotIn('role               = "roles/billing.admin"', SERVICE_ACCOUNTS)


if __name__ == "__main__":
    unittest.main()
