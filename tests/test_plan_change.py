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
    "classify_plan_change", ROOT / "scripts/classify-plan-change.py"
)
assert SPEC and SPEC.loader
classifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(classifier)


class PlanChangeTests(unittest.TestCase):
    def test_terraform_state_and_control_paths_require_connected_plan(self) -> None:
        for path in (
            "main.tf",
            "modules/state/outputs.tf",
            "generated/config.tf.json",
            ".terraform.lock.hcl",
            "module/.terraform.lock.hcl",
            ".terraform-version",
            ".github/workflows/plan.yml",
            "scripts/classify-plan-change.py",
        ):
            with self.subTest(path=path):
                self.assertTrue(classifier.requires_connected_plan([path]))

    def test_documentation_only_change_skips_connected_plan(self) -> None:
        self.assertFalse(
            classifier.requires_connected_plan(["README.md", "docs/architecture.md"])
        )

    def test_manual_and_merge_group_events_fail_closed_to_plan(self) -> None:
        self.assertTrue(classifier.decide("workflow_dispatch", "", "", ""))
        self.assertTrue(classifier.decide("merge_group", "", "", ""))

    def test_closed_pull_request_is_cancellation_only(self) -> None:
        self.assertFalse(classifier.decide("pull_request", "closed", "", ""))

    def test_workflow_executes_only_the_base_branch_classifier(self) -> None:
        workflow = (ROOT / ".github/workflows/plan.yml").read_text(encoding="utf-8")
        self.assertIn(
            'git show "${BASE_SHA}:scripts/classify-plan-change.py"', workflow
        )
        self.assertIn(
            "grep -Eq '^(\\.github/workflows/plan\\.yml|"
            "scripts/classify-plan-change\\.py)$'",
            workflow,
        )
        self.assertIn(
            "A pull request may not execute its own modified gate to exempt itself",
            workflow,
        )

    def test_cancelled_connected_plan_cannot_pass_the_verdict(self) -> None:
        workflow = (ROOT / ".github/workflows/plan.yml").read_text(encoding="utf-8")
        self.assertNotIn('[ "$PLAN_RESULT" = cancelled ]', workflow)
        self.assertIn('[ "$PLAN_RESULT" != success ]', workflow)
        self.assertIn("connected speculative plan did not succeed", workflow)


if __name__ == "__main__":
    unittest.main()
