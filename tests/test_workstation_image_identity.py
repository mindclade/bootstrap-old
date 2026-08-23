# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class WorkstationImageIdentityTest(unittest.TestCase):
    def test_provider_binds_every_identity_claim(self) -> None:
        text = (ROOT / "modules/identity/wif.tf").read_text(encoding="utf-8")
        provider = text.split(
            'resource "google_iam_workload_identity_pool_provider" "github_workstation_image"',
            1,
        )[1].split(
            'resource "google_iam_workload_identity_pool_provider" "github_artifact_authority"',
            1,
        )[0]

        for claim in (
            "assertion.repository_owner_id",
            "assertion.repository_id",
            "assertion.repository",
            "assertion.repository_visibility",
            "assertion.aud",
            "assertion.sub",
            "assertion.ref",
            "assertion.event_name",
            "assertion.workflow_ref",
            "assertion.job_workflow_ref",
        ):
            self.assertIn(claim, provider)
        self.assertIn('assertion.event_name == \\"workflow_dispatch\\"', provider)
        self.assertIn("reusable-nixos-gce-image-publish.yml@refs/tags/v5.0.0", text)
        self.assertIn(".github/workflows/nixos-image.yml@refs/heads/main", text)

    def test_platform_contract_exports_dedicated_identity(self) -> None:
        outputs = (ROOT / "outputs.tf").read_text(encoding="utf-8")
        module_outputs = (ROOT / "modules/identity/outputs.tf").read_text(
            encoding="utf-8"
        )
        schema = json.loads(
            (ROOT / "contracts/outputs.schema.json").read_text(encoding="utf-8")
        )

        self.assertIn('contract_version      = "1.6.0"', outputs)
        self.assertIn('output "workstation_image_identity"', outputs)
        self.assertIn('output "workstation_image_identity"', module_outputs)
        self.assertIn(
            "workstation_image_identity",
            schema["properties"]["github"]["required"],
        )
        self.assertIn("workstation_image_identity", schema["$defs"])


if __name__ == "__main__":
    unittest.main()
