#!/usr/bin/env python3
# Copyright © 2026 Mindclade, LLC. All Rights Reserved.
# Mindclade Proprietary and Confidential.
# SPDX-License-Identifier: LicenseRef-Mindclade-Proprietary

from __future__ import annotations

import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WIF = ROOT / "modules" / "identity" / "wif.tf"
OUTPUTS = ROOT / "modules" / "identity" / "outputs.tf"
SCHEMA = ROOT / "contracts" / "outputs.schema.json"


class BazelCacheIdentityTests(unittest.TestCase):
    def contract(self) -> str:
        text = WIF.read_text(encoding="utf-8")
        return text.split(
            "  github_bazel_cache_repository         = local.github_signer_repository",
            maxsplit=1,
        )[1].split(
            'resource "google_iam_workload_identity_pool_provider" "github_dr_evidence"',
            maxsplit=1,
        )[0]

    def test_provider_has_four_exact_routes(self) -> None:
        text = WIF.read_text(encoding="utf-8")
        contract = self.contract()
        for route, event in (
            ("pull-request-read", "pull_request"),
            ("trusted-main-write", "push"),
            ("merge-group-write", "merge_group"),
            ("nightly-write", "schedule"),
        ):
            with self.subTest(route=route):
                self.assertIn(f"{route} = {{", text)
                self.assertIn(f'assertion.event_name == \\"{event}\\"', text)
                self.assertIn(route, contract)
        self.assertIn("assertion.workflow_sha == assertion.sha", contract)
        self.assertIn("assertion.repository_owner_id", contract)
        self.assertIn("assertion.repository_id", contract)
        self.assertIn("allowed_audiences = [local.github_bazel_cache_audience]", contract)

    def test_provider_rejects_unapproved_authority_paths(self) -> None:
        contract = self.contract()
        for forbidden in (
            "pull_request_target",
            "workflow_dispatch",
            "repository_dispatch",
            "principalSet://",
            "refs/tags/",
        ):
            with self.subTest(forbidden=forbidden):
                self.assertNotIn(forbidden, contract)

    def test_routes_bind_exact_subject_ref_and_workflow_claims(self) -> None:
        contract = self.contract()
        for required in (
            ':pull_request")}',
            r'assertion.ref.startsWith(\"refs/pull/\")',
            r'assertion.ref.endsWith(\"/merge\")',
            'assertion.workflow_ref == ${jsonencode("${local.github_bazel_cache_presubmit_workflow}@")} + assertion.ref',
            ':ref:refs/heads/main")}',
            r'assertion.ref == \"refs/heads/main\"',
            'assertion.workflow_ref == ${jsonencode("${local.github_bazel_cache_presubmit_workflow}@refs/heads/main")}',
            r'assertion.ref.startsWith(\"refs/heads/gh-readonly-queue/main/\")',
            ':ref:")} + assertion.ref',
            'assertion.workflow_ref == ${jsonencode("${local.github_bazel_cache_nightly_workflow}@refs/heads/main")}',
            r'assertion.repository_visibility in [\"internal\", \"private\"]',
        ):
            with self.subTest(required=required):
                self.assertIn(required, contract)

    def test_output_contract_keeps_pr_read_only(self) -> None:
        schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
        identity = schema["$defs"]["bazel_cache_identity"]
        routes = identity["properties"]["routes"]["properties"]
        expected = {
            "pull-request-read": ("read", "pull_request"),
            "trusted-main-write": ("write", "push"),
            "merge-group-write": ("write", "merge_group"),
            "nightly-write": ("write", "schedule"),
        }
        self.assertEqual(set(routes), set(expected))
        for route, (access, event) in expected.items():
            properties = routes[route]["allOf"][1]["properties"]
            self.assertEqual(properties["access"]["const"], access)
            self.assertEqual(properties["event_name"]["const"], event)
            self.assertTrue(properties["principal"]["pattern"].endswith(f"{route}$"))

    def test_output_uses_route_exact_principals(self) -> None:
        outputs = OUTPUTS.read_text(encoding="utf-8")
        self.assertIn('subject/bazel-cache:${route}"', outputs)
        self.assertNotIn("principalSet://", outputs)


if __name__ == "__main__":
    unittest.main()
